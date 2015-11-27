_ = require 'underscore-plus'
fs = require 'fs'
csv = require 'csv'
path = require 'path'
{CompositeDisposable, Emitter, File} = require 'atom'
TableEditor = require './table-editor'
Tablr = null

module.exports =
class CSVEditor
  @deserialize: (state) ->
    csvEditor = new CSVEditor(state)
    csvEditor.applyChoice()
    csvEditor

  @tableEditorForPath: {}

  constructor: (state={}) ->
    {filePath, @options, @choice, @layout, editor: @editorState} = state

    Tablr ?= require './tablr'
    @options ?= {}
    @subscriptions = new CompositeDisposable
    @emitter = new Emitter
    @setPath(filePath)

  setPath: (filePath) ->
    return if filePath is @getPath()

    if filePath
      @file = new File(filePath)
      @previousPath = filePath
      @subscribeToFile()
    else
      @file = null

    @emitter.emit 'did-change-path', @getPath()
    @emitter.emit 'did-change-title', @getTitle()

  subscribeToFile: ->
    @fileSubscriptions?.dispose()

    @fileSubscriptions = new CompositeDisposable

    changeFired = false
    debounceChange = =>
      setTimeout =>
        changeFired = false
        @allowFileChangeEvents()
      , 100

    @fileSubscriptions.add @file.onDidChange =>
      return if changeFired
      changeFired = true

      return if @nofileChangeEvent

      if @editor?
        if @editor.isModified()
          @emitter.emit 'did-conflict', this
          debounceChange()
        else
          filePath = @getPath()
          options = _.clone(@options)
          layout = @layout ? Tablr.csvConfig?.get(filePath, 'layout')

          @getTableEditor(filePath, options, layout).then (tableEditor) =>
            CSVEditor.tableEditorForPath[filePath] = tableEditor
            @editor = tableEditor
            @emitter.emit 'did-change', this
            debounceChange()
          .catch (err) =>
            # The file content has changed for a format that cannot be parsed
            # We drop the editor and replace it with the csv form
            @editor.destroy()
            delete @editor
            @emitter.emit 'did-change', this
            debounceChange()
      else
        @emitter.emit 'did-change', this
        debounceChange()

    # @fileSubscriptions.add @file.onDidDelete =>
    #   console.log 'deleted'

    @fileSubscriptions.add @file.onDidRename =>
      newPath = @getPath()
      Tablr.csvConfig.move(@previousPath, newPath)

      @emitter.emit 'did-change-path', newPath
      @emitter.emit 'did-change-title', @getTitle()
      @previousPath = newPath

    # @fileSubscriptions.add @file.onWillThrowWatchError (errorObject) =>
    #   console.log 'error', errorObject

  getTitle: ->
    if sessionPath = @getPath()
      path.basename(sessionPath)
    else
      'untitled'

  getLongTitle: ->
    if sessionPath = @getPath()
      fileName = path.basename(sessionPath)
      directory = atom.project.relativize(path.dirname(sessionPath))
      directory = if directory.length > 0 then directory else path.basename(path.dirname(sessionPath))
      "#{fileName} - #{directory}"
    else
      'untitled'

  getPath: -> @file?.getPath()

  getURI: -> @getPath()

  isDestroyed: -> @destroyed

  isModified: -> @editor?.isModified() ? false

  copy: ->
    new CSVEditor({filePath: @getPath(), options: _.clone(@options), @choice})

  shouldPromptToSave: (options) ->
    @editor?.shouldPromptToSave(options) ? false

  onDidOpen: (callback) ->
    @emitter.on 'did-open', callback

  onDidDestroy: (callback) ->
    @emitter.on 'did-destroy', callback

  onDidConflict: (callback) ->
    @emitter.on 'did-conflict', callback

  onDidChange: (callback) ->
    @emitter.on 'did-change', callback

  onDidChangeModified: (callback) ->
    @emitter.on 'did-change-modified', callback

  onDidChangePath: (callback) ->
    @emitter.on 'did-change-path', callback

  onDidChangeTitle: (callback) ->
    @emitter.on 'did-change-title', callback

  applyChoice: ->
    return if @choiceApplied
    if @choice?
      switch @choice
        when 'TextEditor' then @openTextEditor(@options)
        when 'TableEditor' then @openTableEditor(@options)

    @choiceApplied = true

  openTextEditor: (@options={}) ->
    filePath = @getPath()
    atom.workspace.openTextFile(filePath).then (editor) =>
      pane = atom.workspace.paneForItem(this)
      @emitter.emit('did-open', {editor, options: _.clone(@options)})
      @saveConfig('TextEditor')
      @destroy()

      pane.activateItem(editor)

  openTableEditor: (@options={}) ->
    @openCSV().then (@editor) =>
      @subscriptions.add @editor.onDidChangeModified (status) =>
        @emitter.emit 'did-change-modified', status

      @emitter.emit 'did-open', {@editor, options: _.clone(options)}
      @emitter.emit 'did-change-modified', @editor.isModified()

      @saveConfig('TableEditor')
      @editor

  destroy: ->
    return if @destroyed

    if @editor?
      @saveLayout()
      @editor.destroy()

    @fileSubscriptions?.dispose()
    @destroyed = true
    @emitter.emit('did-destroy', this)
    @emitter.dispose()

  save: =>
    @saveAs(@getPath())

  saveAs: (path) ->
    new Promise (resolve, reject) =>
      options = _.clone(@options)
      options.columns = @editor.getColumns() if options.header

      @setPath(path)
      @saveLayout()

      csv.stringify @editor.getTable().getRows(), options, (err, data) =>
        return reject(err) if err?

        @preventFileChangeEvents()
        fs.writeFile path, data, (err) =>
          if err?
            @allowFileChangeEvents()
            return reject(err)
          resolve()

  saveConfig: (@choice) ->
    filePath = @getPath()
    Tablr.csvConfig.set(filePath, 'options', @options)
    if @options.remember and @choice?
      Tablr.csvConfig.set(filePath, 'choice', @choice)

  saveLayout: ->
    @layout = @getCurrentLayout()

    Tablr.csvConfig.set(@getPath(), 'layout', @layout)

  getCurrentLayout: ->
    columns: @editor.getScreenColumns().map (column) =>
      conf = {}
      if column.width? and column.width isnt @editor.getScreenColumnWidth()
        conf.width = column.width

      if column.align? and column.align isnt 'left'
        conf.align = column.align

      conf

    rowHeights: @editor.displayTable.rowHeights.slice()

  openCSV: ->
    new Promise (resolve, reject) =>
      filePath = @getPath()
      if (previousEditor = CSVEditor.tableEditorForPath[filePath])? and previousEditor.table?
        {table, displayTable} = CSVEditor.tableEditorForPath[filePath]
        tableEditor = new TableEditor({table, displayTable})

        resolve(tableEditor)
      else if @editorState?
        tableEditor = atom.deserializers.deserialize(@editorState)
        @editorState = null
        resolve(tableEditor)
      else
        options = _.clone(@options)
        layout = @layout ? Tablr.csvConfig?.get(filePath, 'layout')

        @getTableEditor(filePath, options, layout).then (tableEditor) =>
          CSVEditor.tableEditorForPath[filePath] = tableEditor
          resolve(tableEditor)

  getTableEditor: (filePath, options, layout) ->
    new Promise (resolve, reject) =>
      fileContent = fs.readFileSync(filePath)
      csv.parse String(fileContent), options, (err, data) =>
        return reject(err) if err?

        tableEditor = new TableEditor
        return resolve(tableEditor) if data.length is 0
        tableEditor.lockModifiedStatus()

        if options.header
          for column,i in data.shift()
            tableEditor.addColumn(column, layout?.columns[i] ? {}, false)
        else
          for i in [0...data[0].length]
            tableEditor.addColumn(undefined, layout?.columns[i] ? {}, false)

        tableEditor.addRows(data)
        tableEditor.displayTable.setRowHeights(layout.rowHeights) if layout?
        tableEditor.setSaveHandler(@save)
        tableEditor.initializeAfterSetup()
        tableEditor.unlockModifiedStatus()
        resolve(tableEditor)

  previewCSV: (options) ->
    new Promise (resolve, reject) =>
      input = fs.createReadStream(@getPath())
      parser = csv.parse(options)
      output = []

      stop = ->
        input.unpipe(parser)
        parser.end()
        resolve(output)

      read = ->
        output.push record while record = parser.read()

      end = ->
        resolve(output)

      error = (err) -> reject(err)

      parser.on 'readable', read
      parser.on 'end', end
      parser.on 'error', error

      input.pipe(parser)

  preventFileChangeEvents: -> @nofileChangeEvent = true

  allowFileChangeEvents: -> @nofileChangeEvent = false

  serialize: ->
    out = {
      deserializer: 'CSVEditor'
      filePath: @getPath()
      @options
      @choice
    }
    if @isModified()
      out.editor = @editor.serialize()
    else
      out.layout = @getCurrentLayout() if @editor?
    out
