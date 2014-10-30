
module.exports =

  activate: (state) ->
    atom.workspaceView.command 'table-edit:demo', ->
      Table = require './table'
      TableView = require './table-view'

      table = new Table
      table.addColumn 'key'
      table.addColumn 'value', align: 'right'
      table.addColumn 'foo', align: 'right'

      for i in [0...100]
        table.addRow [
          "row#{i}"
          i * 100
          if i % 2 is 0 then 'yes' else 'no'
        ]

      tableView = new TableView(table)
      tableView.setRowHeight 20
      tableView.setRowOverdraw 10

      tableView.addClass('demo overlay from-top').height(300)
      atom.workspaceView.append(tableView)

      tableView.on 'core:cancel', -> tableView.destroy()

  deactivate: ->

  serialize: ->
