{CompositeDisposable} = require 'atom'
{SpacePenDSL, EventsDelegation} = require 'atom-utils'
CSVEditor = require './csv-editor'
CSVEditorFormElement = require './csv-editor-form-element'
CSVPreviewElement = require './csv-preview-element'
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

    @subscriptions.add @form.onDidChange (options) => @updatePreview(options)

  collectOptions: -> @form.collectOptions()

  destroy: ->
    @subscriptions.dispose()
    @model = null

  setModel: (@model) ->
    @form.setModel(@model.options)
    @subscriptions.add @model.onDidDestroy => @destroy()

    @subscriptions.add @model.onDidOpen ({editor}) =>
      return unless editor instanceof TableEditor

      @innerHTML = ''

      tableElement = atom.views.getView(editor)
      @appendChild(tableElement)

      tableElement.focus()

      @subscriptions.dispose()
      @subscriptions = new CompositeDisposable

    @updatePreview(@model.options)

    @model.applyChoice()

  updatePreview: (options) ->
    return if options.remember

    @form.preview.clean()
    @model.previewCSV(options).then (preview) =>
      @form.preview.render(preview, options)
      @form.openTableEditorButton.removeAttribute('disabled')
    .catch (reason) =>
      @form.preview.error(reason)
      @form.openTableEditorButton.setAttribute('disabled', 'true')

module.exports = CSVEditorElement = document.registerElement 'atom-csv-editor', prototype: CSVEditorElement.prototype

CSVEditorElement.registerViewProvider = ->
  atom.views.addViewProvider CSVEditor, (model) ->
    element = new CSVEditorElement
    element.setModel(model)
    element

atom.commands.add 'atom-csv-editor',
  'core:save-as': (e) ->
    unless @model.editor?
      e.stopImmediatePropagation()
      e.preventDefault()
