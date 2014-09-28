{Emitter, Disposable, CompositeDisposable} = require 'event-kit'

Identifiable = require './mixins/identifiable'
Column = require './column'
Row = require './row'
Cell = require './cell'

module.exports =
class Table
  Identifiable.includeInto(this)

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

  #     ######   #######  ##       ##     ## ##     ## ##    ##  ######
  #    ##    ## ##     ## ##       ##     ## ###   ### ###   ## ##    ##
  #    ##       ##     ## ##       ##     ## #### #### ####  ## ##
  #    ##       ##     ## ##       ##     ## ## ### ## ## ## ##  ######
  #    ##       ##     ## ##       ##     ## ##     ## ##  ####       ##
  #    ##    ## ##     ## ##       ##     ## ##     ## ##   ### ##    ##
  #     ######   #######  ########  #######  ##     ## ##    ##  ######

  getColumns: -> @columns

  getColumn: (index) -> @columns[index]

  getColumnNames: -> @columns.map (column) -> column.name

  getColumnsCount: -> @columns.length

  addColumn: (name, options={}) ->
    @addColumnAt(@columns.length, name, options)

  addColumnAt: (index, name, options={}) ->
    if index < 0
      throw new Error "Can't add column #{name} at index #{index}"

    if name in @getColumnNames()
      throw new Error "Can't add column #{name} as one already exist"

    column = new Column {name, options}

    @subscribeToColumn(column)
    @extendExistingRows(column, index)

    if index >= @columns.length
      @columns.push column
    else
      @columns.splice index, 0, column

    @emitter.emit 'did-add-column', {column}

    column

  removeColumn: (column) ->
    throw new Error "Can't remove an undefined column" unless column?

    @removeColumnAt(@columns.indexOf(column))

  removeColumnAt: (index) ->
    if index is -1 or index >= @columns.length
      throw new Error "Can't remove column at index #{index}"

    column = @columns[index]
    @unsubscribeFromColumn(column)
    @columns.splice(index, 1)
    row.removeCellAt(index) for row in @rows
    @emitter.emit 'did-remove-column', {column}

  subscribeToColumn: (column) ->
    subscriptions = @columnSubscriptions[column.id] = new CompositeDisposable

    subscriptions.add column.onDidChangeName @updateRowsColumnAccessor

  unsubscribeFromColumn: (column) ->
    @columnSubscriptions[column.id].dispose()
    delete @columnSubscriptions[column.id]

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

  addRow: (values, batch=false) ->
    @addRowAt(@rows.length, values, batch)

  addRowAt: (index, values={}, batch=false) ->
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

    row = new Row {cells, table: this}

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

    row

  addRows: (rows) ->
    index = @rows.length
    rows.forEach (row) => @addRow(row, true)
    @emitter.emit 'did-change-rows', {
      oldRange: {start: index, end: index}
      newRange: {start: index, end: index+rows.length}
    }

  addRowsAt: (index, rows) ->
    rows.forEach (row,i) => @addRowAt(index+i, row, true)
    @emitter.emit 'did-change-rows', {
      oldRange: {start: index, end: index}
      newRange: {start: index, end: index+rows.length}
    }

  removeRow: (row, batch=false) ->
    throw new Error "Can't remove an undefined row" unless row?

    @removeRowAt(@rows.indexOf(row), batch)

  removeRowAt: (index, batch=false) ->
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

  removeRowsInRange: (range) ->
    range = @rangeFrom(range)

    for i in [range.start...range.end]
      @removeRowAt(range.start, true)

    @emitter.emit 'did-change-rows', {
      oldRange: range
      newRange: {start: range.start, end: range.start}
    }

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
