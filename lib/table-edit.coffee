[Table, TableView, url] = []

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
    TableView.registerViewProvider(true)

    atom.commands.add 'atom-workspace',
      'table-edit:demo-in-pane': => @openDemoInPane()

    atom.workspace.addOpener (uriToOpen) ->
      url ||= require 'url'

      {protocol, host} = url.parse uriToOpen
      return unless protocol is 'table:'

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

      return table

  deactivate: ->

  serialize: ->

  openDemoInPane: ->
    atom.workspace.open('table://demo')
