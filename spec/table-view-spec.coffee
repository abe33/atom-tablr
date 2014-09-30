Table = require '../lib/table'
TableView = require '../lib/table-view'
Column = require '../lib/column'
Row = require '../lib/row'
Cell = require '../lib/cell'

describe 'TableView', ->
  [tableView, table] = []

  beforeEach ->
    table = new Table
    table.addColumn 'key'
    table.addColumn 'value'

    table.addRow ['first_name', 'Cédric']
    table.addRow ['last_name', 'Néhémie']

    tableView = new TableView()
    tableView.initialize(table)

  it 'holds a table', ->
    expect(tableView.table).toEqual(table)
