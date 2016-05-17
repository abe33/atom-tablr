_ = require 'underscore-plus'
{CompositeDisposable} = require 'atom'
encodings = require './encodings'
[url, Range, Table, DisplayTable, TableEditor, TableElement, TableSelectionElement, CSVConfig, CSVEditor, CSVEditorElement] = []

module.exports =
  config:
    tableEditor:
      type: 'object'
      properties:
        undefinedDisplay:
          title: 'Undefined Value Display'
          description: 'How to render undefined values in a cell. Leave the field blank to display an empty cell.'
          type: 'string'
          default: ''
        pageMoveRowAmount:
          title: 'Page Move Row Amount'
          description: 'The number of rows to jump when using the `core:page-up` and `core:page-down` commands.'
          type: 'integer'
          default: 20
        pageMoveColumnAmount:
          title: 'Page Move Column Amount'
          description: 'The number of columns to jump when using the `tablr:page-left` and `tablr:page-right` commands.'
          type: 'integer'
          default: 5
        scrollSpeedDuringDrag:
          title: 'Scroll Speed During Drag'
          description: 'The speed of the scrolling motion during a drag gesture, in pixels.'
          type: 'integer'
          default: 20
        scrollPastEnd:
          title: 'Scroll Past End'
          description: 'When enabled, the table can scroll past the end of the table both vertically and horizontally to let manipulate rows and columns more easily.'
          type: 'boolean'
          default: false

        rowHeight:
          title: 'Row Height'
          description: 'The default row height in pixels.'
          type: 'integer'
          default: 24
        rowOverdraw:
          description: 'The number of rows to render outside the bounds of the visible area to smooth the scrolling motion.'
          title: 'Row Overdraw'
          type: 'integer'
          default: 3
        minimumRowHeight:
          title: 'Minimum Row Height'
          description: 'The minimum height of a row in pixels.'
          type: 'integer'
          default: 16
        rowHeightIncrement:
          title: 'Row Height Increment'
          description: 'The amount of pixels to add or remove to a row when using the row resizing commands.'
          type: 'integer'
          default: 20

        columnWidth:
          title: 'Column Width'
          description: 'The default column width in pixels.'
          type: 'integer'
          default: 120
        columnOverdraw:
          title: 'Column Overdraw'
          description: 'The number of columns to render outside the bounds of the visible area to smooth the scrolling motion.'
          type: 'integer'
          default: 2
        minimumColumnWidth:
          title: 'Minimum Column Width'
          description: 'The minimum column width in pixels.'
          type: 'integer'
          default: 40
        columnWidthIncrement:
          title: 'Column Width Increment'
          description: 'The amount of pixels to add or remove to a column when using the column resizing commands.'
          type: 'integer'
          default: 20

    copyPaste:
      type: 'object'
      properties:
        flattenBufferMultiSelectionOnPaste:
          title: 'Flatten Buffer Multi Selection On Paste'
          type: 'boolean'
          default: false
          description: 'If the clipboard content comes from a multiple selection copy in a text editor, the whole clipboard text will be pasted in each cell of the table selection.'
        distributeBufferMultiSelectionOnPaste:
          title: 'Distribute Buffer Multi Selection On Paste'
          type: 'string'
          default: 'vertically'
          enum: ['horizontally', 'vertically']
          description: 'If the clipboard content comes from a multiple selection copy in a text editor, each selection will be considered as part of the same column (`vertically`) or of the same row (`horizontally`).'
        treatEachCellAsASelectionWhenPastingToABuffer:
          title: 'Treat Each Cell As A Selection When Pasting To A Buffer'
          type: 'boolean'
          default: true
          description: 'When copying from a table to paste the content in a text editor this setting will make each cell appear as if they were created from different selections.'

    csvEditor:
      type: 'object'
      properties:
        maximumRowsInPreview:
          type: 'integer'
          default: 100
          minimum: 1
          description: 'The maximum number of rows in the CSV preview. Low numbers can speed up the preview generation but can also lead to error or inconsistencies when parsing the whole file if there is errors past the last row in the preview.'
        tableCreationBatchSize:
          type: 'integer'
          default: 1000
          minimum: 1
          description: 'When creating a table from a CSV file, filling the table in one single loop can lock the UI if the table is too large. To prevent that from happening the table is filled in small steps where a number of rows equals to the batch size are added to the table.'
        columnDelimiter:
          title: 'Default Column Delimiter'
          description: 'The default column delimiter to use when opening a CSV for the first time. You can write space characters code such as `\\t` instead of using the proper character.'
          type: 'string'
          default: ','
        rowDelimiter:
          title: 'Default Row Delimiter'
          description: 'The default row delimiter to use when opening a CSV for the first time. You can write space characters code such as `\\r` instead of using the proper character. The `auto` value will let the CSV parser determine the proper separator to use depending on the file\'s content.'
          type: 'string'
          default: 'auto'
        quote:
          title: 'Default Quote Character'
          description: 'The default quote character for quoted content.'
          type: 'string'
          default: '"'
        escape:
          title: 'Default Espace Character'
          description: 'The default escape character for escaped quotes in quoted content.'
          type: 'string'
          default: '"'
        comment:
          title: 'Default Comment Character'
          description: 'The default character that indicate a comment. Everything past this character in a line will be ignored. You can set it to `none` to disable the use of comments.'
          type: 'string'
          default: '#'
        quoted:
          title: 'Quoted Content'
          description: 'Whether the column\'s content are wrapped into quotes or not.'
          type: 'boolean'
          default: false
        header:
          title: 'File Header'
          description: 'Whether to treat the first line of a CSV as the file header or not.'
          type: 'boolean'
          default: false
        eof:
          title: 'Ensure New Line At End Of File'
          description: 'When checked, every file will be saved with an extra new-line character at the end of the file.'
          type: 'boolean'
          default: false
        skipEmptyLines:
          title: 'Skip Empty Lines'
          description: 'When checked, empty lines will simply be ignored.'
          type: 'boolean'
          default: false
        trim:
          title: 'Trim Cell Content'
          description: 'How to treat cell\'s content when parsing a CSV file.'
          type: 'string'
          default: 'no'
          enum: ['no', 'left', 'right', 'both']
        encoding:
          title: 'Default Encoding'
          description: 'The default encoding to use when opening a new CSV file.'
          type: 'string'
          default: 'UTF-8'
          enum: Object.keys(encodings).map (key) -> encodings[key].list

    supportedCsvExtensions:
      type: 'array'
      default: ['csv', 'tsv', 'CSV', 'TSV']
      description: 'The extensions for which the CSV opener will be used.'

    disablePreview:
      title: 'Disable preview'
      description: 'When checked, preview will not be presented.'
      type: 'boolean'
      default: false

    defaultColumnNamingMethod:
      type: 'string'
      default: 'alphabetic'
      enum: ['alphabetic', 'numeric', 'numericZeroBased']
      description: 'When file has no header, select the default naming method for the columns. `alphabetic` means use A, B,…, Z, AA, AB… `numeric` is for simple numbers, ie 1, 2… `numericZeroBased` is similar to `numeric`, except that it starts numbering from 0 instead of 1'


  activate: ({csvConfig}) ->
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

  loadModelsAndRegisterViews: ->
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

    atom.deserializers.add(CSVEditor)
    atom.deserializers.add(TableEditor)
    atom.deserializers.add(DisplayTable)
    atom.deserializers.add(Table)

module.exports.loadModelsAndRegisterViews()
