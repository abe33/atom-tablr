{$} = require 'atom'

Table = require '../lib/table'
TableView = require '../lib/table-view'
Column = require '../lib/column'
Row = require '../lib/row'
Cell = require '../lib/cell'

describe 'TableView', ->
  [tableView, table, nextAnimationFrame, noAnimationFrame, requestAnimationFrameSafe, styleNode] = []

  beforeEach ->
    spyOn(window, "setInterval").andCallFake window.fakeSetInterval
    spyOn(window, "clearInterval").andCallFake window.fakeClearInterval

    noAnimationFrame = -> throw new Error('No animation frame requested')
    nextAnimationFrame = noAnimationFrame

    requestAnimationFrameSafe = window.requestAnimationFrame
    spyOn(window, 'requestAnimationFrame').andCallFake (fn) ->
      nextAnimationFrame = ->
        nextAnimationFrame = noAnimationFrame
        fn()

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

    styleNode = $('body').append("""
    <style>
      .table-edit {
        position: relative;
      }

      .scroll-view {
        position: absolute;
        overflow: auto;
        top: 27px;
        bottom: 0;
        left: 0;
        right: 0;
      }

      .table-edit-content {
        position: relative;
      }

      .table-edit-row {
        position: absolute;
      }
    </style>
    """).find('style')

    $('body').append(tableView)

    nextAnimationFrame()

  afterEach ->
    window.requestAnimationFrame = requestAnimationFrameSafe
    styleNode.remove()
    tableView.destroy()

  it 'holds a table', ->
    expect(tableView.table).toEqual(table)

  it 'has a scroll-view', ->
    expect(tableView.scrollView).toBeDefined()

  describe 'when not scrolled yet', ->
    it 'renders the lines at the top of the table', ->
      rows = tableView.find('.table-edit-row')
      expect(rows.length).toEqual(18)
      expect(rows.first().data('row-id')).toEqual(1)
      expect(rows.last().data('row-id')).toEqual(18)

  describe '::getFirstVisibleRow', ->
    it 'returns 0 when the table view is not scrolled', ->
      expect(tableView.getFirstVisibleRow()).toEqual(0)

  describe '::getLastVisibleRow', ->
    it 'returns 8 when the table view is not scrolled', ->
      expect(tableView.getLastVisibleRow()).toEqual(8)

  describe 'when scrolled by 100px', ->
    beforeEach ->
      tableView.scrollTop(100)
      nextAnimationFrame()

    describe '::getFirstVisibleRow', ->
      it 'returns 5', ->
        expect(tableView.getFirstVisibleRow()).toEqual(5)

    describe '::getLastVisibleRow', ->
      it 'returns 13', ->
        expect(tableView.getLastVisibleRow()).toEqual(13)

    it 'translates the content by the amount of scroll', ->
      expect(tableView.find('.scroll-view').scrollTop()).toEqual(100)

    it 'does not render new rows', ->
      rows = tableView.find('.table-edit-row')
      expect(rows.length).toEqual(18)
      expect(rows.first().data('row-id')).toEqual(1)
      expect(rows.last().data('row-id')).toEqual(18)
