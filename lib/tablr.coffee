encodings = require './encodings'
[_, url, CompositeDisposable, Range, Table, DisplayTable, TableEditor, TableElement, TableSelectionElement, CSVConfig, CSVEditor, CSVEditorElement] = []

{CSVEditorPlaceholder, CSVEditorPlaceholderElement} = require './csv-editor-placeholder'

atom.deserializers.add(CSVEditorPlaceholder)
CSVEditorPlaceholderElement.registerViewProvider()

module.exports =
  activate: ({csvConfig}) ->
    CompositeDisposable ?= require('atom').CompositeDisposable
    CSVConfig ?= require './csv-config'

    @csvConfig = new CSVConfig(csvConfig)
    @subscriptions = new CompositeDisposable

    if atom.inDevMode()
      @subscriptions.add atom.commands.add 'atom-workspace',
        'tablr:demo-large': => atom.workspace.open('tablr://large')
        'tablr:demo-small': => atom.workspace.open('tablr://small')

    @subscriptions.add atom.commands.add 'atom-workspace',
      'tablr:clear-csv-storage': => @csvConfig.clear()
      'tablr:clear-csv-choice': => @csvConfig.clearOption('choice')
      'tablr:clear-csv-layout': => @csvConfig.clearOption('layout')

    @subscriptions.add atom.workspace.addOpener (uriToOpen) =>
      return unless ///\.(#{atom.config.get('tablr.supportedCsvExtensions').join('|')})$///.test uriToOpen

      _ ?= require 'underscore-plus'
      CSVEditor ?= require './csv-editor'

      @registerViews()

      choice = @csvConfig.get(uriToOpen, 'choice')
      options = _.clone(@csvConfig.get(uriToOpen, 'options') ? {})

      return atom.workspace.openTextFile(uriToOpen) if choice is 'TextEditor'

      new CSVEditor({filePath: uriToOpen, options, choice})

    @subscriptions.add atom.workspace.addOpener (uriToOpen) =>
      url ||= require 'url'

      {protocol, host} = url.parse uriToOpen
      return unless protocol is 'tablr:'

      switch host
        when 'large' then @getLargeTable()
        when 'small' then @getSmallTable()

    @subscriptions.add atom.contextMenu.add
      'tablr-editor': [{
        label: 'Tablr'
        created: (event) ->
          {pageX, pageY, target} = event
          return unless target.getScreenColumnIndexAtPixelPosition? and target.getScreenRowIndexAtPixelPosition?

          contextMenuColumn = target.getScreenColumnIndexAtPixelPosition(pageX)
          contextMenuRow = target.getScreenRowIndexAtPixelPosition(pageY)

          @submenu = []

          if contextMenuRow? and contextMenuRow >= 0
            target.contextMenuRow = contextMenuRow

            @submenu.push {label: 'Fit Row Height To Content', command: 'tablr:fit-row-to-content'}

          if contextMenuColumn? and contextMenuColumn >= 0
            target.contextMenuColumn = contextMenuColumn

            @submenu.push {label: 'Fit Column Width To Content', command: 'tablr:fit-column-to-content'}
            @submenu.push {type: 'separator'}
            @submenu.push {label: 'Align left', command: 'tablr:align-left'}
            @submenu.push {label: 'Align center', command: 'tablr:align-center'}
            @submenu.push {label: 'Align right', command: 'tablr:align-right'}

          setTimeout ->
            delete target.contextMenuColumn
            delete target.contextMenuRow
          , 10
      }]

    @replacePlaceholders()

  deactivate: ->
    @subscriptions.dispose()

  provideTablrModelsServiceV1: ->
    Range ?= require './range'
    Table ?= require './table'
    DisplayTable ?= require './display-table'
    TableEditor ?= require './table-editor'

    {Table, DisplayTable, TableEditor, Range}

  replacePlaceholders: ->
    @registerViews()
    placeholders = atom.workspace.getPaneItems()
    .filter (item) -> item instanceof CSVEditorPlaceholder
    .forEach (item) ->
      pane = atom.workspace.paneForItem(item)
      itemIndex = pane.getItems().indexOf(item)
      isActive = pane.getActiveItem() is item
      csvEditor = item.getCSVEditor()
      pane.removeItem(item)
      pane.addItem(csvEditor, index: itemIndex)
      pane.activateItem(csvEditor) if isActive

  getSmallTable: ->
    @registerViews()

    TableEditor ?= require './table-editor'

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
    @registerViews()

    TableEditor ?= require './table-editor'

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

  registerViews: ->
    unless CSVEditorElement?
      TableElement ?= require './table-element'
      TableSelectionElement ?= require './table-selection-element'
      CSVEditorElement ?= require './csv-editor-element'

      CSVEditorElement.registerViewProvider()
      TableElement.registerViewProvider()
      TableSelectionElement.registerViewProvider()

  serialize: ->
    csvConfig: @csvConfig.serialize()
