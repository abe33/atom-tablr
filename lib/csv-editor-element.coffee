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

            @div class: 'control-group row-delimiters', =>
              @div class: 'controls', =>
                @div class: 'setting-title', 'Rows delimiter'
                @tag 'atom-text-editor', mini: true

              @div class: 'controls btn-group', =>
                @input type: 'radio', value: 'auto', name: 'row-delimiter', id: 'auto', checked: true
                @label class: 'btn', for: 'auto', 'auto'
                @input type: 'radio', value: 'custom', name: 'row-delimiter', id: 'custom'
                @label class: 'btn', for: 'custom', 'custom'
                @input type: 'radio', value: '\n', name: 'row-delimiter', id: 'new-line'
                @label class: 'btn', for: 'new-line', '\\n'
                @input type: 'radio', value: '\r', name: 'row-delimiter', id: 'char-return'
                @label class: 'btn', for: 'char-return', '\\r'
                @input type: 'radio', value: '\r\n', name: 'row-delimiter', id: 'char-return-new-line'
                @label class: 'btn', for: 'char-return-new-line', '\\r\\n'

            @div class: 'control-group delimiters', =>
              @div class: 'setting-title', 'Separator'

              @div class: 'controls btn-group', =>
                @input type: 'radio', value: ',', name: 'delimiter', id: 'comma', checked: true
                @label class: 'btn', for: 'comma', ','
                @input type: 'radio', value: ";", name: 'delimiter', id: 'semi-colon'
                @label class: 'btn', for: 'semi-colon', ";"
                @input type: 'radio', value: "-", name: 'delimiter', id: 'dash'
                @label class: 'btn', for: 'dash', "-"

            @div class: 'control-group quotes', =>
              @div class: 'setting-title', 'Quotes'

              @div class: 'controls btn-group', =>
                @input type: 'radio', value: '&quot;', name: 'quote', id: 'double-quote', checked: true
                @label class: 'btn', for: 'double-quote', '"…"'
                @input type: 'radio', value: "'", name: 'quote', id: 'simple-quote'
                @label class: 'btn', for: 'simple-quote', "'…'"

            @div class: 'control-group header', =>
              @label class: 'setting-title', for: 'header', 'Header'
              @input type: 'checkbox', name: 'header', id: 'header'

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

        @model.openTableEditor(@collectOptions()).catch (reason) =>
          alert = document.createElement('div')
          alert.classList.add('alert')
          alert.classList.add('alert-danger')
          alert.textContent = reason.message

          @tableSettingsForm.appendChild(alert)

  collectOptions: ->
    options =
      header: @querySelector('#header').checked
      quote: @querySelector('[name="quote"]:checked')?.value
      delimiter: @querySelector('[name="delimiter"]:checked')?.value
      escape: @querySelector('[name="quote"]:checked')?.value

    rowDelimiter = @querySelector('[name="row-delimiter"]:checked')?.value
    options.rowDelimiter = rowDelimiter unless rowDelimiter is 'auto'

    options

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
