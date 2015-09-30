_ = require 'underscore-plus'
{CompositeDisposable} = require 'atom'
[url] = []

Range = require './range'
Table = require './table'
DisplayTable = require './display-table'
TableEditor = require './table-editor'
TableElement = require './table-element'
TableSelectionElement = require './table-selection-element'
CSVConfig = require './csv-config'
CSVEditor = require './csv-editor'
CSVEditorElement = require './csv-editor-element'

CSVEditorElement.registerViewProvider()
TableElement.registerViewProvider()
TableSelectionElement.registerViewProvider()

module.exports =
  config:
    undefinedDisplay:
      type: 'string'
      default: ''
    pageMoveRowAmount:
      type: 'integer'
      default: 20
    pageMoveColumnAmount:
      type: 'integer'
      default: 5
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
    rowHeightIncrement:
      type: 'integer'
      default: 20

    columnWidth:
      type: 'integer'
      default: 120
    columnOverdraw:
      type: 'integer'
      default: 2
    minimumColumnWidth:
      type: 'integer'
      default: 40
    columnWidthIncrement:
      type: 'integer'
      default: 20

    flattenBufferMultiSelectionOnPaste:
      type: 'boolean'
      default: false
      description: 'If the clipboard content comes from a multiple selection copy in a text editor, the whole clipboard text will be pasted in each cell of the table selection.'
    distributeBufferMultiSelectionOnPaste:
      type: 'string'
      default: 'vertically'
      enum: ['horizontally', 'vertically']
      description: 'If the clipboard content comes from a multiple selection copy in a text editor, each selection will be considered as part of the same column (`vertically`) or of the same row (`horizontally`).'
    treatEachCellAsASelectionWhenPastingToABuffer:
      type: 'boolean'
      default: true
      description: 'When copying from a table to paste the content in a text editor this setting will make each cell appear as if they were created from different selections.'

  activate: ({csvConfig}) ->
    @csvConfig = new CSVConfig(csvConfig)

    @subscriptions = new CompositeDisposable

    @subscriptions.add atom.commands.add 'atom-workspace',
      'tablr:demo-large': => atom.workspace.open('tablr://large')
      'tablr:demo-small': => atom.workspace.open('tablr://small')

    @subscriptions.add atom.workspace.addOpener (uriToOpen) =>
      return unless /\.csv$/.test uriToOpen

      choice = @csvConfig.get(uriToOpen, 'choice')
      options = _.clone(@csvConfig.get(uriToOpen, 'options') ? {})

      return atom.project.open(uriToOpen) if choice is 'TextEditor'

      new CSVEditor({filePath: uriToOpen, options, choice})

    @subscriptions.add atom.workspace.addOpener (uriToOpen) =>
      url ||= require 'url'

      {protocol, host} = url.parse uriToOpen
      return unless protocol is 'tablr:'

      switch host
        when 'large' then @getLargeTable()
        when 'small' then @getSmallTable()

    @subscriptions.add atom.contextMenu.add
      'atom-table-editor': [{
        label: 'Table'
        submenu: [
          {label: 'Align left', command: 'tablr:align-left'}
          {label: 'Align center', command: 'tablr:align-center'}
          {label: 'Align right', command: 'tablr:align-right'}
        ]
        created: (event) ->
          {pageX, pageY, target} = event
          return unless target.getScreenColumnIndexAtPixelPosition?
          target.targetColumnForAlignment = target.getScreenColumnIndexAtPixelPosition(pageX, pageY)
          setTimeout (-> delete target.targetColumnForAlignment), 10
      }]

  deactivate: ->
    @subscriptions.dispose()

  provideTablrModelsServiceV1: ->
    {Table, DisplayTable, TableEditor, Range}

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
    table.initializeAfterSetup()
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
    table.initializeAfterSetup()
    table.unlockModifiedStatus()

    return table

  serialize: ->
    csvConfig: @csvConfig.serialize()
