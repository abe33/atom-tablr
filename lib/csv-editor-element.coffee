{CompositeDisposable} = require 'atom'
{SpacePenDSL, EventsDelegation} = require 'atom-utils'
CSVEditor = require './csv-editor'

module.exports =
class CSVEditorElement extends HTMLElement
  SpacePenDSL.includeInto(this)
  EventsDelegation.includeInto(this)

  @content: ->
    @button outlet: 'openTableEditorButton', class: 'btn', 'Open Table Editor'
    @button outlet: 'openTextEditorButton', class: 'btn', 'Open Text Editor'

  createdCallback: ->
    @subscriptions = new CompositeDisposable

    @subscriptions.add @subscribeTo @openTextEditorButton,
      'click': => @model.openTextEditor()

  attachedCallback: ->

  setModel: (@model) ->
    @subscriptions.add @model.onDidOpen (editor) =>
      @appendChild(atom.views.getView(editor))

module.exports = CSVEditorElement = document.registerElement 'atom-csv-editor', prototype: CSVEditorElement.prototype

CSVEditorElement.registerViewProvider = ->
  atom.views.addViewProvider CSVEditor, (model) ->
    element = new CSVEditorElement
    element.setModel(model)
    element
