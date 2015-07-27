{CompositeDisposable} = require 'atom'
{SpacePenDSL, EventsDelegation} = require 'atom-utils'
CSVEditor = require './csv-editor'
CSVEditorFormElement = require './csv-editor-form-Element'
TableEditor = require './table-editor'

nextId = 0

module.exports =
class CSVEditorElement extends HTMLElement
  SpacePenDSL.includeInto(this)
  EventsDelegation.includeInto(this)

  @content: ->
    id = nextId++

    @div class: 'settings-view', =>
      @tag 'atom-csv-editor-form', outlet: 'form'

  createdCallback: ->
    @setAttribute 'tabindex', -1
    @subscriptions = new CompositeDisposable

    @subscriptions.add @subscribeTo @form.openTextEditorButton,
      click: => @model.openTextEditor(@collectOptions())

    @subscriptions.add @subscribeTo @form.openTableEditorButton,
      click: =>
        @form.cleanMessages()

        @model.openTableEditor(@collectOptions()).catch (reason) =>
          @form.alert(reason.message)

  collectOptions: -> @form.collectOptions()

  setModel: (@model) ->
    @subscriptions.add @model.onDidOpen ({editor}) =>
      return unless editor instanceof TableEditor

      @innerHTML = ''
      @appendChild(atom.views.getView(editor))

      @subscriptions.dispose()
      @subscriptions = new CompositeDisposable

    @model.applyChoice()

module.exports = CSVEditorElement = document.registerElement 'atom-csv-editor', prototype: CSVEditorElement.prototype

CSVEditorElement.registerViewProvider = ->
  atom.views.addViewProvider CSVEditor, (model) ->
    element = new CSVEditorElement
    element.setModel(model)
    element
