fs = require 'fs'
csv = require 'csv'
[TableEditor, TableElement, url] = []

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
    TableEditor ?= require './table-editor'
    TableElement ?= require './table-element'
    TableElement.registerViewProvider(true)

    atom.commands.add 'atom-workspace',
      'table-edit:demo-large': => atom.workspace.open('table://large')
      'table-edit:demo-small': => atom.workspace.open('table://small')

    atom.workspace.addOpener (uriToOpen) =>
      return unless /\.csv$/.test uriToOpen

      new Promise (resolve, reject) ->
        fileContent = fs.readFileSync(uriToOpen)
        csv.parse fileContent, (err, data) ->
          return reject(err) if err?

          tableEditor = new TableEditor
          return resolve(tableEditor) if data.length is 0

          {table} = tableEditor

          tableEditor.addColumn(column, {}, false) for column in data.shift()
          tableEditor.addRows(data)
          table.clearUndoStack()
          table.modified = false
          table.updateCachedContents()

          resolve(tableEditor)

    atom.workspace.addOpener (uriToOpen) =>
      url ||= require 'url'

      {protocol, host} = url.parse uriToOpen
      return unless protocol is 'table:'

      switch host
        when 'large' then @getLargeTable()
        when 'small' then @getSmallTable()

  getSmallTable: ->
    table = new TableEditor

    table.addColumn 'key', width: 150, align: 'right'
    table.addColumn 'value', width: 150, align: 'center'
    table.addColumn 'locked', width: 150, align: 'left'

    rows = []
    for i in [0...100]
      rows.push [
        "row#{i}"
        Math.random() * 100
        if i % 2 is 0 then 'yes' else 'no'
      ]

    table.addRows(rows)

    table.clearUndoStack()
    table.getTable().modified = false

    return table

  getLargeTable: ->
    table = new TableEditor

    table.addColumn 'key', width: 150, align: 'right'
    table.addColumn 'value', width: 150, align: 'center'
    for i in [0..100]
      table.addColumn 'column_' + i, width: 150, align: 'left'

    rows = []
    for i in [0...1000]
      data = [
        "row#{i}"
        Math.random() * 100
      ]
      for j in [0..100]
        if j % 2 is 0
          data.push if i % 2 is 0 then 'yes' else 'no'
        else
          data.push Math.random() * 100

      rows.push data

    table.addRows(rows)

    table.clearUndoStack()
    table.getTable().modified = false

    return table
