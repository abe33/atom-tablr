{CompositeDisposable} = require 'atom'
{SpacePenDSL, EventsDelegation} = require 'atom-utils'
CSVEditor = require './csv-editor'
CSVEditorFormElement = require './csv-editor-form-element'
CSVPreviewElement = require './csv-preview-element'
TableEditor = require './table-editor'

module.exports =
class CSVEditorElement extends HTMLElement
  SpacePenDSL.includeInto(this)
  EventsDelegation.includeInto(this)

  createdCallback: ->
    @setAttribute 'tabindex', -1
    @subscriptions = new CompositeDisposable
    @formSubscriptions = new CompositeDisposable
    @classList.add 'pane-item'

    @createFormView()

    @formSubscriptions.add @subscribeTo @form.openTextEditorButton,
      click: =>
        @model.choice = 'TextEditor'
        @model.openTextEditor(@collectOptions())

    @formSubscriptions.add @subscribeTo @form.openTableEditorButton,
      click: =>
        @form.cleanMessages()
        @model.choice = 'TableEditor'
        @model.openTableEditor(@collectOptions()).catch (reason) =>
          @form.alert(reason.message)

    @formSubscriptions.add @form.onDidChange (options) => @updatePreview(options)

  collectOptions: -> @form.collectOptions()

  destroy: ->
    @subscriptions.dispose()
    @formSubscriptions?.dispose()
    @model = null

  focus: -> @tableElement?.focus()

  setModel: (@model) ->
    @form.setModel(@model.options)
    @subscriptions.add @model.onDidDestroy => @destroy()

    @subscriptions.add @model.onDidChange =>
      if @model.editor?
        if @model.editor isnt @tableElement.getModel()
          @displayTableEditor(@model.editor)
      else if @tableElement?
        delete @tableElement
        @createFormView()
      else
        @updatePreview()

    @subscriptions.add @model.onDidOpen ({editor}) =>
      return unless editor instanceof TableEditor

      @displayTableEditor(editor)

      @formSubscriptions.dispose()
      @formSubscriptions = null

    @updatePreview(@model.options)

    @model.applyChoice()

  displayTableEditor: (editor) ->
    delete @form
    @innerHTML = ''

    @tableElement = atom.views.getView(editor)
    @appendChild(@tableElement)

    @tableElement.focus()

  createFormView: ->
    @innerHTML = ''

    container = document.createElement('div')
    container.className = 'settings-view'

    @form = document.createElement 'atom-csv-editor-form'

    container.appendChild(@form)
    @appendChild(container)

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
