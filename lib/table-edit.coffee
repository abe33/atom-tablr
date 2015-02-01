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
    columnWidth:
      type: 'integer'
      default: 120
    minimumRowHeight:
      type: 'integer'
      default: 16
    rowOverdraw:
      type: 'integer'
      default: 3
    columnOverdraw:
      type: 'integer'
      default: 2

  activate: (state) ->
    Table ?= require './table'
    TableView ?= require './table-element'
    TableView.registerViewProvider()

    atom.commands.add 'atom-workspace',
      'table-edit:demo', => @openDemo()
      'table-edit:demo-with-gutter', => @openDemoWithGutter()

    # @openDemoWithGutter()

  deactivate: ->

  serialize: ->

  openDemo: -> @getTableView()

  openDemoWithGutter: ->
    tableElement = @getTableView()
    tableElement.setAbsoluteColumnsWidths(true)

    tableElement.showGutter()

  getTableView: ->
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

    tableElement = atom.views.getView(table)
    tableElement.setRowHeightAt(3, 90)
    tableElement.setRowHeightAt(30, 110)
    tableElement.setRowHeightAt(60, 60)
    tableElement.setRowHeightAt(90, 80)

    tableElement.classList.add('demo')
    tableElement.classList.add('overlay')
    tableElement.classList.add('from-top')
    tableElement.style.height = '400px'

    tableElement.attach(atom.views.getView(atom.workspace))

    atom.commands.add tableElement, 'core:cancel', -> tableElement.destroy()

    tableElement.sortBy('value')

    tableElement.focus()

    tableElement
