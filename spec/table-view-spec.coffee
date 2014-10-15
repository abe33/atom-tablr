{$} = require 'atom'

Table = require '../lib/table'
TableView = require '../lib/table-view'
Column = require '../lib/column'
Row = require '../lib/row'
Cell = require '../lib/cell'

describe 'TableView', ->
  [tableView, table] = []

  beforeEach ->
    table = new Table
    table.addColumn 'id'
    table.addColumn 'value'

    for i in [0...100]
      table.addRow ["row#{i}", Math.random() * 100]

    tableView = new TableView(table)
    tableView.height 200
    tableView.setRowHeight 20
    tableView.setRowOverdraw 10

    tableView.css
      position: 'relative'

    tableView.scrollView.css
      position: 'absolute'
      top: 27
      bottom: 0
      left: 0
      right: 0

    $('body').append(tableView)

  afterEach ->
    tableView.destroy()

  it 'holds a table', ->
    expect(tableView.table).toEqual(table)

  it 'has a scroll-view', ->
    expect(tableView.scrollView).toBeDefined()

  describe 'when not scrolled yet', ->
    it 'renders the lines at the top of the table', ->
      expect(tableView.tableNode.find('.row')).toEqual(18)

  describe '::getFirstVisibleRow', ->
    it 'returns 0 when the table view is not scrolled', ->
      expect(tableView.getFirstVisibleRow()).toEqual(0)

    describe 'when scrolled by 100px', ->
      it 'returns 5', ->
        tableView.scrollTop(100)
        expect(tableView.getFirstVisibleRow()).toEqual(5)

  describe '::getLastVisibleRow', ->
    it 'returns 8 when the table view is not scrolled', ->
      expect(tableView.getLastVisibleRow()).toEqual(8)

    describe 'when scrolled by 100px', ->
      it 'returns 13', ->
        tableView.scrollTop(100)
        expect(tableView.getFirstVisibleRow()).toEqual(13)
