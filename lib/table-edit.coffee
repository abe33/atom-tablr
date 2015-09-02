_ = require 'underscore-plus'
{CompositeDisposable} = require 'atom'
[TableEditor, TableElement, TableSelectionElement, CSVEditor, CSVEditorElement, url] = []

module.exports =
  config:
    undefinedDisplay:
      type: 'string'
      default: ''
    pageMovesAmount:
      type: 'integer'
      default: 20
    scrollSpeedDuringDrag:
      type: 'integer'
      default: 20
    scrollPastEnd:
      type: 'boolean'
      default: false

    rowHeight:
      type: 'integer'
      default: 24
    rowOverdraw:
      type: 'integer'
      default: 3
    minimumRowHeight:
      type: 'integer'
      default: 16

    columnWidth:
      type: 'integer'
      default: 120
    columnOverdraw:
      type: 'integer'
      default: 2
    minimumColumnWidth:
      type: 'integer'
      default: 40

    flattenBufferMultiSelectionOnPaste:
      type: 'boolean'
      default: false
      description: "If the clipboard content comes from a multiple selection copy in a text editor, the whole clipboard text will be pasted in each cell of the table selection."
    distributeBufferMultiSelectionOnPaste:
      type: 'string'
      default: 'vertically'
      enum: ['horizontally', 'vertically']
      description: "If the clipboard content comes from a multiple selection copy in a text editor, each selection will be considered as part of the same column (verticall) or of the same row (horizontally)."

  activate: ({@pathOptions}) ->
    TableEditor ?= require './table-editor'
    TableElement ?= require './table-element'
    TableSelectionElement ?= require './table-selection-element'
    TableElement.registerViewProvider()
    TableSelectionElement.registerViewProvider()

    @subscriptions = new CompositeDisposable

    @subscriptions.add atom.commands.add 'atom-workspace',
      'table-edit:demo-large': => atom.workspace.open('table://large')
      'table-edit:demo-small': => atom.workspace.open('table://small')

    @subscriptions.add atom.workspace.addOpener (uriToOpen) =>
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

    @subscriptions.add atom.workspace.addOpener (uriToOpen) =>
      url ||= require 'url'

      {protocol, host} = url.parse uriToOpen
      return unless protocol is 'table:'

      switch host
        when 'large' then @getLargeTable()
        when 'small' then @getSmallTable()

  deactivate: ->
    @subscriptions.dispose()

  getChoiceForPath: (path) ->
    @pathOptions?[path]?.choice

  storeChoiceForPath: (path, choice) ->
    @pathOptions ?= {}
    @pathOptions[path] ?= {}
    @pathOptions[path].choice = choice

  getOptionsForPath: (path) ->
    @pathOptions?[path]?.options

  storeOptionsForPath: (path, options) ->
    @pathOptions ?= {}
    @pathOptions[path] ?= {}
    @pathOptions[path].options = options

  getSmallTable: ->
    table = new TableEditor

    table.lockModifiedStatus()
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
    table.initializeAfterOpen()
    table.unlockModifiedStatus()
    return table

  getLargeTable: ->
    table = new TableEditor

    table.lockModifiedStatus()
    table.addColumn 'key', width: 150, align: 'right'
    table.addColumn 'value', width: 150, align: 'center'
    for i in [0..100]
      table.addColumn undefined, width: 150, align: 'left'

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
    table.initializeAfterOpen()
    table.unlockModifiedStatus()

    return table

  serialize: ->
    {@pathOptions}
