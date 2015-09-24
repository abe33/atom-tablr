{Point} = require 'atom'
{Emitter, Disposable, CompositeDisposable} = require 'event-kit'
Identifiable = require './mixins/identifiable'
Transactions = require './mixins/transactions'
Range = require './range'

module.exports =
class Table
  Identifiable.includeInto(this)
  Transactions.includeInto(this)

  atom.deserializers.add(this)

  @MAX_HISTORY_SIZE: 100

  @deserialize: (state) ->
    table = new Table(state)
    table.initializeAfterSetup()
    table

  constructor: (state={}) ->
    {@id, @columns, @rows, modified} = state
    @cachedContents = state.cachedContents ? '' if modified
    @initID() unless @id?
    @columns ?= []
    @rows ?= []
    @emitter = new Emitter
    @refcount = 0

  destroy: ->
    return if @destroyed
    @emitter.emit 'did-destroy', this
    @emitter.dispose()
    @columns = []
    @rows = []
    @destroyed = true

  hasMultipleEditors: -> @refcount > 0

  isModified: -> @cachedContents isnt @getCacheContent()

  isDestroyed: -> @destroyed

  isRetained: -> @refcount > 0

  retain: ->
    @refcount++
    this

  release: ->
    @refcount--
    @destroy() unless @isRetained()
    this

  save: ->
    return unless @lastModified

    @emitter.emit 'will-save', this

    if @saveHandler?
      saved = @saveHandler(this)
      if saved instanceof Promise
        saved.then =>
          @updateCachedContents()
          @emitter.emit 'did-save', this
          @emitModifiedStatusChange()
        saved.catch (reason) ->
          console.error reason
      else
        @emitModifiedStatusChange()

        if saved
          @updateCachedContents()
          @emitter.emit 'did-save', this
    else
      @updateCachedContents()
      @emitter.emit 'did-save', this
      @emitModifiedStatusChange()

  serialize: ->
    out = {@columns, @rows, @id, deserializer: 'Table'}

    if @lastModified
      out.modified = true
      out.cachedContents = @cachedContents

    out

  setSaveHandler: (@saveHandler) ->

  updateCachedContents: ->
    @cachedContents = @getCacheContent()

  getCacheContent: ->
    res = [@columns].concat(@rows).join('\n')

  initializeAfterSetup: ->
    @clearUndoStack()
    @updateCachedContents() unless @cachedContents?
    @lastModified = false

  lockModifiedStatus: ->
    @modifiedLock = true

  unlockModifiedStatus: ->
    @modifiedLock = false
    @emitModifiedStatusChange()

  emitModifiedStatusChange: ->
    return if @modifiedLock

    modified = @isModified()
    return if @lastModified is modified

    @emitter.emit 'did-change-modified', modified
    @lastModified = modified


  #    ######## ##     ## ######## ##    ## ########  ######
  #    ##       ##     ## ##       ###   ##    ##    ##    ##
  #    ##       ##     ## ##       ####  ##    ##    ##
  #    ######   ##     ## ######   ## ## ##    ##     ######
  #    ##        ##   ##  ##       ##  ####    ##          ##
  #    ##         ## ##   ##       ##   ###    ##    ##    ##
  #    ########    ###    ######## ##    ##    ##     ######

  onWillSave: (callback) ->
    @emitter.on 'did-save', callback

  onDidSave: (callback) ->
    @emitter.on 'did-save', callback

  onDidChangeModified: (callback) ->
    @emitter.on 'did-change-modified', callback

  onDidAddColumn: (callback) ->
    @emitter.on 'did-add-column', callback

  onDidRemoveColumn: (callback) ->
    @emitter.on 'did-remove-column', callback

  onDidRenameColumn: (callback) ->
    @emitter.on 'did-rename-column', callback

  onDidAddRow: (callback) ->
    @emitter.on 'did-add-row', callback

  onDidRemoveRow: (callback) ->
    @emitter.on 'did-remove-row', callback

  onDidChange: (callback) ->
    @emitter.on 'did-change', callback

  onDidChangeCellValue: (callback) ->
    @emitter.on 'did-change-cell-value', callback

  onDidDestroy: (callback) ->
    @emitter.on 'did-destroy', callback

  #     ######   #######  ##       ##     ## ##     ## ##    ##  ######
  #    ##    ## ##     ## ##       ##     ## ###   ### ###   ## ##    ##
  #    ##       ##     ## ##       ##     ## #### #### ####  ## ##
  #    ##       ##     ## ##       ##     ## ## ### ## ## ## ##  ######
  #    ##       ##     ## ##       ##     ## ##     ## ##  ####       ##
  #    ##    ## ##     ## ##       ##     ## ##     ## ##   ### ##    ##
  #     ######   #######  ########  #######  ##     ## ##    ##  ######

  getColumns: -> @columns.slice()

  getColumn: (index) -> @columns[index]

  getColumnIndex: (column) -> @columns.indexOf(column)

  getColumnValues: (index) -> @rows.map (row) => row[index]

  getColumnNames: -> @columns.concat()

  getColumnCount: -> @columns.length

  addColumn: (name, transaction=true, event=true) ->
    @addColumnAt(@columns.length, name, transaction, event)

  addColumnAt: (index, column, transaction=true, event=true) ->
    throw new Error "Can't add column to a destroyed table" if @isDestroyed()
    throw new Error "Can't add column #{column} at index #{index}" if index < 0

    @extendExistingRows(column, index)

    if index >= @columns.length
      index = @columns.length
      @columns.push column
    else
      @columns.splice index, 0, column

    @emitModifiedStatusChange()
    @emitter.emit 'did-add-column', {column, index} if event

    if transaction
      @transaction
        undo: -> @removeColumnAt(index, false)
        redo: -> @addColumnAt(index, column, false)

    column

  removeColumn: (column, transaction=true, event=true) ->
    throw new Error "Can't remove an undefined column" unless column?

    @removeColumnAt(@columns.indexOf(column), transaction, event)

  removeColumnAt: (index, transaction=true, event=true) ->
    if index is -1 or index >= @columns.length
      throw new Error "Can't remove column at index #{index}"

    values = @getColumnValues(index) if transaction

    column = @columns[index]
    @columns.splice(index, 1)
    row.splice(index, 1) for row in @rows

    @emitModifiedStatusChange()
    @emitter.emit 'did-remove-column', {column, index} if event

    if transaction
      @transaction
        undo: ->
          @addColumnAt(index, column, false)
          @rows.forEach (row,i) -> row[index] = values[i]
        redo: -> @removeColumnAt(index, false)

    column

  changeColumnName: (column, newName, transaction=true, event=true) ->
    index = @columns.indexOf(column)

    @columns[index] = newName
    @emitModifiedStatusChange()

    if event
      @emitter.emit('did-rename-column', {oldName: column, newName, index})

    if transaction
      @transaction
        undo: ->
          @columns[index] = column
          @emitModifiedStatusChange()
        redo: ->
          @columns[index] = newName
          @emitModifiedStatusChange()

    return

  #    ########   #######  ##      ##  ######
  #    ##     ## ##     ## ##  ##  ## ##    ##
  #    ##     ## ##     ## ##  ##  ## ##
  #    ########  ##     ## ##  ##  ##  ######
  #    ##   ##   ##     ## ##  ##  ##       ##
  #    ##    ##  ##     ## ##  ##  ## ##    ##
  #    ##     ##  #######   ###  ###   ######

  getRows: -> @rows.slice()

  getRow: (index) -> @rows[index]

  getRowIndex: (row) -> @rows.indexOf(row)

  getRowCount: -> @rows.length

  getRowsInRange: (range) ->
    range = @rowRangeFrom(range)
    @rows[range.start...range.end]

  getFirstRow: -> @rows[0]

  getLastRow: -> @rows[@rows.length - 1]

  addRow: (values, batch=false, transaction=true) ->
    @addRowAt(@rows.length, values, batch, transaction)

  addRowAt: (index, values={}, batch=false, transaction=true) ->
    throw new Error "Can't add row to a destroyed table" if @isDestroyed()
    throw new Error "Can't add row #{values} at index #{index}" if index < 0

    if @columns.length is 0
      throw new Error "Can't add rows to a table without column"

    row = []

    if Array.isArray(values)
      row = values.concat()
    else
      row.push values[column] for column in @columns

    if index >= @rows.length
      @rows.push row
    else
      @rows.splice index, 0, row

    @emitter.emit 'did-add-row', {row, index}

    unless batch
      @emitModifiedStatusChange()
      @emitter.emit 'did-change', {
        oldRange: {start: index, end: index}
        newRange: {start: index, end: index+1}
      }

      if transaction
        @transaction
          undo: -> @removeRowAt(index, false, false)
          redo: -> @addRowAt(index, values, false, false)

    row

  addRows: (rows, transaction=true) ->
    @addRowsAt(@rows.length, rows, transaction)

  addRowsAt: (index, rows, transaction=true) ->
    throw new Error "Can't add rows to a destroyed table" if @isDestroyed()

    createdRows = rows.map (row,i) => @addRowAt(index+i, row, true)

    @emitModifiedStatusChange()
    @emitter.emit 'did-change', {
      oldRange: {start: index, end: index}
      newRange: {start: index, end: index+rows.length}
    }

    if transaction
      range = {start: index, end: index+rows.length}
      @transaction
        undo: -> @removeRowsInRange(range, false)
        redo: -> @addRowsAt(index, rows, false)

    createdRows

  removeRow: (row, batch=false, transaction=true) ->
    throw new Error "Can't remove an undefined row" unless row?

    @removeRowAt(@rows.indexOf(row), batch, transaction)

  removeRowAt: (index, batch=false, transaction=true) ->
    if index is -1 or index >= @rows.length
      throw new Error "Can't remove row at index #{index}"

    row = @rows[index]
    @rows.splice(index, 1)

    @emitter.emit 'did-remove-row', {row, index}
    unless batch
      @emitModifiedStatusChange()
      @emitter.emit 'did-change', {
        oldRange: {start: index, end: index+1}
        newRange: {start: index, end: index}
      }

      if transaction
        values = row.slice()
        @transaction
          undo: -> @addRowAt(index, values, false, false)
          redo: -> @removeRowAt(index, false, false)

    row

  removeRowsInRange: (range, transaction=true) ->
    range = @rowRangeFrom(range)

    removedRows = @rows.splice(range.start, range.end - range.start)
    rowsValues = removedRows.map((row) -> row.slice()) if transaction

    for row,i in removedRows
      @emitter.emit 'did-remove-row', {row, index: range.start}

    @emitModifiedStatusChange()
    @emitter.emit 'did-change', {
      oldRange: range
      newRange: {start: range.start, end: range.start}
    }

    if transaction
      @transaction
        undo: -> @addRowsAt(range.start, rowsValues, false)
        redo: -> @removeRowsInRange(range, false)

    removedRows

  removeRowsAtIndices: (indices, transaction=true) ->
    indices = indices.slice().sort()
    removedRows = (@rows[index] for index in indices)
    rowsValues = removedRows.map((row) -> row.slice()) if transaction

    @removeRow(row, true, false) for row in removedRows when row?

    if transaction
      @transaction
        undo: ->
          @addRowAt(index, rowsValues[i], true, false) for index,i in indices
          @emitter.emit 'did-change', {rowIndices: indices.slice()}
        redo: ->
          @removeRowsAtIndices(indices, false)

    @emitter.emit 'did-change', {rowIndices: indices.slice()}

    removedRows

  extendExistingRows: (column, index) ->
    row.splice index, 0, undefined for row in @rows

  rowRangeFrom: (range) ->
    throw new Error "Can't remove rows with a range" unless range?

    range = {start: range[0], end: range[1]} if Array.isArray range

    unless range.start? and range.end?
      throw new Error "Invalid range #{range}"

    range.start = 0 if range.start < 0
    range.end = @getRowCount() if range.end > @getRowCount()

    range

  #     ######  ######## ##       ##        ######
  #    ##    ## ##       ##       ##       ##    ##
  #    ##       ##       ##       ##       ##
  #    ##       ######   ##       ##        ######
  #    ##       ##       ##       ##             ##
  #    ##    ## ##       ##       ##       ##    ##
  #     ######  ######## ######## ########  ######

  getCells: -> @rows.reduce ((cells, row) -> cells.concat row), []

  getCellCount: -> @rows.length * @columns.length

  getValueAtPosition: (position) ->
    unless position?
      throw new Error "Table::getValueAtPosition called without a position"

    position = Point.fromObject(position)
    @rows[position.row]?[position.column]

  setValueAtPosition: (position, value, batch=false, transaction=true) ->
    unless position?
      throw new Error "Table::setValueAtPosition called without a position"
    if position.row < 0 or position.row >= @getRowCount() or position.column < 0 or position.column >= @getColumnCount()
      throw new Error "Table::setValueAtPosition called without an invalid position #{position}"

    position = Point.fromObject(position)
    oldValue = @rows[position.row]?[position.column]
    @rows[position.row]?[position.column] = value

    unless batch
      @emitModifiedStatusChange()
      @emitter.emit 'did-change-cell-value', {
        position
        oldValue
        newValue: value
      }

      if transaction
        @transaction
          undo: -> @setValueAtPosition(position, oldValue, batch, false)
          redo: -> @setValueAtPosition(position, value, batch, false)

    return

  setValuesAtPositions: (positions, values, transaction=true) ->
    oldValues = []

    for position,i in positions
      position = Point.fromObject(position)
      oldValues.push @rows[position.row]?[position.column]
      @rows[position.row]?[position.column] = values[i % values.length]

    @emitModifiedStatusChange()
    @emitter.emit 'did-change-cell-value', {
      positions
      oldValues
      newValues: values
    }

    if transaction
      positions = positions.slice()
      values = values.slice()
      @transaction
        undo: -> @setValuesAtPositions(positions, oldValues, false)
        redo: -> @setValuesAtPositions(positions, values, false)

    return

  setValuesInRange: (range, values, transaction=true) ->
    range = Range.fromObject(range)
    oldValues = []

    valuesRows = values.length
    valuesColumns = values[0].length

    for row in [range.start.row...range.end.row]
      oldRowValues = []
      oldValues.push oldRowValues
      for column in [range.start.column...range.end.column]
        valuesRow = (row - range.start.row) % valuesRows
        valuesColumn = (column - range.start.column) % valuesColumns

        oldRowValues.push @rows[row]?[column]
        @rows[row]?[column] = values[valuesRow][valuesColumn]

    @emitModifiedStatusChange()
    @emitter.emit 'did-change-cell-value', {
      range
      oldValues
      newValues: values
    }

    if transaction
      values = values.map (a) -> a.slice()
      @transaction
        undo: -> @setValuesInRange(range, oldValues, false)
        redo: -> @setValuesInRange(range, values, false)

    return
