'use strict'

const {CompositeDisposable} = require('atom')
const {EventsDelegation} = require('atom-utils')
const element = require('./decorators/element')

let CSVEditorFormElement, CSVPreviewElement, CSVProgressElement, TableEditor

class CSVEditorElement extends HTMLElement {
  static initClass () {
    EventsDelegation.includeInto(this)
    atom.commands.add('atom-csv-editor', {
      'core:save-as' (e) {
        if (!this.model.editor) {
          e.stopImmediatePropagation()
          e.preventDefault()
        }
      }
    })
    return element(this, 'atom-csv-editor')
  }

  createdCallback () {
    this.setAttribute('tabindex', -1)
    this.subscriptions = new CompositeDisposable()
    this.classList.add('pane-item')

    this.createFormView()
  }

  collectOptions () { return this.form.collectOptions() }

  destroy () {
    this.subscriptions.dispose()
    this.formSubscriptions && this.formSubscriptions.dispose()
    delete this.model
  }

  focus () { this.tableElement && this.tableElement.focus() }

  setModel (model) {
    this.model = model
    this.form.setModel(this.model.options)
    this.subscriptions.add(this.model.onDidDestroy(() => this.destroy()))

    this.subscriptions.add(this.model.onDidChange(() => {
      if (this.model.editor) {
        if (this.model.editor !== this.tableElement.getModel()) {
          this.removeTableEditor()
          this.displayTableEditor(this.model.editor)
        }
      } else if (this.tableElement) {
        this.createFormView()
      } else {
        this.updatePreview(this.collectOptions())
      }
    }))

    let loadingSubscription
    this.subscriptions.add(this.model.onWillOpen(() => {
      this.ensureProgress()
      this.removeFormView()
      loadingSubscription = this.model.onDidReadData(({input, lines}) => {
        this.input = input
        this.lines = lines
        this.requestProgressUpdate()
      })
      this.subscriptions.add(loadingSubscription)
    }))

    this.subscriptions.add(this.model.onWillFillTable(() => {
      loadingSubscription && loadingSubscription.dispose()
      this.ensureProgress()
      this.removeFormView()

      loadingSubscription = this.model.onFillTable(({table}) => {
        const count = table.getRowCount()
        this.progress.updateFillTable(count, count / this.lines)
      })
      this.subscriptions.add(loadingSubscription)
    }))

    this.subscriptions.add(this.model.onDidFailOpen(({err}) => {
      this.hideProgress()
      this.createFormView()
      this.form.alert(err.message)
    }))

    this.subscriptions.add(this.model.onDidOpen(({editor}) => {
      if (!TableEditor) { TableEditor = require('./table-editor') }

      if (!(editor instanceof TableEditor)) { return }

      this.hideProgress()
      loadingSubscription && loadingSubscription.dispose()

      this.displayTableEditor(editor)

      this.formSubscriptions.dispose()
      delete this.formSubscriptions
    }))

    requestAnimationFrame(() => {
      this.updatePreview(this.collectOptions())
      this.model.applyChoice()
    })
  }

  displayTableEditor (editor) {
    this.removeFormView()

    this.tableElement = atom.views.getView(editor)
    this.appendChild(this.tableElement)

    this.tableElement.focus()
  }

  removeTableEditor () {
    if (this.tableElement && this.tableElement.parentNode) {
      this.removeChild(this.tableElement)
    }
    delete this.tableElement
  }

  createFormView () {
    if (this.form) { return }

    if (!CSVEditorFormElement) {
      CSVEditorFormElement = require('./csv-editor-form-element')
    }
    if (!CSVPreviewElement) {
      CSVPreviewElement = require('./csv-preview-element')
    }

    this.removeTableEditor()

    this.formContainer = document.createElement('div')
    this.formContainer.className = 'settings-view'

    this.form = new CSVEditorFormElement()
    this.formSubscriptions = new CompositeDisposable()

    this.formSubscriptions.add(this.subscribeTo(this.form.openTextEditorButton, {
      click: () => {
        this.model.choice = 'TextEditor'
        this.model.openTextEditor(this.collectOptions())
      }
    }))

    this.formSubscriptions.add(this.subscribeTo(this.form.openTableEditorButton, {
      click: () => {
        this.form.cleanMessages()
        this.model.choice = 'TableEditor'
        this.model.openTableEditor(this.collectOptions())
      }
    }))

    this.formSubscriptions.add(this.form.onDidChange(options => {
      this.updatePreview(options)
    }))

    this.formContainer.appendChild(this.form)
    if (this.model) { this.form.setModel(this.model.options) }
    this.appendChild(this.formContainer)
  }

  removeFormView () {
    if (this.formContainer && this.formContainer.parentNode) {
      this.removeChild(this.formContainer)
    }
    delete this.form
    delete this.formContainer
  }

  updatePreview (options) {
    if (options.remember || atom.config.get('tablr.disablePreview')) { return }
    if (!this.model) { return }

    this.form.preview.clean()
    this.model.previewCSV(options).then(preview => {
      if (!this.form) { return }
      this.form.preview.render(preview, options)
      this.form.openTableEditorButton.removeAttribute('disabled')
    })
    .catch(reason => {
      if (!this.form) { return }
      this.form.preview.error(reason)
      this.form.openTableEditorButton.setAttribute('disabled', 'true')
    })
  }

  ensureProgress () {
    if (!this.progress) { return this.displayProgress() }
  }

  displayProgress () {
    if (!CSVProgressElement) {
      CSVProgressElement = require('./csv-progress-element')
    }

    this.progress = new CSVProgressElement()
    this.appendChild(this.progress)
  }

  hideProgress () {
    if (this.progress && this.progress.parentNode) {
      this.removeChild(this.progress)
    }
  }

  requestProgressUpdate () {
    if (this.frameRequested || !this.progress) { return }
    this.frameRequested = true

    requestAnimationFrame(() => {
      this.progress.updateReadData(this.input, this.lines)
      this.frameRequested = false
    })
  }
}

module.exports = CSVEditorElement.initClass()
