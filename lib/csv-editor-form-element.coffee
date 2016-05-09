{CompositeDisposable, Emitter} = require 'atom'
{SpacePenDSL, EventsDelegation, registerOrUpdateElement} = require 'atom-utils'
encodings = require('./encodings')

nextId = 0
encodingOptions = Object.keys(encodings).map (key) ->
  value: encodings[key].status
  name: encodings[key].list

findEncodingValue = (name) ->
  res = encodingOptions.filter (opt) -> opt.name is name

  res[0].value if res.length > 0

labelFromValue = (value) ->
  String(value)
  .replace('\n','\\n')
  .replace('\t','\\t')
  .replace('\r','\\r')

valueFromLabel = (value) ->
  String(value)
  .replace('\\n','\n')
  .replace('\\t','\t')
  .replace('\\r','\r')

normalizeValue = (value) ->
  labelFromValue(value?.replace('"','&quot;'))

denormalizeValue = (value) ->
  valueFromLabel(value?.replace('&quot;', '"'))

module.exports =
class CSVEditorFormElement extends HTMLElement
  SpacePenDSL.includeInto(this)
  EventsDelegation.includeInto(this)

  @content: ->
    id = nextId++

    radios = (options) =>
      {name, label, options, outlet, output, selected} = options

      @div class: 'controls btn-group', 'data-initial': selected, 'data-id': outlet, 'data-output': output ? outlet, =>
        for optionName, value of options
          inputOption = type: 'radio', value: normalizeValue(value), name: name, id: "#{optionName}-#{name}-#{id}", 'data-name': optionName
          inputOption.checked = true if optionName is value
          @input(inputOption)
          @label class: 'btn', for: "#{optionName}-#{name}-#{id}", labelFromValue(value)

    radiosOnly = (options={}) =>
      {name, label} = options
      @div class: "control-group with-radios-only radios #{name}", =>
        @label class: 'setting-title', label
        radios(options)

    radiosWithTextEditor = (options={}) =>
      {name, label, outlet, selected} = options
      @div class: "control-group with-text-editor radios #{name}", =>
        @div class: 'controls', =>
          @label class: 'setting-title', label
          @tag 'atom-text-editor', outlet: "#{outlet}TextEditorElement", mini: true, 'data-id': outlet

        options.options["custom"] = 'custom'
        radios(options)

    select = (options={}) =>
      {name, label, outlet, options} = options

      @div class: "control-group select #{name}", =>
        @div class: 'controls', =>
          @label class: 'setting-title', label
          @select class: 'form-control', outlet: "#{outlet}Select", =>
            options.forEach (option) =>
              @option value: option.value, option.name

    @div class: 'settings-panel', =>
      @div class: 'setting-title', 'Choose between table and text editor:'
      @div class: 'controls', =>
        @label for: "remember-choice-#{id}", =>
          @input type: 'checkbox', id: "remember-choice-#{id}"
          @div class: 'setting-title', "Remember my choice for this file"

      @div class: 'editor-choices', =>
        @div class: 'table-editor', outlet: 'tableSettingsForm', =>
          @button outlet: 'openTableEditorButton', class: 'btn btn-lg', 'Open Table Editor'

        @div class: 'text-editor', =>
          @button outlet: 'openTextEditorButton', class: 'btn btn-lg', 'Open Text Editor'

      @div class: 'messages', outlet: 'messagesContainer'
      @div class: 'setting-title', 'CSV Settings'

      @div class: 'split-panel', =>
        @div class: 'panel', =>
          radiosWithTextEditor {
            label: 'Row Delimiter'
            name: 'row-delimiter'
            outlet: 'rowDelimiter'
            selected: 'auto'
            options:
              'auto': 'auto'
              'char-return-new-line': '\r\n'
              'new-line': '\n'
              'char-return': '\r'
          }

          radiosWithTextEditor {
            label: 'Quotes'
            name: 'quote'
            outlet: 'quote'
            selected: 'double-quote'
            options:
              'double-quote': '"'
              'single-quote': "'"
          }

          radiosWithTextEditor {
            label: 'Comments'
            name: 'comment'
            outlet: 'comment'
            selected: 'hash'
            options:
              'hash': "#"
              'none': 'none'
          }

        @div class: 'panel', =>
          radiosWithTextEditor {
            label: 'Column Delimiter'
            name: 'delimiter'
            output: 'delimiter'
            outlet: 'columnDelimiter'
            selected: 'comma'
            options:
              'comma': ','
              'semi-colon': ';'
              'dash': '-'
              'tab': '\t'
          }

          radiosWithTextEditor {
            label: 'Escape'
            name: 'escape'
            outlet: 'escape'
            selected: 'double-quote'
            options:
              'double-quote': '"'
              'single-quote': "'"
              'backslash': "\\"
          }

          radiosOnly {
            name: 'trim'
            label: 'Trim'
            selected: 'no'
            outlet: 'trim'
            options:
              no: 'no'
              left: 'left'
              right: 'right'
              both: 'both'
          }

        @div class: 'panel', =>
          select {
            name: 'encoding'
            label: 'Encoding'
            outlet: 'encoding'
            options: encodingOptions
          }

          @div class: 'control-group boolean header', =>
            @label class: 'setting-title', for: "header-#{id}", 'Header'
            @input type: 'checkbox', name: 'header', id: "header-#{id}"

          @div class: 'control-group boolean eof', =>
            @label class: 'setting-title', for: "eof-#{id}", 'End Of File'
            @input type: 'checkbox', name: 'eof', id: "eof-#{id}"

          @div class: 'control-group boolean quoted', =>
            @label class: 'setting-title', for: "quoted-#{id}", 'Quoted'
            @input type: 'checkbox', name: 'quoted', id: "quoted-#{id}"

          @div class: 'control-group boolean skip-empty-lines', =>
            @label class: 'setting-title', for: "skip-empty-lines-#{id}", 'Skip Empty Lines'
            @input type: 'checkbox', name: 'skip-empty-lines', id: "skip-empty-lines-#{id}"

      @p 'Preview of the parsed CSV:'
      @tag 'atom-csv-preview', outlet: 'preview'

  createdCallback: ->
    @subscriptions = new CompositeDisposable
    @emitter = new Emitter

    @subscriptions.add @subscribeTo this, 'input, select',
      change: => @emitChangeEvent()

    @initializeBindings()

  initializeBindings: ->
    Array::forEach.call @querySelectorAll('atom-text-editor'), (editorElement) =>
      outlet = editorElement.dataset.id
      radioGroup = editorElement.parentNode.parentNode.querySelector('[data-initial]')
      initial = radioGroup.dataset.initial

      @["#{outlet}TextEditor"] = element = editorElement.getModel()
      @subscriptions.add element.onDidChange =>
        return unless @attached
        if element.getText() isnt ''
          radioGroup.querySelector("[id^='custom-']")?.checked = true
        else
          radioGroup.querySelector("[id^='#{initial}-']")?.checked = true

        @emitChangeEvent()

  initializeDefaults: (options) ->
    if options.header ? atom.config.get('tablr.csvEditor.header')
      @querySelector('[id^="header"]').checked = true

    if options.eof ? atom.config.get('tablr.csvEditor.eof')
      @querySelector('[id^="eof"]').checked = true

    if options.quoted ? atom.config.get('tablr.csvEditor.quoted')
      @querySelector('[id^="quoted"]').checked = true

    if options.skip_empty_lines ? atom.config.get('tablr.csvEditor.skipEmptyLines')
      @querySelector('[id^="skip-empty-lines"]').checked = true

    if options.ltrim ? (atom.config.get('tablr.csvEditor.trim') is 'left')
      @querySelector('[id^="left-trim"]').checked = true
    if options.rtrim ? (atom.config.get('tablr.csvEditor.trim') is 'right')
      @querySelector('[id^="right-trim"]').checked = true
    if options.trim ? (atom.config.get('tablr.csvEditor.trim') is 'both')
      @querySelector('[id^="both-trim"]').checked = true

    if encoding = (options.encoding ? findEncodingValue(atom.config.get('tablr.csvEditor.encoding')))
      @encodingSelect.value = encoding

    radioGroups = @querySelectorAll('.with-text-editor .btn-group')

    Array::forEach.call radioGroups, (radioGroup) =>
      outlet = radioGroup.dataset.id
      output = radioGroup.dataset.output
      initial = radioGroup.dataset.initial

      radios = radioGroup.querySelectorAll('input[type="radio"]')
      radioOptions = {}

      value = labelFromValue(options[output] ? atom.config.get("tablr.csvEditor.#{outlet}"))

      if value? and radio = Array::filter.call(radios, (r) -> r.value is value)[0]
        radio.checked = true
      else if value?
        @["#{outlet}TextEditor"].setText(value)
        radioGroup.querySelector("[id^='custom-']")?.checked = true
      else if radio = radioGroup.querySelector("[id^='#{initial}-']")
        radio.checked = true

    @initialized = true

  attachedCallback: ->
    @attached = true

  detachedCallback: ->
    @attached = false

  onDidChange: (callback) ->
    @emitter.on 'did-change', callback

  emitChangeEvent: ->
    @emitter.emit 'did-change', @collectOptions() if @initialized

  destroy: ->
    @subscriptions.dispose()
    @emitter.dispose()

  alert: (message) ->
    alert = document.createElement('div')
    alert.classList.add('alert')
    alert.classList.add('alert-danger')
    alert.textContent = message

    @messagesContainer.appendChild(alert)

  cleanMessages: ->
    @messagesContainer.innerHTML = ''

  setModel: (options={}) ->
    requestAnimationFrame => @initializeDefaults(options)

  collectOptions: ->
    options =
      remember: @querySelector('[id^="remember-choice"]').checked
      header: @querySelector('[id^="header"]').checked
      eof: @querySelector('[id^="eof"]').checked
      quoted: @querySelector('[id^="quoted"]').checked
      skip_empty_lines: @querySelector('[id^="skip-empty-lines"]').checked
      fileEncoding: @encodingSelect.value
      relax_column_count: true

    trim = @querySelector('[name="trim"]:checked')?.value
    comment = @querySelector('[name="comment"]:checked')?.value
    escape = @querySelector('[name="escape"]:checked')?.value
    quote = @querySelector('[name="quote"]:checked')?.value
    delimiter =  @querySelector('[name="delimiter"]:checked')?.value
    rowDelimiter = @querySelector('[name="row-delimiter"]:checked')?.value

    if quote is '' or delimiter is '' or rowDelimiter is '' or comment is '' or escape is ''
      throw new Error('It should not be empty')

    if quote is 'custom'
      options.quote = @quoteTextEditor.getText()
    else
      options.quote = quote

    if escape is 'custom'
      options.escape = @escapeTextEditor.getText()
    else
      options.escape = escape

    if comment is 'custom'
      options.comment = @commentTextEditor.getText()
    else if comment is 'none'
      options.comment = ''
    else
      options.comment = comment

    if delimiter is 'custom'
      options.delimiter = @columnDelimiterTextEditor.getText()
    else
      options.delimiter = denormalizeValue(delimiter)

    if rowDelimiter is 'custom'
      options.rowDelimiter = @rowDelimiterTextEditor.getText()
    else unless rowDelimiter is 'auto'
      options.rowDelimiter = denormalizeValue(rowDelimiter)

    switch trim
      when 'both' then options.trim = true
      when 'left' then options.ltrim = true
      when 'right' then options.rtrim = true

    options


module.exports =
CSVEditorFormElement =
registerOrUpdateElement 'atom-csv-editor-form', CSVEditorFormElement.prototype
