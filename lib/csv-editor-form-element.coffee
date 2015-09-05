{CompositeDisposable, Emitter} = require 'atom'
{SpacePenDSL, EventsDelegation} = require 'atom-utils'

nextId = 0

module.exports =
class CSVEditorFormElement extends HTMLElement
  SpacePenDSL.includeInto(this)
  EventsDelegation.includeInto(this)

  @content: ->
    id = nextId++

    labelFromValue = (value) ->
      String(value)
      .replace('\n','\\n')
      .replace('\t','\\t')
      .replace('\r','\\r')
      .replace('\t','\\t')

    normalizeValue = (value) ->
      value?.replace('"','&quot;')

    radios = (options) =>
      {name, label, options, outlet, selected} = options

      @div class: 'controls btn-group', =>
        for optionName, value of options
          inputOption = type: 'radio', value: normalizeValue(value), name: name, id: "#{optionName}-#{name}-#{id}"
          inputOption.checked = true if selected is optionName
          @input(inputOption)
          @label class: 'btn', for: "#{optionName}-#{name}-#{id}", labelFromValue(value)

    radiosOnly = (options={}) =>
      {name, label} = options
      @div class: "control-group with-radios #{name}", =>
        @label class: 'setting-title', label
        radios(options)

    radiosWithTextEditor = (options={}) =>
      {name, label, outlet, selected} = options
      @div class: "control-group with-text-editor #{name}", =>
        @div class: 'controls', =>
          @label class: 'setting-title', label
          @tag 'atom-text-editor', outlet: "#{outlet}TextEditorElement", mini: true

        options.options["custom"] = 'custom'
        radios(options)

      reversedOptions = {}
      reversedOptions[v] = k for k,v of options.options

      CSVEditorFormElement::__bindings__ ?= []
      CSVEditorFormElement::initializeBindings ?= ->
        @__bindings__.forEach (f) => f.call(this)
        @__bindings__.length = 0
      CSVEditorFormElement::__bindings__.push ->
        @["#{outlet}TextEditor"] = @["#{outlet}TextEditorElement"].getModel()
        @subscriptions.add @["#{outlet}TextEditor"].onDidChange =>
          return unless @attached
          if @["#{outlet}TextEditor"].getText() isnt ''
            @querySelector("#custom-#{name}-#{id}")?.checked = true
          else
            @querySelector("##{selected}-#{name}-#{id}")?.checked = true

          @emitChangeEvent()

      CSVEditorFormElement::__defaults__ ?= []
      CSVEditorFormElement::initializeDefaults ?= (options) ->
        @__defaults__.forEach (f) => f.call(this, options)
        @__defaults__.length = 0
        @initialized = true
      CSVEditorFormElement::__defaults__.push (options) ->
        value = options[outlet]
        optionName = reversedOptions[value]

        if optionName? and radio = @querySelector("##{optionName}-#{name}-#{id}")
          radio.checked = true
        else if value?
          @["#{outlet}TextEditor"].setText(value)
          @querySelector("#custom-#{name}-#{id}")?.checked = true
        else if radio = @querySelector("##{selected}-#{name}-#{id}")
          radio.checked = true

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
          }

        @div class: 'panel', =>
          radiosWithTextEditor {
            label: 'Column Delimiter'
            name: 'delimiter'
            outlet: 'delimiter'
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
            options:
              no: 'no'
              left: 'left'
              right: 'right'
              both: 'both'
          }

        @div class: 'panel', =>
          @div class: 'control-group header', =>
            @label class: 'setting-title', for: "header-#{id}", 'Header'
            @input type: 'checkbox', name: 'header', id: "header-#{id}"

          @div class: 'control-group eof', =>
            @label class: 'setting-title', for: "eof-#{id}", 'End Of File'
            @input type: 'checkbox', name: 'eof', id: "eof-#{id}"

          @div class: 'control-group quoted', =>
            @label class: 'setting-title', for: "quoted-#{id}", 'Quoted'
            @input type: 'checkbox', name: 'quoted', id: "quoted-#{id}"

          @div class: 'control-group skip-empty-lines', =>
            @label class: 'setting-title', for: "skip-empty-lines-#{id}", 'Skip Empty Lines'
            @input type: 'checkbox', name: 'skip-empty-lines', id: "skip-empty-lines-#{id}"

      @p 'Preview of the parsed CSV (down to the fifth row):'
      @tag 'atom-csv-preview', outlet: 'preview'

  createdCallback: ->
    @subscriptions = new CompositeDisposable
    @emitter = new Emitter

    @subscriptions.add @subscribeTo this, 'input',
      change: => @emitChangeEvent()

    @initializeBindings()

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
    @querySelector('[id^="header"]').checked = true if options.header
    @querySelector('[id^="eof"]').checked = true if options.eof
    @querySelector('[id^="quoted"]').checked = true if options.quoted
    @querySelector('[id^="skip-empty-lines"]').checked = true if options.skip_empty_lines

    @querySelector('[id^="left-trim"]').checked = true if options.ltrim
    @querySelector('[id^="right-trim"]').checked = true if options.rtrim
    @querySelector('[id^="both-trim"]').checked = true if options.trim

    requestAnimationFrame => @initializeDefaults(options)

  collectOptions: ->
    options =
      remember: @querySelector('[id^="remember-choice"]').checked
      header: @querySelector('[id^="header"]').checked
      eof: @querySelector('[id^="eof"]').checked
      quoted: @querySelector('[id^="quoted"]').checked
      skip_empty_lines: @querySelector('[id^="skip-empty-lines"]').checked

    trim = @querySelector('[name="trim"]:checked')?.value
    comment = @querySelector('[name="comment"]:checked')?.value
    escape = @querySelector('[name="escape"]:checked')?.value
    quote = @querySelector('[name="quote"]:checked')?.value
    delimiter =  @querySelector('[name="delimiter"]:checked')?.value
    rowDelimiter = @querySelector('[name="row-delimiter"]:checked')?.value

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
    else
      options.comment = comment

    if delimiter is 'custom'
      options.delimiter = @delimiterTextEditor.getText()
    else
      options.delimiter = delimiter

    if rowDelimiter is 'custom'
      options.rowDelimiter = @rowDelimiterTextEditor.getText()
    else unless rowDelimiter is 'auto'
      options.rowDelimiter = rowDelimiter

    switch trim
      when 'both' then options.trim = true
      when 'left' then options.ltrim = true
      when 'right' then options.rtrim = true

    options


module.exports = CSVEditorFormElement = document.registerElement 'atom-csv-editor-form', prototype: CSVEditorFormElement.prototype
