_ = require 'underscore-plus'
[TableEditor, TableElement, CSVEditor, CSVEditorElement, url] = []

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
    TableElement.registerViewProvider()

    atom.commands.add 'atom-workspace',
      'table-edit:demo-large': => atom.workspace.open('table://large')
      'table-edit:demo-small': => atom.workspace.open('table://small')

    atom.workspace.addOpener (uriToOpen) =>
      return unless /\.csv$/.test uriToOpen

      unless CSVEditorElement?
        CSVEditor ?= require './csv-editor'
        CSVEditorElement = require './csv-editor-element'
        CSVEditorElement.registerViewProvider()

      choice = @getChoiceForPath(uriToOpen)
      options = _.clone @getOptionsForPath(uriToOpen)

      return atom.project.open(uriToOpen) if choice is 'TextEditor'

      csvEditor = new CSVEditor(uriToOpen, options, choice)

      disposable = csvEditor.onDidOpen ({editor, options}) =>
        disposable.dispose()

        @storeOptionsForPath(uriToOpen, options)
        if options.remember
          @storeChoiceForPath(uriToOpen, editor.constructor.name)

      csvEditor

    atom.workspace.addOpener (uriToOpen) =>
      url ||= require 'url'

      {protocol, host} = url.parse uriToOpen
      return unless protocol is 'table:'

      switch host
        when 'large' then @getLargeTable()
        when 'small' then @getSmallTable()

  getChoiceForPath: (path) ->
    @pathsOptions?[path]?.choice

  storeChoiceForPath: (path, choice) ->
    @pathsOptions ?= {}
    @pathsOptions[path] ?= {}
    @pathsOptions[path].choice = choice

  getOptionsForPath: (path) ->
    @pathsOptions?[path]?.options

  storeOptionsForPath: (path, options) ->
    @pathsOptions ?= {}
    @pathsOptions[path] ?= {}
    @pathsOptions[path].options = options

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
