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
          @div class: 'table-editor', outlet: 'tableSettingsForm', =>
            @button outlet: 'openTableEditorButton', class: 'btn btn-lg', 'Open Table Editor'

            @div class: 'control-group row-separators', =>
              @div class: 'setting-title', 'Rows separator'

              @div class: 'controls btn-group', =>
                @input type: 'radio', value: 'auto', name: 'row-separator', id: 'auto', checked: true
                @label class: 'btn', for: 'auto', 'auto'
                @input type: 'radio', value: 'unix', name: 'row-separator', id: 'unix'
                @label class: 'btn', for: 'unix', 'unix'
                @input type: 'radio', value: 'mac', name: 'row-separator', id: 'mac'
                @label class: 'btn', for: 'mac', 'mac'
                @input type: 'radio', value: 'windows', name: 'row-separator', id: 'windows'
                @label class: 'btn', for: 'windows', 'windows'
                @input type: 'radio', value: 'unicode', name: 'row-separator', id: 'unicode'
                @label class: 'btn', for: 'unicode', 'unicode'

            @div class: 'control-group separators', =>
              @div class: 'setting-title', 'Separator'

              @div class: 'controls btn-group', =>
                @input type: 'radio', value: ',', name: 'separator', id: 'comma', checked: true
                @label class: 'btn', for: 'comma', ','
                @input type: 'radio', value: ";", name: 'separator', id: 'semi-colon'
                @label class: 'btn', for: 'semi-colon', ";"
                @input type: 'radio', value: "-", name: 'separator', id: 'dash'
                @label class: 'btn', for: 'dash', "-"

            @div class: 'control-group quotes', =>
              @div class: 'setting-title', 'Quotes'

              @div class: 'controls btn-group', =>
                @input type: 'radio', value: '"', name: 'quotes', id: 'double-quote', checked: true
                @label class: 'btn', for: 'double-quote', '"…"'
                @input type: 'radio', value: "'", name: 'quotes', id: 'simple-quote'
                @label class: 'btn', for: 'simple-quote', "'…'"

            @div class: 'control-group header', =>
              @label class: 'setting-title', for: 'header', 'Header'
              @input type: 'checkbox', value: '"', name: 'header', id: 'header'

            @div class: 'table-preview', outlet: 'tablePreview'

          @div class: 'text-editor', =>
            @button outlet: 'openTextEditorButton', class: 'btn btn-lg', 'Open Text Editor'

  createdCallback: ->
    @subscriptions = new CompositeDisposable

    @subscriptions.add @subscribeTo @openTextEditorButton,
      click: => @model.openTextEditor()

    @subscriptions.add @subscribeTo @openTableEditorButton,
      click: =>
        previousAlert = @querySelector('.alert')
        if previousAlert?
          previousAlert.parentNode.removeChild(previousAlert)

        @model.openTableEditor().catch (reason) =>
          alert = document.createElement('div')
          alert.classList.add('alert')
          alert.classList.add('alert-danger')
          alert.textContent = reason.message

          @tableSettingsForm.appendChild(alert)

  setModel: (@model) ->
    @subscriptions.add @model.onDidOpen (editor) =>
      @innerHTML = ''
      @appendChild(atom.views.getView(editor))

      @subscriptions.dispose()
      @subscriptions = new CompositeDisposable

module.exports = CSVEditorElement = document.registerElement 'atom-csv-editor', prototype: CSVEditorElement.prototype

CSVEditorElement.registerViewProvider = ->
  atom.views.addViewProvider CSVEditor, (model) ->
    element = new CSVEditorElement
    element.setModel(model)
    element
