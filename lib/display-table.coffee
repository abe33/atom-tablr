_ = require 'underscore-plus'
{Point, Range, Emitter, CompositeDisposable} = require 'atom'
Delegator = require 'delegato'
Table = require './table'
DisplayColumn = require './display-column'

module.exports =
class DisplayTable
  Delegator.includeInto(this)

  atom.deserializers.add(this)

  @deserialize: (state) ->
    state.table = atom.deserializers.deserialize(state.table) if state.table?
    displayTable = new DisplayTable(state)

  @delegatesMethods(
    'changeColumnName', 'undo', 'redo', 'getRows', 'getColumns','getColumnCount', 'getColumnIndex', 'getRowCount', 'clearUndoStack', 'clearRedoStack', 'getValueAtPosition', 'setValueAtPosition', 'setValuesAtPositions', 'setValuesInRange', 'rowRangeFrom',
    toProperty: 'table'
  )

  rowOffsets: null
  columnOffsets: null

  constructor: (options={}) ->
    {@table, @rowHeights, @order, @direction} = options
    @table ?= new Table
    @emitter = new Emitter
    @subscriptions = new CompositeDisposable
    @screenColumnsSubscriptions = new WeakMap

    @subscribeToConfig()
    @subscribeToTable()

    @screenColumns = @table.getColumns().map (column) =>
      screenColumn = new DisplayColumn({name: column})
      @subscribeToScreenColumn(screenColumn)
      screenColumn

    @rowHeights ?= @table.getColumns().map (column) => @getRowHeight()
    @computeScreenColumnOffsets()
    @updateScreenRows()

  destroy: ->
    @unsubscribeFromScreenColumn(column) for column in @screenColumns
    @rowOffsets = []
    @rowHeights = []
    @columnOffsets = []
    @screenColumns = []
    @screenRows = []
    @screenToModelRowsMap = {}
    @modelToScreenRowsMap = {}
    @destroyed = true
    @emitter.emit 'did-destroy', this
    @emitter.dispose()
    @emitter = null
    @subscriptions.dispose()
    @subscriptions = null
    @table = null

  onDidDestroy: (callback) ->
    @emitter.on 'did-destroy', callback

  onDidAddColumn: (callback) ->
    @emitter.on 'did-add-column', callback

  onDidRemoveColumn: (callback) ->
    @emitter.on 'did-remove-column', callback

  onDidRenameColumn: (callback) ->
    @emitter.on 'did-rename-column', callback

  onDidChangeColumnOption: (callback) ->
    @emitter.on 'did-change-column-options', callback

  onDidChangeCellValue: (callback) ->
    @emitter.on 'did-change-cell-value', callback

  onDidAddRow: (callback) ->
    @emitter.on 'did-add-row', callback

  onDidRemoveRow: (callback) ->
    @emitter.on 'did-remove-row', callback

  onDidChange: (callback) ->
    @emitter.on 'did-change', callback

  onDidChangeLayout: (callback) ->
    @emitter.on 'did-change-layout', callback

  onDidChangeRowHeight: (callback) ->
    @emitter.on 'did-change-row-height', callback

  subscribeToTable: ->
    @subscriptions.add @table.onDidAddColumn ({column, index}) =>
      @addScreenColumn(index, {name: column})

    @subscriptions.add @table.onDidRemoveColumn ({column, index}) =>
      @removeScreenColumn(index, column)

    @subscriptions.add @table.onDidRenameColumn ({newName, oldName, index}) =>
      @screenColumns[index].setOption 'name', newName
      @emitter.emit('did-rename-column', {screenColumn: @screenColumns[index], oldName, newName, index})

    @subscriptions.add @table.onDidAddRow ({index}) =>
      @rowHeights.splice(index, 0, undefined)

    @subscriptions.add @table.onDidRemoveRow ({index}) =>
      @rowHeights.splice(index, 1)

    @subscriptions.add @table.onDidChange (event) =>
      @updateScreenRows()
      @emitter.emit 'did-change', event

    @subscriptions.add @table.onDidChangeCellValue (event) =>
      if event.positions?
        {positions, oldValues, newValues} = event
        newEvent = {
          positions, oldValues, newValues
          screenPositions: positions.map (p) => @screenPosition(p)
        }
      else if event.position?
        {position, oldValue, newValue} = event
        newEvent = {
          position, oldValue, newValue
          screenPosition: @screenPosition(position)
        }
      else if event.range?
        {range, oldValues, newValues} = event
        if @order?
          screenPositions = []
          range.each (row, column) =>
            screenPositions.push(@screenPosition([row, column]))
          newEvent = { range, oldValues, newValues, screenPositions }
        else
          newEvent = {
            range, oldValues, newValues
            screenRange: range.copy()
          }
      else
        newEvent = event

      @emitter.emit 'did-change-cell-value', newEvent

    @subscriptions.add @table.onDidDestroy (event) => @destroy()

  subscribeToConfig: ->
    @observeConfig
      'tablr.undefinedDisplay': (@configUndefinedDisplay) =>
      'tablr.rowHeight': (@configRowHeight) =>
        @computeRowOffsets() if @rowHeights? and @screenRows?
      'tablr.minimumRowHeight': (@configMinimumRowHeight) =>
        @computeRowOffsets() if @rowHeights? and @screenRows?
      'tablr.columnWidth': (@configScreenColumnWidth) =>
        @computeScreenColumnOffsets() if @screenColumns?
      'tablr.minimumColumnWidth': (@configMinimumScreenColumnWidth) =>
        @computeScreenColumnOffsets() if @screenColumns?

  observeConfig: (configs) ->
    for config, callback of configs
      @subscriptions.add atom.config.observe config, callback

  isDestroyed: -> @destroyed

  serialize: ->
    out = {
      deserializer: 'DisplayTable'
      @rowHeights
      table: @table.serialize()
    }

    out = _.extend(out, {@order, @direction}) if @order?

    out

  ##     ######   #######  ##       ##     ## ##     ## ##    ##  ######
  ##    ##    ## ##     ## ##       ##     ## ###   ### ###   ## ##    ##
  ##    ##       ##     ## ##       ##     ## #### #### ####  ## ##
  ##    ##       ##     ## ##       ##     ## ## ### ## ## ## ##  ######
  ##    ##       ##     ## ##       ##     ## ##     ## ##  ####       ##
  ##    ##    ## ##     ## ##       ##     ## ##     ## ##   ### ##    ##
  ##     ######   #######  ########  #######  ##     ## ##    ##  ######

  getScreenColumns: -> @screenColumns.slice()

  getScreenColumnCount: -> @screenColumns.length

  getScreenColumn: (index) -> @screenColumns[index]

  getScreenColumnIndex: (column) -> @screenColumns.indexOf(column)

  getLastColumnIndex: -> @screenColumns.length - 1

  getContentWidth: ->
    lastIndex = @getLastColumnIndex()
    return 0 if lastIndex < 0

    @getScreenColumnOffsetAt(lastIndex) + @getScreenColumnWidthAt(lastIndex)

  getScreenColumnWidth: ->
    @screenColumnWidth ? @configScreenColumnWidth

  getMinimumScreenColumnWidth: ->
    @minimumScreenColumnWidth ? @configMinimumScreenColumnWidth

  setScreenColumnWidth: (@minimumScreenColumnWidth) ->
    @computeScreenColumnOffsets()

  getScreenColumnWidthAt: (index) ->
    @screenColumns[index]?.width ? @getScreenColumnWidth()

  setScreenColumnWidthAt: (index, width) ->
    minWidth = @getMinimumScreenColumnWidth()
    width = minWidth if width < minWidth
    @screenColumns[index]?.width = width
    @emitter.emit 'did-change-layout', this

  getScreenColumnAlignAt: (index) ->
    @screenColumns[index]?.align

  setScreenColumnAlignAt: (index, align) ->
    @screenColumns[index]?.align = align
    @emitter.emit 'did-change-layout', this

  getScreenColumnOffsetAt: (column) -> @screenColumnOffsets[column]

  getScreenColumnIndexAtPixelPosition: (position) ->
    for i in [0...@getScreenColumnWidth()]
      offset = @getScreenColumnOffsetAt(i)
      return i - 1 if position < offset

    return @getLastColumnIndex()

  addColumn: (name, options={}, transaction=true) ->
    @addColumnAt(@screenColumns.length, name, options, transaction)

  addColumnAt: (index, column, options={}, transaction=true) ->
    @table.addColumnAt(index, column, transaction)
    @getScreenColumn(index).setOptions(options)

    if transaction
      columnOptions = _.clone(options)

      @table.ammendLastTransaction
        undo: (commit) =>
          commit.undo()
        redo: (commit) =>
          commit.redo()
          @getScreenColumn(index).setOptions(columnOptions)

  addScreenColumn: (index, options) ->
    screenColumn = new DisplayColumn(options)
    @subscribeToScreenColumn(screenColumn)
    @screenColumns.splice(index, 0, screenColumn)
    @computeScreenColumnOffsets()
    @emitter.emit('did-add-column', {screenColumn, column: options.name, index})

  removeColumn: (column, transaction=true) ->
    @removeColumnAt(@table.getColumnIndex(column), transaction)

  removeColumnAt: (index, transaction=true) ->
    screenColumn = @screenColumns[index]
    @table.removeColumnAt(index, transaction)

    if transaction
      columnOptions = _.clone(screenColumn.options)

      @table.ammendLastTransaction
        undo: (commit) =>
          commit.undo()
          @getScreenColumn(index).setOptions(columnOptions)
        redo: (commit) =>
          commit.redo()

  removeScreenColumn: (index, column) ->
    screenColumn = @screenColumns[index]
    @unsubscribeFromScreenColumn(screenColumn)
    @screenColumns.splice(index, 1)
    @computeScreenColumnOffsets()
    @emitter.emit('did-remove-column', {screenColumn, column, index})

  computeScreenColumnOffsets: ->
    offsets = []
    offset = 0

    for i in [0...@screenColumns.length]
      offsets.push offset
      offset += @getScreenColumnWidthAt(i)

    @screenColumnOffsets = offsets

  subscribeToScreenColumn: (screenColumn) ->
    subs = new CompositeDisposable
    @screenColumnsSubscriptions.set(screenColumn, subs)

    subs.add screenColumn.onDidChangeName ({oldName, newName}) =>
      @table.changeColumnName(oldName, newName)

    subs.add screenColumn.onDidChangeOption (event) =>
      newEvent = _.clone(event)
      newEvent.index = @screenColumns.indexOf(event.column)
      @emitter.emit 'did-change-column-options', newEvent

      @computeScreenColumnOffsets() if event.option is 'width'

  unsubscribeFromScreenColumn: (screenColumn) ->
    subs = @screenColumnsSubscriptions.get(screenColumn)
    @screenColumnsSubscriptions.delete(screenColumn)
    subs?.dispose()

  ##    ########   #######  ##      ##  ######
  ##    ##     ## ##     ## ##  ##  ## ##    ##
  ##    ##     ## ##     ## ##  ##  ## ##
  ##    ########  ##     ## ##  ##  ##  ######
  ##    ##   ##   ##     ## ##  ##  ##       ##
  ##    ##    ##  ##     ## ##  ##  ## ##    ##
  ##    ##     ##  #######   ###  ###   ######

  screenRowToModelRow: (row) -> @screenToModelRowsMap[row]

  modelRowToScreenRow: (row) -> @modelToScreenRowsMap[row]

  getScreenRows: -> @screenRows.slice()

  getScreenRowCount: -> @screenRows.length

  getScreenRow: (row) ->
    @table.getRow(@screenRowToModelRow(row))

  getLastRowIndex: -> @screenRows.length - 1

  getScreenRowHeightAt: (row) ->
    @getRowHeightAt(@screenRowToModelRow(row))

  setScreenRowHeightAt: (row, height) ->
    @setRowHeightAt(@screenRowToModelRow(row), height)

  getScreenRowOffsetAt: (row) -> @rowOffsets[row]

  getContentHeight: ->
    lastIndex = @getLastRowIndex()
    return 0 if lastIndex < 0

    @getScreenRowOffsetAt(lastIndex) + @getScreenRowHeightAt(lastIndex)

  getRowHeight: ->
    @rowHeight ? @configRowHeight

  getMinimumRowHeight: ->
    @minimumRowHeight ? @configMinimumRowHeight

  setRowHeight: (@rowHeight) ->
    @computeRowOffsets()

  setRowHeights: (@rowHeights=[]) ->
    @computeRowOffsets()
    @emitter.emit 'did-change-layout', this

  getRowHeightAt: (index) ->
    @rowHeights[index] ? @getRowHeight()

  setRowHeightAt: (index, height) ->
    minHeight = @getMinimumRowHeight()
    height = minHeight if height < minHeight
    @rowHeights[index] = height
    @computeRowOffsets()
    @emitter.emit 'did-change-row-height', {height, row: index}
    @emitter.emit 'did-change-layout', this

  getRowOffsetAt: (index) -> @getScreenRowOffsetAt(@modelRowToScreenRow(index))

  getScreenRowIndexAtPixelPosition: (position) ->
    for i in [0...@getScreenRowCount()]
      offset = @getScreenRowOffsetAt(i)
      return i - 1 if position < offset

    return @getLastRowIndex()

  getRowIndexAtPixelPosition: (position) ->
    @screenRowToModelRow(@getScreenRowIndexAtPixelPosition(position))

  addRow: (row, options={}, transaction=true) ->
    @addRowAt(@table.getRowCount(), row, options, transaction)

  addRowAt: (index, row, options={}, transaction=true) ->
    @table.addRowAt(index, row, false, transaction)
    @setRowHeightAt(index, options.height) if options.height?

    if transaction
      rowOptions = _.clone(options)
      @table.ammendLastTransaction
        undo: (commit) =>
          commit.undo()
        redo: (commit) =>
          commit.redo()
          @setRowHeightAt(index, rowOptions.height) if rowOptions.height?

    modelIndex = @screenRowToModelRow(index)
    @emitter.emit 'did-add-row', {row, screenIndex: index, index: modelIndex}

  addRows: (rows, options=[], transaction=true) ->
    @addRowsAt(@table.getRowCount(), rows, options, transaction)

  addRowsAt: (index, rows, options=[], transaction=true) ->
    modelIndex = @screenRowToModelRow(index)
    rows = rows.slice()

    @table.addRowsAt(index, rows, transaction)
    for row,i in rows
      @setRowHeightAt(index + i, options[i]?.height) if options[i]?.height?
      @emitter.emit 'did-add-row', {row, screenIndex: index, index: modelIndex}

    if transaction
      rowOptions = _.clone(options)
      @table.ammendLastTransaction
        undo: (commit) =>
          commit.undo()
        redo: (commit) =>
          commit.redo()
          for row,i in rows when rowOptions[i]?.height?
            @setRowHeightAt(index + i, rowOptions[i]?.height)

  removeRow: (row, transaction=true) ->
    @removeRowAt(@table.getRowIndex(row), transaction)

  removeRowAt: (index, transaction=true) ->
    rowHeight = @rowHeights[index]
    @table.removeRowAt(index, false, transaction)

    if transaction
      @table.ammendLastTransaction
        undo: (commit) =>
          commit.undo()
          @setRowHeightAt(index, rowHeight)
        redo: (commit) =>
          commit.redo()

  removeScreenRowAt: (row, transaction=true) ->
    @removeRowAt(@screenRowToModelRow(row))

  removeRowsInRange: (range, transaction=true) ->
    range = @rowRangeFrom(range)

    rowHeights = (@rowHeights[index] for index in [range.start...range.end])
    @table.removeRowsInRange(range, transaction)

    if transaction
      @table.ammendLastTransaction
        undo: (commit) =>
          commit.undo()
          for i in [range.start...range.end]
            @setRowHeightAt(i, rowHeights[i])
        redo: (commit) =>
          commit.redo()

  removeRowsInScreenRange: (range, transaction=true) ->
    range = @table.rowRangeFrom(range)

    if @order?
      rowIndices = (@screenRowToModelRow(i) for i in [range.start...range.end])
      rowHeights = (@rowHeights[index] for index in rowIndices)

      @table.removeRowsAtIndices(rowIndices, transaction)
    else
      rowIndices = [range.start...range.end]
      rowHeights = (@rowHeights[index] for index in rowIndices)

      @table.removeRowsInRange(range, transaction)

    if transaction
      @table.ammendLastTransaction
        undo: (commit) =>
          commit.undo()
          for index,i in rowIndices
            @setRowHeightAt(index, rowHeights[i])
        redo: (commit) =>
          commit.redo()

  computeRowOffsets: ->
    offsets = []
    offset = 0

    for i in [0...@table.getRowCount()]
      offsets.push offset
      offset += @getScreenRowHeightAt(i)

    @rowOffsets = offsets

  updateScreenRows: ->
    rows = @table.getRows()
    @screenRows = rows.concat()

    if @order?
      if typeof @order is 'function'
        @screenRows.sort(@order)
      else
        orderFunction = @compareRows(@order, @direction)
        @screenRows.sort(orderFunction)

    @screenToModelRowsMap = (rows.indexOf(row) for row in @screenRows)
    @modelToScreenRowsMap = (@screenRows.indexOf(row) for row in rows)
    @computeRowOffsets()

  compareRows: (order, direction=1) ->
    collator = new Intl.Collator("en-US", numeric: true)
    return (a,b) -> collator.compare(a[order],b[order]) * direction

  ##     ######  ######## ##       ##        ######
  ##    ##    ## ##       ##       ##       ##    ##
  ##    ##       ##       ##       ##       ##
  ##    ##       ######   ##       ##        ######
  ##    ##       ##       ##       ##             ##
  ##    ##    ## ##       ##       ##       ##    ##
  ##     ######  ######## ######## ########  ######

  getValueAtScreenPosition: (position) ->
    @getValueAtPosition(@modelPosition(position))

  setValueAtScreenPosition: (position, value, transaction=true) ->
    @setValueAtPosition(@modelPosition(position), value, false, transaction)

  setValuesAtScreenPositions: (positions, values, transaction=true) ->
    positions = positions.map (position) => @modelPosition(position)
    @setValuesAtPositions(positions, values, transaction)

  setValuesInScreenRange: (range, values, transaction=true) ->
    range = Range.fromObject(range)

    if @order?
      valuesRows = values.length
      valuesColumns = values[0].length
      positions = []

      flattenValues = []

      for row in [range.start.row...range.end.row]
        for column in [range.start.column...range.end.column]
          valuesRow = (row - range.start.row) % valuesRows
          valuesColumn = (column - range.start.column) % valuesColumns
          value = values[valuesRow][valuesColumn]

          flattenValues.push value
          positions.push @modelPosition([row, column])

      @setValuesAtPositions(positions, flattenValues, transaction)

    else
      @setValuesInRange(range, values, transaction)

  getScreenPositionAtPixelPosition: (x,y) ->
    return unless x? and y?

    row = @getScreenRowIndexAtPixelPosition(y)
    column = @getScreenColumnIndexAtPixelPosition(x)

    new Point(row, column)

  getPositionAtPixelPosition: (x,y) ->
    position = @getScreenPositionAtPixelPosition(x,y)
    position.row = @screenRowToModelRow(position.row)
    position

  screenPosition: (position) ->
    {row, column} = Point.fromObject(position)

    new Point(@modelRowToScreenRow(row), column)

  modelPosition: (position) ->
    {row, column} = Point.fromObject(position)

    new Point(@screenRowToModelRow(row), column)

  getScreenCellPosition: (position) ->
    position = Point.fromObject(position)
    {
      top: @getScreenRowOffsetAt(position.row)
      left: @getScreenColumnOffsetAt(position.column)
    }

  getScreenCellRect: (position) ->
    {top, left} = @getScreenCellPosition(position)

    width = @getScreenColumnWidthAt(position.column)
    height = @getScreenRowHeightAt(position.row)

    {top, left, width, height}

  ##     ######   #######  ########  ########
  ##    ##    ## ##     ## ##     ##    ##
  ##    ##       ##     ## ##     ##    ##
  ##     ######  ##     ## ########     ##
  ##          ## ##     ## ##   ##      ##
  ##    ##    ## ##     ## ##    ##     ##
  ##     ######   #######  ##     ##    ##

  sortBy: (order, @direction=1) ->
    if typeof order is 'string'
      @order = @table.getColumnIndex(order)
    else
      @order = order

    @updateScreenRows()
    @emitter.emit 'did-change', {
      oldScreenRange: {start: 0, end: @getRowCount()}
      newScreenRange: {start: 0, end: @getRowCount()}
    }

  toggleSortDirection: ->
    @direction *= -1
    @updateScreenRows()
    @emitter.emit 'did-change', {
      oldScreenRange: {start: 0, end: @getRowCount()}
      newScreenRange: {start: 0, end: @getRowCount()}
    }

  resetSort: ->
    @order = null
    @updateScreenRows()
    @emitter.emit 'did-change', {
      oldScreenRange: {start: 0, end: @getRowCount()}
      newScreenRange: {start: 0, end: @getRowCount()}
    }
