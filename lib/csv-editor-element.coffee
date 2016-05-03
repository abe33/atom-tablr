{CompositeDisposable} = require 'atom'
{SpacePenDSL, EventsDelegation, registerOrUpdateElement} = require 'atom-utils'
CSVEditor = require './csv-editor'
CSVEditorFormElement = require './csv-editor-form-element'
CSVPreviewElement = require './csv-preview-element'
CSVProgressElement = require './csv-progress-element'
TableEditor = require './table-editor'

module.exports =
class CSVEditorElement extends HTMLElement
  SpacePenDSL.includeInto(this)
  EventsDelegation.includeInto(this)

  createdCallback: ->
    @setAttribute 'tabindex', -1
    @subscriptions = new CompositeDisposable
    @classList.add 'pane-item'

    @createFormView()

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
          @removeTableEditor()
          @displayTableEditor(@model.editor)
      else if @tableElement?
        @createFormView()
      else
        @updatePreview()

    loadingSubscription = null
    @subscriptions.add @model.onWillOpen =>
      @ensureProgress()
      @removeFormView()
      loadingSubscription = @subscriptions.add @model.onDidReadData ({@input, @lines}) =>
        @requestProgressUpdate()

    @subscriptions.add @model.onWillFillTable =>
      loadingSubscription?.dispose()
      @ensureProgress()
      @removeFormView()

      loadingSubscription = @subscriptions.add @model.onFillTable ({table}) =>
        count = table.getRowCount()
        @progress.updateFillTable(count, count / @lines)

    @subscriptions.add @model.onDidFailOpen ({err}) =>
      @hideProgress()
      @createFormView()
      @form.alert(err.message)

    @subscriptions.add @model.onDidOpen ({editor}) =>
      return unless editor instanceof TableEditor

      @hideProgress()
      loadingSubscription?.dispose()

      @displayTableEditor(editor)

      @formSubscriptions.dispose()
      @formSubscriptions = null

    @updatePreview(@model.options)

    @model.applyChoice()

  displayTableEditor: (editor) ->
    @removeFormView()

    @tableElement = atom.views.getView(editor)
    @appendChild(@tableElement)

    @tableElement.focus()

  removeTableEditor: ->
    @removeChild(@tableElement) if @tableElement?.parentNode?
    delete @tableElement

  createFormView: ->
    return if @form?

    @removeTableEditor()

    @formContainer = document.createElement('div')
    @formContainer.className = 'settings-view'

    @form = document.createElement 'atom-csv-editor-form'
    @formSubscriptions = new CompositeDisposable

    @formSubscriptions.add @subscribeTo @form.openTextEditorButton,
      click: =>
        @model.choice = 'TextEditor'
        @model.openTextEditor(@collectOptions())

    @formSubscriptions.add @subscribeTo @form.openTableEditorButton,
      click: =>
        @form.cleanMessages()
        @model.choice = 'TableEditor'
        @model.openTableEditor(@collectOptions())

    @formSubscriptions.add @form.onDidChange (options) =>
      @updatePreview(options)

    @formContainer.appendChild(@form)
    @form.setModel(@model.options) if @model?
    @appendChild(@formContainer)

  removeFormView: ->
    @removeChild(@formContainer) if @formContainer?
    delete @form
    delete @formContainer

  updatePreview: (options) ->
    return if options.remember or atom.config.get('tablr.disablePreview')

    @form.preview.clean()
    @model.previewCSV(options).then (preview) =>
      return unless @form?
      @form.preview.render(preview, options)
      @form.openTableEditorButton.removeAttribute('disabled')
    .catch (reason) =>
      return unless @form?
      @form.preview.error(reason)
      @form.openTableEditorButton.setAttribute('disabled', 'true')

  ensureProgress: ->
    @displayProgress() unless @progress?

  displayProgress: ->
    @progress = new CSVProgressElement
    @appendChild(@progress)

  hideProgress: ->
    @removeChild(@progress) if @progress?.parentNode?

  requestProgressUpdate: ->
    return if @frameRequested or !@progress?
    @frameRequested = true

    requestAnimationFrame =>
      @progress.updateReadData(@input, @lines)
      @frameRequested = false

module.exports =
CSVEditorElement =
registerOrUpdateElement 'atom-csv-editor', CSVEditorElement.prototype

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
