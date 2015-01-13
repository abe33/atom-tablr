_ = require 'underscore-plus'
{Point} = require 'atom'
{Emitter, Disposable, CompositeDisposable} = require 'event-kit'
Identifiable = require './mixins/identifiable'
Transactions = require './mixins/transactions'
Column = require './column'
Row = require './row'
Cell = require './cell'

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

  onDidChangeRowsOptions: (callback) ->
    @emitter.on 'did-change-rows-options', callback

  onDidChangeColumnsOptions: (callback) ->
    @emitter.on 'did-change-columns-options', callback

  #     ######   #######  ##       ##     ## ##     ## ##    ##  ######
  #    ##    ## ##     ## ##       ##     ## ###   ### ###   ## ##    ##
  #    ##       ##     ## ##       ##     ## #### #### ####  ## ##
  #    ##       ##     ## ##       ##     ## ## ### ## ## ## ##  ######
  #    ##       ##     ## ##       ##     ## ##     ## ##  ####       ##
  #    ##    ## ##     ## ##       ##     ## ##     ## ##   ### ##    ##
  #     ######   #######  ########  #######  ##     ## ##    ##  ######

  getColumns: -> @columns

  getColumn: (index) -> @columns[index]

  getColumnValues: (index) ->
    name = @columns[index].name
    @rows.map (row) => row[name]

  getColumnNames: -> @columns.map (column) -> column.name

  getColumnsCount: -> @columns.length

  addColumn: (name, options={}, transaction=true) ->
    @addColumnAt(@columns.length, name, options, transaction)

  addColumnAt: (index, name, options={}, transaction=true) ->
    if index < 0
      throw new Error "Can't add column #{name} at index #{index}"

    if typeof name is 'string'
      options.name = name
    else
      [options, transaction] = [name, options]
      {name} = options

    unless name?
      throw new Error "Can't add column without a name"

    if name in @getColumnNames()
      throw new Error "Can't add column #{name} as one already exist"

    column = new Column options

    @subscribeToColumn(column)
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
        redo: -> @addColumnAt(index, options, false)

    column

  removeColumn: (column) ->
    throw new Error "Can't remove an undefined column" unless column?

    @removeColumnAt(@columns.indexOf(column))

  removeColumnAt: (index, transaction=true) ->
    if index is -1 or index >= @columns.length
      throw new Error "Can't remove column at index #{index}"

    values = @getColumnValues(index) if transaction
    column = @columns[index]
    @unsubscribeFromColumn(column)
    @columns.splice(index, 1)
    row.removeCellAt(index) for row in @rows
    @emitter.emit 'did-remove-column', {column, index}

    if transaction
      {name, options} = column

      @transaction
        undo: ->
          @addColumnAt(index, name, options, false)
          @rows.forEach (row,i) -> row.setProperty(name, values[i], false)
        redo: -> @removeColumnAt(index, false)

  subscribeToColumn: (column) ->
    subscriptions = @columnSubscriptions[column.id] = new CompositeDisposable

    subscriptions.add column.onDidChangeName @updateRowsColumnAccessor
    subscriptions.add column.onDidChangeOption @registerColumnTransaction

  unsubscribeFromColumn: (column) ->
    @columnSubscriptions[column.id].dispose()
    delete @columnSubscriptions[column.id]

  registerColumnTransaction: (change) =>
    doChange = change
    undoChange = {
      column: change.column
      option: change.option
      newValue: change.oldValue
      oldValue: change.newValue
    }
    @emitter.emit 'did-change-columns-options', doChange
    @transaction
      undo: =>
        @emitter.emit 'did-change-columns-options', undoChange
        change.column.setOption(change.option, change.oldValue, true)
      redo: =>
        @emitter.emit 'did-change-columns-options', doChange
        change.column.setOption(change.option, change.newValue, true)

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

  addRow: (values, options, batch=false) ->
    @addRowAt(@rows.length, values, options, batch)

  addRowAt: (index, values={}, options, batch, transaction) ->
    [options, batch, transaction] = [{}, options, batch] if typeof options is 'boolean'

    options ?= {}
    batch ?= false
    transaction ?= true

    if index < 0
      throw new Error "Can't add column #{name} at index #{index}"

    if @getColumns().length is 0
      throw new Error "Can't add rows to a table without column"

    cells = []

    if Array.isArray(values)
      for column,i in @columns
        value = values[i]
        cell = new Cell {value, column}
        cells.push cell
    else
      for column in @columns
        value = values[column.name]
        cell = new Cell {value, column}
        cells.push cell

    row = new Row {cells, options, table: this}

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
      options = _.clone(row.options)
      @transaction
        undo: -> @removeRowAt(index, false, false)
        redo: -> @addRowAt(index, values, options, false, false)

    row

  addRows: (rows, options, transaction=true) ->
    @addRowsAt(@rows.length, rows, options, transaction)

  addRowsAt: (index, rows, options, transaction) ->
    [options, transaction] = [[], options] if typeof options is 'boolean'

    options ?= []
    transaction ?= true

    createdRows = rows.map (row,i) => @addRowAt(index+i, row, options[i], true)

    @emitter.emit 'did-change-rows', {
      oldRange: {start: index, end: index}
      newRange: {start: index, end: index+rows.length}
    }

    if transaction
      range = {start: index, end: index+rows.length}
      options = @getRowsInRange(range).map (row) -> _.clone(row.options)
      @transaction
        undo: -> @removeRowsInRange(range, false)
        redo: -> @addRowsAt(index, rows, options, false)

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
      values = row.getValues()
      options = _.clone(row.options)
      @transaction
        undo: -> @addRowAt(index, values, options, false, false)
        redo: -> @removeRowAt(index, false, false)

  removeRowsInRange: (range, transaction=true) ->
    range = @rangeFrom(range)

    rowsValues = []

    if transaction
      options = @getRowsInRange(range).map (row) -> _.clone(row.options)

    for i in [range.start...range.end]
      rowsValues.push @rows[range.start].getValues()
      @removeRowAt(range.start, true)

    @emitter.emit 'did-change-rows', {
      oldRange: range
      newRange: {start: range.start, end: range.start}
    }

    if transaction
      @transaction
        undo: -> @addRowsAt(range.start, rowsValues, options, false)
        redo: -> @removeRowsInRange(range, false)

  extendExistingRows: (column, index) ->
    row.addCellAt index, new Cell {column} for row in @rows

  updateRowsColumnAccessor: ({oldName, newName}) =>
    row.updateCellAccessorName(oldName, newName) for row in @rows

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

  getCells: ->
    @rows.reduce ((cells, row) -> cells.concat row.getCells()), []

  getCellsCount: -> @getCells().length

  cellAtPosition: (position) ->
    unless position?
      throw new Error "Table::cellAtPosition called without a position"

    position = Point.fromObject(position)
    @getRow(position.row)?.getCell(position.column)

  positionOfCell: (cell) ->
    unless cell?
      throw new Error "Table::positionOfCell called without a cell"

    row = @rows.indexOf(cell.row)
    column = cell.row.cells.indexOf(cell)

    {row, column}
