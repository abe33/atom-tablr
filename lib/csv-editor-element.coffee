{CompositeDisposable} = require 'atom'
{SpacePenDSL, EventsDelegation} = require 'atom-utils'
CSVEditor = require './csv-editor'

module.exports =
class CSVEditorElement extends HTMLElement
  SpacePenDSL.includeInto(this)
  EventsDelegation.includeInto(this)

  @content: ->
    @div class: 'settings-view', =>
      @div class: 'settings-panel', =>
        @div class: 'setting-title', 'Choose between table and text editor:'
        @div class: 'controls', =>
          @label for: 'remember-choice', =>
            @input type: 'checkbox', id: 'remember-choice'
            @div class: 'setting-title', "Remember my choice for this file"

        @div class: 'editor-choices', =>
          @div class: 'table-editor', =>
            @button outlet: 'openTableEditorButton', class: 'btn btn-lg', 'Open Table Editor'

            @div class: 'control-group separators', =>
              @div class: 'setting-title', 'Separators'

              @div class: 'controls btn-group', =>
                @input type: 'radio', value: ',', name: 'separator', id: 'comma'
                @label class: 'btn', for: 'comma', ','
                @input type: 'radio', value: ";", name: 'separator', id: 'semi-colon'
                @label class: 'btn', for: 'semi-colon', ";"
                @input type: 'radio', value: "-", name: 'separator', id: 'dash'
                @label class: 'btn', for: 'dash', "-"


            @div class: 'control-group quotes', =>
              @div class: 'setting-title', 'Quotes'

              @div class: 'controls btn-group', =>
                @input type: 'radio', value: '"', name: 'quotes', id: 'double-quote'
                @label class: 'btn', for: 'double-quote', '"…"'
                @input type: 'radio', value: "'", name: 'quotes', id: 'simple-quote'
                @label class: 'btn', for: 'simple-quote', "'…'"

          @div class: 'text-editor', =>
            @button outlet: 'openTextEditorButton', class: 'btn btn-lg', 'Open Text Editor'

  createdCallback: ->
    @subscriptions = new CompositeDisposable

    @subscriptions.add @subscribeTo @openTextEditorButton,
      click: => @model.openTextEditor()

    @subscriptions.add @subscribeTo @openTableEditorButton,
      click: => @model.openTableEditor()

  setModel: (@model) ->
    @subscriptions.add @model.onDidOpen (editor) =>
      @appendChild(atom.views.getView(editor))

module.exports = CSVEditorElement = document.registerElement 'atom-csv-editor', prototype: CSVEditorElement.prototype

CSVEditorElement.registerViewProvider = ->
  atom.views.addViewProvider CSVEditor, (model) ->
    element = new CSVEditorElement
    element.setModel(model)
    element
