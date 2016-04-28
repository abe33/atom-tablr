_ = require 'underscore-plus'
fs = require 'fs'
csv = require 'csv'
path = require 'path'
stream = require 'stream'
{File, CompositeDisposable, Emitter} = require 'atom'
TableEditor = require './table-editor'
Table = require './table'
Tablr = null
iconv = null

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

  destroy: ->
    return if @destroyed

    if @editor?
      @saveLayout()
      @editor.destroy()

    @fileSubscriptions?.dispose()
    @editorSubscriptions?.dispose()
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
        @file.writeFile(path, data).then =>
          resolve()
        .catch (err) =>
          @allowFileChangeEvents()
          reject(err)


  saveConfig: (@choice) ->
    filePath = @getPath()
    Tablr.csvConfig.set(filePath, 'options', @options)
    if @options.remember and @choice?
      Tablr.csvConfig.set(filePath, 'choice', @choice)

  saveLayout: ->
    @layout = @getCurrentLayout()

    Tablr.csvConfig.set(@getPath(), 'layout', @layout)

  shouldPromptToSave: (options) ->
    @editor?.shouldPromptToSave(options) ? false

  onWillOpen: (callback) ->
    @emitter.on 'will-open', callback

  onDidReadData: (callback) ->
    @emitter.on 'did-read-data', callback

  onDidOpen: (callback) ->
    @emitter.on 'did-open', callback

  onDidFailOpen: (callback) ->
    @emitter.on 'did-fail-open', callback

  onWillFillTable: (callback) ->
    @emitter.on 'will-fill-table', callback

  onFillTable: (callback) ->
    @emitter.on 'fill-table', callback

  onDidFillTable: (callback) ->
    @emitter.on 'did-fill-table', callback

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
    @emitter.emit 'will-open', {options: _.clone(options)}

    @openCSV().then (@editor) =>
      @subscribeToEditor()

      @emitter.emit 'did-open', {@editor, options: _.clone(options)}
      @emitter.emit 'did-change-modified', @editor.isModified()

      @saveConfig('TableEditor')
      @editor
    .catch (err) =>
      @emitter.emit 'did-fail-open', {err, options: _.clone(options)}

  subscribeToEditor: ->
    @editorSubscriptions = new CompositeDisposable
    @editorSubscriptions.add @editor.onDidChangeModified (status) =>
      @emitter.emit 'did-change-modified', status

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

          @getTableEditor(options, layout).then (tableEditor) =>
            CSVEditor.tableEditorForPath[filePath] = tableEditor
            @editorSubscriptions.dispose()
            @editor = tableEditor
            @subscribeToEditor()
            @emitter.emit 'did-change', this
            debounceChange()
          .catch (err) =>
            # The file content has changed for a format that cannot be parsed
            # We drop the editor and replace it with the csv form
            @editorSubscriptions.dispose()
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

        @getTableEditor(options, layout).then (tableEditor) =>
          CSVEditor.tableEditorForPath[filePath] = tableEditor
          resolve(tableEditor)
        .catch (err) ->
          reject(err)

  getTableEditor: (options, layout) ->
    new Promise (resolve, reject) =>
      output = []
      input = @createReadStream(options)
      length = 0
      read = =>
        while record = input.read()
          output.push(record)
          length = Math.max(length, record.length)

        @emitter.emit 'did-read-data', {input, lines: output.length}

      end = =>
        table = new Table
        return resolve(new TableEditor({table})) if output.length is 0

        table.lockModifiedStatus()

        if options.header
          for column,i in output.shift()
            table.addColumn(column, false)
        else
          for i in [0...length]
            table.addColumn(undefined, false)

        @emitter.emit 'will-fill-table', {table}
        @fillTable(table, output).then =>
          @emitter.emit 'did-fill-table', {table}
          tableEditor = new TableEditor({table})

          if layout?
            for i in [0...length] when (opts = layout.columns[i])?
              tableEditor.setScreenColumnOptions(i, opts)
            tableEditor.displayTable.setRowHeights(layout.rowHeights)

          tableEditor.setSaveHandler(@save)
          tableEditor.initializeAfterSetup()
          tableEditor.unlockModifiedStatus()
          resolve(tableEditor)
        .catch (err) -> reject(err)

      error = (err) -> reject(err)

      input.on 'readable', read
      input.on 'end', end
      input.on 'error', error

  fillTable: (table, rows) ->
    batchSize = atom.config.get('tablr.csvEditor.tableCreationBatchSize')
    new Promise (resolve, reject) =>
      if rows.length <= batchSize
        table.addRows(rows, false)
        @emitter.emit 'fill-table', {table}
        resolve()
      else
        fill = =>
          currentRows = rows.splice(0,batchSize)
          table.addRows(currentRows, false)
          @emitter.emit 'fill-table', {table}

          if rows.length > 0
            requestAnimationFrame(-> fill table, rows)
          else
            resolve()

        fill()

  previewCSV: (options) ->
    new Promise (resolve, reject) =>
      output = []
      input = @createReadStream(options)
      limit = atom.config.get('tablr.csvEditor.maximumRowsInPreview')
      limit += 1 if options.header

      stop = ->
        input.stop()
        input.removeListener 'readable', read
        input.removeListener 'end', end
        # input.removeListener 'error', error
        resolve(output[0...limit])

      read = ->
        output.push record while record = input.read()
        stop() if output.length > limit

      end = -> resolve(output[0...limit])

      error = (err) -> reject(err)

      input.on 'readable', read
      input.on 'end', end
      input.on 'error', error

  createReadStream: (options) ->
    encoding = options.fileEncoding ? 'utf8'
    filePath = @file.getPath()
    @file.setEncoding(encoding)

    if encoding is 'utf8'
      input = fs.createReadStream(filePath, {encoding})
    else
      iconv ?= require 'iconv-lite'
      input = fs.createReadStream(filePath).pipe(iconv.decodeStream(encoding))

    size = fs.lstatSync(filePath).size
    parser = csv.parse(options)
    length = 0

    counter = new stream.Transform
      transform: (chunk, encoding, callback) ->
        length += chunk.length
        @push chunk
        callback()

    input.pipe(counter).pipe(parser)

    parser.stop = ->
      input.unpipe(counter)
      counter.unpipe(parser)
      parser.end()

    parser.getProgress = ->
      return {length, total: size, ratio: length/size}

    parser

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
