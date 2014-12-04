[Table, TableView] = []

module.exports =

  config:
    undefinedDisplay:
      type: 'string'
      default: ''
    pageMovesAmount:
      type: 'integer'
      default: 20
    rowHeight:
      type: 'integer'
      default: 24
    minimumRowHeight:
      type: 'integer'
      default: 16
    rowOverdraw:
      type: 'integer'
      default: 10

  activate: (state) ->
    atom.workspaceView.command 'table-edit:demo', => @openDemo()
    atom.workspaceView.command 'table-edit:demo-with-gutter', => @openDemoWithGutter()

    @openDemoWithGutter()

  deactivate: ->

  serialize: ->

  openDemo: -> @getTableView()

  openDemoWithGutter: ->
    tableView = @getTableView()
    tableView.showGutter()

  getTableView: ->
    Table ?= require './table'
    TableView ?= require './table-view'

    table = new Table
    table.addColumn 'key'
    table.addColumn 'value', align: 'right'
    table.addColumn 'foo', align: 'right'

    for i in [0...1000]
      table.addRow [
        "row#{i}"
        Math.random() * 100
        if i % 2 is 0 then 'yes' else 'no'
      ]

    table.clearUndoStack()

    tableView = new TableView(table)
    tableView.setRowHeightAt(3, 90)
    tableView.setRowHeightAt(30, 110)
    tableView.setRowHeightAt(60, 60)
    tableView.setRowHeightAt(90, 80)

    tableView.addClass('demo overlay from-top').height(300)
    tableView.attach(atom.workspaceView)

    tableView.on 'core:cancel', -> tableView.destroy()

    tableView.sortBy('value')

    tableView.focus()

    tableView
