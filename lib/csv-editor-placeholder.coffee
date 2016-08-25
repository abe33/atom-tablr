path = require 'path'
{registerOrUpdateElement} = require 'atom-utils'

CSVEditor = null

class CSVEditorPlaceholder
  @deserialize: (state) ->
    new CSVEditorPlaceholder(state)

  constructor: (@state) ->

  getCSVEditor: ->
    CSVEditor ?= require './csv-editor'

    CSVEditor.deserialize(@state)

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

  getPath: -> @state.filePath

  getURI: -> @getPath()

class CSVEditorPlaceholderElement extends HTMLElement
  createdCallback: ->
    @innerHTML = """
    <ul class='background-message centered'>
    <li><span class='loading loading-spinner-large inline-block'></span></li>
    </ul>
    """

CSVEditorPlaceholderElement = registerOrUpdateElement 'atom-csv-editor-placeholder', CSVEditorPlaceholderElement.prototype

CSVEditorPlaceholderElement.registerViewProvider = ->
  atom.views.addViewProvider CSVEditorPlaceholder, (model) ->
    new CSVEditorPlaceholderElement

module.exports = {CSVEditorPlaceholder, CSVEditorPlaceholderElement}
