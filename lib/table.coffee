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

  getColumns: -> @columns

  getColumnNames: -> @columns.map (column) -> column.name

  addColumn: (name, options={}) ->
    if name in @getColumnNames()
      throw new Error "Can't add column #{name} as one already exist"
    column = new Column {name, options}
    @columns.push column

  getRows: -> @rows

  getRow: (index) -> @rows[0]

  addRow: (data) ->
    if @getColumns().length is 0
      throw new Error "Can't add rows to a table without colum"

    cells = []

    if Array.isArray(data)
    else
      for column in @columns
        value = data[column.name] ? null
        cell = new Cell {value, column}
        cells.push cell

    row = new Row {cells, table: this}
    @rows.push row
    row

  getCells: ->
    cells = []
    @rows.forEach (row) -> cells = cells.concat(row.getCells())
    cells
