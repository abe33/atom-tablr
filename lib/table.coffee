_ = require 'underscore-plus'
{Point} = require 'atom'
{Emitter, Disposable, CompositeDisposable} = require 'event-kit'
Identifiable = require './mixins/identifiable'
Transactions = require './mixins/transactions'

module.exports =
class Table
  Identifiable.includeInto(this)
  Transactions.includeInto(this)

  @MAX_HISTORY_SIZE: 100

  constructor: (options={}) ->
    @initID()
    @columns = []
    @rows = []
    @emitter = new Emitter
    @columnSubscriptions = {}

  #    ######## ##     ## ######## ##    ## ########  ######
  #    ##       ##     ## ##       ###   ##    ##    ##    ##
  #    ##       ##     ## ##       ####  ##    ##    ##
  #    ######   ##     ## ######   ## ## ##    ##     ######
  #    ##        ##   ##  ##       ##  ####    ##          ##
  #    ##         ## ##   ##       ##   ###    ##    ##    ##
  #    ########    ###    ######## ##    ##    ##     ######

  onDidAddColumn: (callback) ->
    @emitter.on 'did-add-column', callback

  onDidRemoveColumn: (callback) ->
    @emitter.on 'did-remove-column', callback

  onDidAddRow: (callback) ->
    @emitter.on 'did-add-row', callback

  onDidRemoveRow: (callback) ->
    @emitter.on 'did-remove-row', callback

  onDidChangeRows: (callback) ->
    @emitter.on 'did-change-rows', callback

  onDidChangeCellValue: (callback) ->
    @emitter.on 'did-change-cell-value', callback

  #     ######   #######  ##       ##     ## ##     ## ##    ##  ######
  #    ##    ## ##     ## ##       ##     ## ###   ### ###   ## ##    ##
  #    ##       ##     ## ##       ##     ## #### #### ####  ## ##
  #    ##       ##     ## ##       ##     ## ## ### ## ## ## ##  ######
  #    ##       ##     ## ##       ##     ## ##     ## ##  ####       ##
  #    ##    ## ##     ## ##       ##     ## ##     ## ##   ### ##    ##
  #     ######   #######  ########  #######  ##     ## ##    ##  ######

  getColumns: -> @columns

  getColumn: (index) -> @columns[index]

  getColumnValues: (index) -> @rows.map (row) => row[index]

  getColumnNames: -> @columns.concat()

  getColumnsCount: -> @columns.length

  addColumn: (name, transaction=true) ->
    @addColumnAt(@columns.length, name, transaction)

  addColumnAt: (index, column, transaction=true) ->
    throw new Error "Can't add column #{column} at index #{index}" if index < 0
    throw new Error "Can't add column without a name" unless column?

    if column in @columns
      throw new Error "Can't add column #{column} as one already exist"

    @extendExistingRows(column, index)

    if index >= @columns.length
      index = @columns.length
      @columns.push column
    else
      @columns.splice index, 0, column

    @emitter.emit 'did-add-column', {column}

    if transaction
      @transaction
        undo: -> @removeColumnAt(index, false)
        redo: -> @addColumnAt(index, column, false)

    column

  removeColumn: (column, transaction=true) ->
    throw new Error "Can't remove an undefined column" unless column?

    @removeColumnAt(@columns.indexOf(column), transaction)

  removeColumnAt: (index, transaction=true) ->
    if index is -1 or index >= @columns.length
      throw new Error "Can't remove column at index #{index}"

    values = @getColumnValues(index) if transaction

    column = @columns[index]
    @columns.splice(index, 1)
    row.splice(index, 1) for row in @rows
    @emitter.emit 'did-remove-column', {column, index}

    if transaction
      @transaction
        undo: ->
          @addColumnAt(index, column, false)
          @rows.forEach (row,i) -> row[index] = values[i]
        redo: -> @removeColumnAt(index, false)

  changeColumnName: (column, newName, transaction=true) ->
    index = @columns.indexOf(column)

    @columns[index] = newName

    if transaction
      @transaction
        undo: -> @columns[index] = column
        redo: -> @columns[index] = newName

  #    ########   #######  ##      ##  ######
  #    ##     ## ##     ## ##  ##  ## ##    ##
  #    ##     ## ##     ## ##  ##  ## ##
  #    ########  ##     ## ##  ##  ##  ######
  #    ##   ##   ##     ## ##  ##  ##       ##
  #    ##    ##  ##     ## ##  ##  ## ##    ##
  #    ##     ##  #######   ###  ###   ######

  getRows: -> @rows

  getRow: (index) -> @rows[index]

  getRowsCount: -> @rows.length

  getRowsInRange: (range) ->
    range = @rangeFrom(range)
    @rows[range.start...range.end]

  getFirstRow: -> @rows[0]

  getLastRow: -> @rows[@rows.length - 1]

  addRow: (values, batch=false, transaction=true) ->
    @addRowAt(@rows.length, values, batch, transaction)

  addRowAt: (index, values={}, batch=false, transaction=true) ->
    throw new Error "Can't add column #{name} at index #{index}" if index < 0

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

    @emitter.emit 'did-add-row', {row}
    unless batch
      @emitter.emit 'did-change-rows', {
        oldRange: {start: index, end: index}
        newRange: {start: index, end: index+1}
      }

    if not batch and transaction
      @transaction
        undo: -> @removeRowAt(index, false, false)
        redo: -> @addRowAt(index, values, false, false)

    row

  addRows: (rows, transaction=true) ->
    @addRowsAt(@rows.length, rows, transaction)

  addRowsAt: (index, rows, transaction=true) ->
    createdRows = rows.map (row,i) => @addRowAt(index+i, row, true)

    @emitter.emit 'did-change-rows', {
      oldRange: {start: index, end: index}
      newRange: {start: index, end: index+rows.length}
    }

    if transaction
      range = {start: index, end: index+rows.length}
      @transaction
        undo: -> @removeRowsInRange(range, false)
        redo: -> @addRowsAt(index, rows, false)

    createdRows

  removeRow: (row, batch=false) ->
    throw new Error "Can't remove an undefined row" unless row?

    @removeRowAt(@rows.indexOf(row), batch)

  removeRowAt: (index, batch=false, transaction=true) ->
    if index is -1 or index >= @rows.length
      throw new Error "Can't remove row at index #{index}"

    row = @rows[index]
    @rows.splice(index, 1)

    @emitter.emit 'did-remove-row', {row}
    unless batch
      @emitter.emit 'did-change-rows', {
        oldRange: {start: index, end: index+1}
        newRange: {start: index, end: index}
      }

    if not batch and transaction
      values = row.concat()
      @transaction
        undo: -> @addRowAt(index, values, false, false)
        redo: -> @removeRowAt(index, false, false)

  removeRowsInRange: (range, transaction=true) ->
    range = @rangeFrom(range)

    rowsValues = []

    range.end = @getRowsCount() if range.end is Infinity

    for i in [range.start...range.end]
      rowsValues.push @rows[range.start].concat()
      @removeRowAt(range.start, true)

    @emitter.emit 'did-change-rows', {
      oldRange: range
      newRange: {start: range.start, end: range.start}
    }

    if transaction
      @transaction
        undo: -> @addRowsAt(range.start, rowsValues, false)
        redo: -> @removeRowsInRange(range, false)

  extendExistingRows: (column, index) ->
    row.splice index, 0, undefined for row in @rows

  rangeFrom: (range) ->
    throw new Error "Can't remove rows with a range" unless range?

    range = {start: range[0], end: range[1]} if Array.isArray range

    unless range.start? and range.end?
      throw new Error "Invalid range #{range}"

    range

  rowUpdated: ({row, cell, newValue, oldValue, transaction}) ->
    transaction ?= true

    index = @rows.indexOf(row)
    @emitter.emit 'did-change-rows', {
      oldRange: {start: index, end: index}
      newRange: {start: index, end: index}
    }
    if transaction
      @transaction
        undo: -> row.setProperty(cell, oldValue, false)
        redo: -> row.setProperty(cell, newValue, false)

  rowOptionUpdated: ({row, option, newValue, oldValue, transaction}) ->
    transaction ?= true

    index = @rows.indexOf(row)
    @emitter.emit 'did-change-rows-options', {
      row
      option
      oldValue
      newValue
      range: {start: index, end: index}
    }
    if transaction
      @transaction
        undo: -> row.setOption(option, oldValue, false)
        redo: -> row.setOption(option, newValue, false)

  #     ######  ######## ##       ##        ######
  #    ##    ## ##       ##       ##       ##    ##
  #    ##       ##       ##       ##       ##
  #    ##       ######   ##       ##        ######
  #    ##       ##       ##       ##             ##
  #    ##    ## ##       ##       ##       ##    ##
  #     ######  ######## ######## ########  ######

  getCells: -> @rows.reduce ((cells, row) -> cells.concat row), []

  getCellsCount: -> @rows.length * @columns.length

  cellAtPosition: (position) ->
    unless position?
      throw new Error "Table::cellAtPosition called without a position"

    position = Point.fromObject(position)
    @rows[position.row]?[position.column]

  setValueAtPosition: (position, value, transaction=true) ->
    unless position?
      throw new Error "Table::setValueAtPosition called without a position"
    if position.row < 0 or position.row >= @getRowsCount() or position.column < 0 or position.column >= @getColumnsCount()
      throw new Error "Table::setValueAtPosition called without an invalid position #{position}"

    position = Point.fromObject(position)
    oldValue = @rows[position.row]?[position.column]
    @rows[position.row]?[position.column] = value

    @emitter.emit 'did-change-cell-value', {position, oldValue, newValue: value}

    if transaction
      @transaction
        undo: -> @setValueAtPosition(position, oldValue, false)
        redo: -> @setValueAtPosition(position, value, false)

  positionOfCell: (cell) ->
    unless cell?
      throw new Error "Table::positionOfCell called without a cell"

    row = @rows.indexOf(cell.row)
    column = cell.row.cells.indexOf(cell)

    {row, column}
