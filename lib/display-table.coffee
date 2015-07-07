_ = require 'underscore-plus'
{Point, Emitter, CompositeDisposable} = require 'atom'
Delegator = require 'delegato'
Table = require './table'
DisplayColumn = require './display-column'

module.exports =
class DisplayTable
  Delegator.includeInto(this)

  @delegatesMethods 'changeColumnName', 'undo', 'redo', 'getColumnsCount', 'getRowsCount', 'clearUndoStack', 'clearRedoStack', 'setValueAtPosition', toProperty: 'table'

  rowOffsets: null
  columnOffsets: null

  constructor: (options={}) ->
    {@table} = options
    @table = new Table unless @table?
    @emitter = new Emitter
    @subscriptions = new CompositeDisposable
    @screenColumnsSubscriptions = new WeakMap

    @subscribeToConfig()
    @subscribeToTable()

    @screenColumns = @table.getColumns().map (column) =>
      screenColumn = new DisplayColumn({name: column})
      @subscribeToScreenColumn(screenColumn)
      screenColumn

    @rowsHeights = @table.getColumns().map (column) => @getRowHeight()
    @computeScreenColumnOffsets()
    @updateScreenRows()

  onDidAddColumn: (callback) ->
    @emitter.on 'did-add-column', callback

  onDidRemoveColumn: (callback) ->
    @emitter.on 'did-remove-column', callback

  onDidRenameColumn: (callback) ->
    @emitter.on 'did-rename-column', callback

  subscribeToTable: ->
    @subscriptions.add @table.onDidAddColumn ({column, index}) =>
      @addScreenColumn(index, {name: column})

    @subscriptions.add @table.onDidRemoveColumn ({column, index}) =>
      @removeScreenColumn(index, column)

    @subscriptions.add @table.onDidRenameColumn ({newName, oldName, index}) =>
      @screenColumns[index].setOption 'name', newName
      @emitter.emit('did-rename-column', {screenColumn: @screenColumns[index], oldName, newName, index})

    @subscriptions.add @table.onDidAddRow ({index}) =>
      @rowsHeights.splice(index, 0, undefined)
      @updateScreenRows()

    @subscriptions.add @table.onDidRemoveRow ({index}) =>
      @rowsHeights.splice(index, 1)
      @updateScreenRows()

  subscribeToConfig: ->
    @observeConfig
      'table-edit.undefinedDisplay': (@configUndefinedDisplay) =>
      'table-edit.rowHeight': (@configRowHeight) =>
        @computeRowOffsets() if @rowsHeights?
      'table-edit.minimumRowHeight': (@configMinimumRowHeight) =>
        @computeRowOffsets() if @rowsHeights?
      'table-edit.columnWidth': (@configScreenColumnWidth) =>
        @computeScreenColumnOffsets() if @screenColumns?
      'table-edit.minimumColumnWidth': (@configMinimumScreenColumnWidth) =>
        @computeScreenColumnOffsets() if @screenColumns?

  observeConfig: (configs) ->
    for config, callback of configs
      @subscriptions.add atom.config.observe config, callback

  ##     ######   #######  ##       ##     ## ##     ## ##    ##  ######
  ##    ##    ## ##     ## ##       ##     ## ###   ### ###   ## ##    ##
  ##    ##       ##     ## ##       ##     ## #### #### ####  ## ##
  ##    ##       ##     ## ##       ##     ## ## ### ## ## ## ##  ######
  ##    ##       ##     ## ##       ##     ## ##     ## ##  ####       ##
  ##    ##    ## ##     ## ##       ##     ## ##     ## ##   ### ##    ##
  ##     ######   #######  ########  #######  ##     ## ##    ##  ######

  removeScreenColumn: (index, column) ->
    screenColumn = @screenColumns[index]
    @unsubscribeFromScreenColumn(screenColumn)
    @screenColumns.splice(index, 1)
    @computeScreenColumnOffsets()
    @emitter.emit('did-remove-column', {screenColumn, column, index})

  addScreenColumn: (index, options) ->
    screenColumn = new DisplayColumn(options)
    @subscribeToScreenColumn(screenColumn)
    @screenColumns.splice(index, 0, screenColumn)
    @computeScreenColumnOffsets()
    @emitter.emit('did-add-column', {screenColumn, column: options.name, index})

  getScreenColumns: -> @screenColumns

  getScreenColumnsCount: -> @screenColumns.length

  getScreenColumn: (index) -> @screenColumns[index]

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
    @computeScreenColumnOffsets()

  getScreenColumnOffsetAt: (column) -> @screenColumnOffsets[column]

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

  unsubscribeFromScreenColumn: (screenColumn) ->
    subs = @screenColumnsSubscriptions.get(screenColumn)
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

  getScreenRows: -> @screenRows

  getScreenRowsCount: -> @screenRows.length

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
    @requestUpdate()

  getRowHeightAt: (index) ->
    @rowsHeights[index] ? @getRowHeight()

  setRowHeightAt: (index, height) ->
    minHeight = @getMinimumRowHeight()
    height = minHeight if height < minHeight
    @rowsHeights[index] = height
    @computeRowOffsets()

  getRowOffsetAt: (index) -> @getScreenRowOffsetAt(@modelRowToScreenRow(index))

  addRow: (row, options={}, transaction=true) ->
    @addRowAt(@table.getRowsCount(), row, options, transaction)

  addRowAt: (index, row, options={}, transaction=true) ->
    @table.addRowAt(index, row, false, transaction)
    @setRowHeightAt(index, options.height) if options.height?

    if transaction
      @table.ammendLastTransaction
        undo: (commit) =>
          commit.undo()
        redo: (commit) =>
          commit.redo()
          @setRowHeightAt(index, options.height) if options.height?

  removeRow: (row, transaction=true) ->
    @removeRowAt(@table.getRowIndex(row), transaction)

  removeRowAt: (index, transaction=true) ->
    rowHeight = @rowsHeights[index]
    @table.removeRowAt(index, false, transaction)

    if transaction
      @table.ammendLastTransaction
        undo: (commit) =>
          commit.undo()
          @setRowHeightAt(index, rowHeight)
        redo: (commit) =>
          commit.redo()

  computeRowOffsets: ->
    offsets = []
    offset = 0

    for i in [0...@table.getRowsCount()]
      offsets.push offset
      offset += @getScreenRowHeightAt(i)

    @rowOffsets = offsets

  sortBy: (@order, @direction=1) ->
    @updateScreenRows()

  updateScreenRows: ->
    rows = @table.getRows()
    @screenRows = rows.concat()

    if @order?
      if typeof @order is 'function'
        @screenRows.sort(@order)
      else
        orderFunction = @compareRows(@table.getColumnIndex(@order), @direction)
        @screenRows.sort(orderFunction)

    @screenToModelRowsMap = (rows.indexOf(row) for row in @screenRows)
    @modelToScreenRowsMap = (@screenRows.indexOf(row) for row in rows)
    @computeRowOffsets()

  compareRows: (order, direction) -> (a,b) ->
    a = a[order]
    b = b[order]
    if a > b
      direction
    else if a < b
      -direction
    else
      0

  ##     ######  ######## ##       ##        ######
  ##    ##    ## ##       ##       ##       ##    ##
  ##    ##       ##       ##       ##       ##
  ##    ##       ######   ##       ##        ######
  ##    ##       ##       ##       ##             ##
  ##    ##    ## ##       ##       ##       ##    ##
  ##     ######  ######## ######## ########  ######

  setValueAtScreenPosition: (position, value) ->
    @setValueAtPosition(@modelPosition(position), value)

  screenPosition: (position) ->
    {row, column} = Point.fromObject(position)

    {row: @modelRowToScreenRow(row), column}

  modelPosition: (position) ->
    {row, column} = Point.fromObject(position)

    {row: @screenRowToModelRow(row), column}

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
