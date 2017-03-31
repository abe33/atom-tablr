'use strict'

const {CompositeDisposable, Emitter} = require('atom')
const {SpacePenDSL, EventsDelegation} = require('atom-utils')
const encodings = require('./encodings')
const element = require('./decorators/element')

let nextId = 0
const encodingOptions = Object.keys(encodings).map(key => ({
  value: encodings[key].status,
  name: encodings[key].list
}))

const findEncodingValue = (name) => {
  let res = encodingOptions.filter(opt => opt.name === name)

  if (res.length > 0) { return res[0].value }
}

const asArray = (a) => [].slice.call(a)

const labelFromValue = value =>
  String(value)
  .replace('\n', '\\n')
  .replace('\t', '\\t')
  .replace('\r', '\\r')

const valueFromLabel = value =>
  String(value)
  .replace('\\n', '\n')
  .replace('\\t', '\t')
  .replace('\\r', '\r')

const normalizeValue = value =>
  labelFromValue(value ? value.replace('"', '&quot') : '')

const denormalizeValue = value =>
  valueFromLabel(value ? value.replace('&quot', '"') : '')

class CSVEditorFormElement extends HTMLElement {
  static initClass () {
    SpacePenDSL.Babel.includeInto(this)
    EventsDelegation.includeInto(this)
    return element(this, 'atom-csv-editor-form')
  }

  static content () {
    const id = nextId++

    const radios = params => {
      const {name, options, outlet, output, selected} = params

      this.div({
        class: 'controls btn-group',
        'data-initial': selected,
        'data-id': outlet,
        'data-output': output || outlet}, () => {
        for (let optionName in options) {
          const value = options[optionName]
          const inputOption = {
            type: 'radio',
            value: normalizeValue(value),
            name,
            id: `${optionName}-${name}-${id}`,
            'data-name': optionName
          }
          if (optionName === value) { inputOption.checked = true }
          this.input(inputOption)
          this.label({
            class: 'btn',
            for: `${optionName}-${name}-${id}`
          }, labelFromValue(value))
        }
      })
    }

    const radiosOnly = (params = {}) => {
      const {name, label} = params
      this.div({class: `control-group with-radios-only radios ${name.replace(/-\d+$/, '')}`}, () => {
        this.label({class: 'setting-title'}, label)
        radios(params)
      })
    }

    const radiosWithTextEditor = (params = {}) => {
      const {name, options, label, outlet} = params
      this.div({class: `control-group with-text-editor radios ${name.replace(/-\d+$/, '')}`}, () => {
        this.div({class: 'controls'}, () => {
          this.label({class: 'setting-title'}, label)
          this.tag('atom-text-editor', {
            outlet: `${outlet}TextEditorElement`,
            mini: true,
            'data-id': outlet
          })
        })

        options.custom = 'custom'
        radios(params)
      })
    }

    const select = (params = {}) => {
      const {name, label, outlet, options} = params

      this.div({class: `control-group select ${name.replace(/-\d+$/, '')}`}, () => {
        this.div({class: 'controls'}, () => {
          this.label({class: 'setting-title'}, label)
          this.select({
            class: 'form-control btn',
            outlet: `${outlet}Select`
          }, () => {
            options.forEach(option => {
              this.option({value: option.value}, option.name)
            })
          })
        })
      })
    }

    this.div({class: 'settings-panel'}, () => {
      this.div({class: 'setting-title'}, 'Choose between table and text editor:')
      this.div({class: 'controls'}, () => {
        this.label({for: `remember-choice-${id}`}, () => {
          this.input({type: 'checkbox', id: `remember-choice-${id}`})
          this.div({class: 'setting-title'}, 'Remember my choice for this file')
        })
      })

      this.div({class: 'editor-choices'}, () => {
        this.div({class: 'table-editor', outlet: 'tableSettingsForm'}, () => {
          this.button({outlet: 'openTableEditorButton', class: 'btn btn-lg'}, 'Open Table Editor')
        })

        this.div({class: 'text-editor'}, () => {
          this.button({outlet: 'openTextEditorButton', class: 'btn btn-lg'}, 'Open Text Editor')
        })
      })

      this.div({class: 'messages', outlet: 'messagesContainer'})
      this.div({class: 'setting-title'}, 'CSV Settings')

      this.div({class: 'split-panel'}, () => {
        this.div({class: 'panel'}, () => {
          radiosWithTextEditor({
            label: 'Row Delimiter',
            name: `row-delimiter-${id}`,
            outlet: 'rowDelimiter',
            selected: 'auto',
            options: {
              'auto': 'auto',
              'char-return-new-line': '\r\n',
              'new-line': '\n',
              'char-return': '\r'
            }
          })

          radiosWithTextEditor({
            label: 'Quotes',
            name: `quote-${id}`,
            outlet: 'quote',
            selected: 'double-quote',
            options: {
              'double-quote': '"',
              'single-quote': "'"
            }
          })

          radiosWithTextEditor({
            label: 'Comments',
            name: `comment-${id}`,
            outlet: 'comment',
            selected: 'hash',
            options: {
              'hash': '#',
              'none': 'none'
            }
          })
        })

        this.div({class: 'panel'}, () => {
          radiosWithTextEditor({
            label: 'Column Delimiter',
            name: `delimiter-${id}`,
            output: 'delimiter',
            outlet: 'columnDelimiter',
            selected: 'comma',
            options: {
              'comma': ',',
              'semi-colon': ';',
              'dash': '-',
              'tab': '\t'
            }
          })

          radiosWithTextEditor({
            label: 'Escape',
            name: `escape-${id}`,
            outlet: 'escape',
            selected: 'double-quote',
            options: {
              'double-quote': '"',
              'single-quote': "'",
              'backslash': '\\'
            }
          })

          radiosOnly({
            name: `trim-${id}`,
            label: 'Trim',
            selected: 'no',
            outlet: 'trim',
            options: {
              no: 'no',
              left: 'left',
              right: 'right',
              both: 'both'
            }
          })
        })

        this.div({class: 'panel'}, () => {
          select({
            name: `encoding-${id}`,
            label: 'Encoding',
            outlet: 'encoding',
            options: encodingOptions
          })

          this.div({class: 'control-group boolean header'}, () => {
            this.label({class: 'setting-title', for: `header-${id}`}, 'Header')
            this.input({type: 'checkbox', name: `header-${id}`, id: `header-${id}`})
          })

          this.div({class: 'control-group boolean eof'}, () => {
            this.label({class: 'setting-title', for: `eof-${id}`}, 'End Of File')
            this.input({type: 'checkbox', name: `eof-${id}`, id: `eof-${id}`})
          })

          this.div({class: 'control-group boolean quoted'}, () => {
            this.label({class: 'setting-title', for: `quoted-${id}`}, 'Quoted')
            this.input({type: 'checkbox', name: `quoted-${id}`, id: `quoted-${id}`})
          })

          this.div({class: 'control-group boolean skip-empty-lines'}, () => {
            this.label({class: 'setting-title', for: `skip-empty-lines-${id}`}, 'Skip Empty Lines')
            this.input({type: 'checkbox', name: `skip-empty-lines-${id}`, id: `skip-empty-lines-${id}`})
          })
        })
      })

      this.p('Preview of the parsed CSV:')
      this.tag('atom-csv-preview', {outlet: 'preview'})
    })
  }

  createdCallback () {
    this.buildContent()
    this.subscriptions = new CompositeDisposable()
    this.emitter = new Emitter()

    this.subscriptions.add(this.subscribeTo(this, 'input, select',
      {
        change: () => this.emitChangeEvent()
      })
    )

    this.initializeBindings()
  }

  initializeBindings () {
    asArray(this.querySelectorAll('atom-text-editor')).forEach(editorElement => {
      const outlet = editorElement.dataset.id
      const radioGroup = editorElement.parentNode.parentNode.querySelector('[data-initial]')
      const {initial} = radioGroup.dataset

      const editor = editorElement.getModel()
      this[`${outlet}TextEditor`] = editor

      this.subscriptions.add(editor.onDidChange(() => {
        if (!this.attached) { return }

        const radio = radioGroup.querySelector("[id^='custom-']")
        if (editor.getText() !== '') {
          radio && (radio.checked = true)
        } else if (radio && radio.checked) {
          const selected = radioGroup.querySelector(`[id^='${initial}-']`)
          selected && (selected.checked = true)
        }

        this.emitChangeEvent()
      }))
    })
  }

  initializeDefaults (options) {
    if (options.header || atom.config.get('tablr.csvEditor.header')) {
      this.querySelector('[id^="header"]').checked = true
    }

    if (options.eof || atom.config.get('tablr.csvEditor.eof')) {
      this.querySelector('[id^="eof"]').checked = true
    }

    if (options.quoted || atom.config.get('tablr.csvEditor.quoted')) {
      this.querySelector('[id^="quoted"]').checked = true
    }

    if (options.skip_empty_lines || atom.config.get('tablr.csvEditor.skipEmptyLines')) {
      this.querySelector('[id^="skip-empty-lines"]').checked = true
    }

    if (options.ltrim || atom.config.get('tablr.csvEditor.trim') === 'left') {
      this.querySelector('[id^="left-trim"]').checked = true
    }
    if (options.rtrim || atom.config.get('tablr.csvEditor.trim') === 'right') {
      this.querySelector('[id^="right-trim"]').checked = true
    }
    if (options.trim || atom.config.get('tablr.csvEditor.trim') === 'both') {
      this.querySelector('[id^="both-trim"]').checked = true
    }

    const encoding = options.encoding || findEncodingValue(atom.config.get('tablr.csvEditor.encoding'))
    if (encoding) {
      this.encodingSelect.value = encoding
    }

    const radioGroups = asArray(this.querySelectorAll('.with-text-editor .btn-group'))
    radioGroups.forEach(radioGroup => {
      const outlet = radioGroup.dataset.id
      const {output} = radioGroup.dataset
      const {initial} = radioGroup.dataset

      const radios = asArray(radioGroup.querySelectorAll('input[type="radio"]'))

      let value = labelFromValue(options[output] || atom.config.get(`tablr.csvEditor.${outlet}`))

      if (value) {
        const radio = radios.filter(r => r.value === value)[0]

        if (radio) {
          radio.checked = true
        } else {
          this[`${outlet}TextEditor`].setText(value)
          const radio = radioGroup.querySelector("[id^='custom-']")
          radio && (radio.checked = true)
        }
      } else {
        const radio = radioGroup.querySelector(`[id^='${initial}-']`)
        if (radio) { radio.checked = true }
      }
    })

    this.initialized = true
  }

  attachedCallback () {
    this.attached = true
  }

  detachedCallback () {
    this.attached = false
  }

  onDidChange (callback) {
    return this.emitter.on('did-change', callback)
  }

  emitChangeEvent () {
    if (this.initialized) {
      this.emitter.emit('did-change', this.collectOptions())
    }
  }

  destroy () {
    this.subscriptions.dispose()
    this.emitter.dispose()
  }

  alert (message) {
    const alert = document.createElement('div')
    alert.classList.add('alert')
    alert.classList.add('alert-danger')
    alert.textContent = message

    this.messagesContainer.appendChild(alert)
  }

  cleanMessages () {
    this.messagesContainer.innerHTML = ''
  }

  setModel (options = {}) {
    requestAnimationFrame(() => this.initializeDefaults(options))
  }

  collectOptions () {
    const options = {
      remember: this.querySelector('[id^="remember-choice"]').checked,
      header: this.querySelector('[id^="header"]').checked,
      eof: this.querySelector('[id^="eof"]').checked,
      quoted: this.querySelector('[id^="quoted"]').checked,
      skip_empty_lines: this.querySelector('[id^="skip-empty-lines"]').checked,
      fileEncoding: this.encodingSelect.value,
      relax_column_count: true
    }

    const trimInput = this.querySelector('[name^="trim"]:checked')
    const commentInput = this.querySelector('[name^="comment"]:checked')
    const escapeInput = this.querySelector('[name^="escape"]:checked')
    const quoteInput = this.querySelector('[name^="quote"]:checked')
    const delimiterInput = this.querySelector('[name^="delimiter"]:checked')
    const rowDelimiterInput = this.querySelector('[name^="row-delimiter"]:checked')

    const trim = trimInput && trimInput.value
    const comment = commentInput && commentInput.value
    const escape = escapeInput && escapeInput.value
    const quote = quoteInput && quoteInput.value
    const delimiter = delimiterInput && delimiterInput.value
    const rowDelimiter = rowDelimiterInput && rowDelimiterInput.value

    if (quote === '' || delimiter === '' || rowDelimiter === '' || comment === '' || escape === '') {
      throw new Error('It should not be empty')
    }

    if (quote === 'custom') {
      options.quote = this.quoteTextEditor.getText()
    } else {
      options.quote = quote
    }

    if (escape === 'custom') {
      options.escape = this.escapeTextEditor.getText()
    } else {
      options.escape = escape
    }

    if (comment === 'custom') {
      options.comment = this.commentTextEditor.getText()
    } else if (comment === 'none') {
      options.comment = ''
    } else {
      options.comment = comment
    }

    if (delimiter === 'custom') {
      options.delimiter = this.columnDelimiterTextEditor.getText()
    } else {
      options.delimiter = denormalizeValue(delimiter)
    }

    if (rowDelimiter === 'custom') {
      options.rowDelimiter = this.rowDelimiterTextEditor.getText()
    } else if (rowDelimiter !== 'auto') {
      options.rowDelimiter = denormalizeValue(rowDelimiter)
    }

    switch (trim) {
      case 'both':
        options.trim = true
        break
      case 'left':
        options.ltrim = true
        break
      case 'right':
        options.rtrim = true
        break
    }

    return options
  }
}
module.exports = CSVEditorFormElement.initClass()
