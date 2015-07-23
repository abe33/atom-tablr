fs = require 'fs'
csv = require 'csv'
path = require 'path'
{CompositeDisposable, Emitter} = require 'atom'
TableEditor = require './table-editor'

module.exports =
class CSVEditor
  constructor: (@uriToOpen, @options={}) ->
    @subscriptions = new CompositeDisposable
    @emitter = new Emitter

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

  getPath: -> @uriToOpen

  isDestroyed: -> @destroyed

  onDidOpen: (callback) ->
    @emitter.on 'did-open', callback

  onDidDestroy: (callback) ->
    @emitter.on 'did-destroy', callback

  openTextEditor: ->
    atom.project.open(@uriToOpen).then (editor) =>
      pane = atom.workspace.paneForItem(this)
      @destroy()

      pane.activateItem(editor)

  openTableEditor: ->
    @openCSV.then (@editor) =>
      @emitter.emit('did-open', @editor)

  destroy: ->
    return if @destroyed

    @destroyed = true
    @emitter.emit('did-destroy', this)
    @emitter.dispose()

  openCSV: ->
    new Promise (resolve, reject) =>
      fileContent = fs.readFileSync(@uriToOpen)
      csv.parse fileContent, (err, data) =>
        return reject(err) if err?

        tableEditor = new TableEditor
        return resolve(tableEditor) if data.length is 0

        for i in [0...data[0].length]
          tableEditor.addColumn(tableEditor.getColumnName(i), {}, false)

        tableEditor.addRows(data)
        tableEditor.setSaveHandler(@save)
        tableEditor.initializeAfterOpen()

        resolve(tableEditor)

  saveCSV: (editor) =>
    new Promise (resolve, reject) =>
      csv.stringify editor.getRows(), @options, (err, data) =>
        return reject(err) if err?

        fs.writeFile @uriToOpen, data, (err) =>
          return reject(err) if err?
          resolve()
