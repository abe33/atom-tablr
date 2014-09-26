{Model} = require 'theorist'
{Emitter, Disposable, CompositeDisposable} = require 'event-kit'

Column = require './column'
Row = require './row'
Cell = require './cell'

module.exports =
class Table extends Model
  constructor: (options={}) ->
    @columns = []
    @rows = []
    @emitter = new Emitter
    @columnSubscriptions = {}

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

    column

  removeColumn: (column) ->
    throw new Error "Can't remove an undefined column" unless column?

    @removeColumnAt(@columns.indexOf(column))

  removeColumnAt: (index) ->
    if index is -1 or index >= @columns.length
      throw new Error "Can't remove column at index #{index}"

    @unsubscribeFromColumn(@columns[index])
    @columns.splice(index, 1)
    row.removeCellAt(index) for row in @rows

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

  getRow: (index) -> @rows[0]

  getRowsCount: -> @rows.length

  addRow: (values) ->
    if @getColumns().length is 0
      throw new Error "Can't add rows to a table without column"

    cells = []

    if Array.isArray(values)
    else
      for column in @columns
        value = values[column.name]
        cell = new Cell {value, column}
        cells.push cell

    row = new Row {cells, table: this}
    @rows.push row
    row

  removeRow: (row) ->
    throw new Error "Can't remove an undefined row" unless row?

    @removeRowAt(@rows.indexOf(row))

  removeRowAt: (index) ->
    if index is -1 or index >= @rows.length
      throw new Error "Can't remove row at index #{index}"

    @rows.splice(index, 1)

  extendExistingRows: (column, index) ->
    row.addCellAt index, new Cell {column} for row in @rows

  updateRowsColumnAccessor: ({oldName, newName}) =>
    row.updateCellAccessorName(oldName, newName) for row in @rows

  #     ######  ######## ##       ##        ######
  #    ##    ## ##       ##       ##       ##    ##
  #    ##       ##       ##       ##       ##
  #    ##       ######   ##       ##        ######
  #    ##       ##       ##       ##             ##
  #    ##    ## ##       ##       ##       ##    ##
  #     ######  ######## ######## ########  ######

  getCells: ->
    cells = []
    @rows.forEach (row) -> cells = cells.concat(row.getCells())
    cells

  getCellsCount: -> @getCells().length
