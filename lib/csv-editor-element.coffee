{CompositeDisposable} = require 'atom'
{SpacePenDSL, EventsDelegation} = require 'atom-utils'
CSVEditor = require './csv-editor'
TableEditor = require './table-editor'

nextId = 0

module.exports =
class CSVEditorElement extends HTMLElement
  SpacePenDSL.includeInto(this)
  EventsDelegation.includeInto(this)

  @content: ->
    id = nextId++

    @div class: 'settings-view', =>
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
          @div class: 'left-panel', =>
            @div class: 'control-group row-delimiters', =>
              @div class: 'controls', =>
                @label class: 'setting-title', 'Rows Delimiter'
                @tag 'atom-text-editor', outlet: 'rowDelimiterTextEditorElement', mini: true

              @div class: 'controls btn-group', =>
                @input type: 'radio', value: 'auto', name: 'row-delimiter', id: "auto-#{id}", checked: true
                @label class: 'btn', for: "auto-#{id}", 'auto'
                @input type: 'radio', value: '\r\n', name: 'row-delimiter', id: "char-return-new-line-#{id}"
                @label class: 'btn', for: "char-return-new-line-#{id}", '\\r\\n'
                @input type: 'radio', value: '\n', name: 'row-delimiter', id: "new-line-#{id}"
                @label class: 'btn', for: "new-line-#{id}", '\\n'
                @input type: 'radio', value: '\r', name: 'row-delimiter', id: "char-return-#{id}"
                @label class: 'btn', for: "char-return-#{id}", '\\r'
                @input type: 'radio', value: 'custom', name: 'row-delimiter', id: "custom-row-delimiter-#{id}"
                @label class: 'btn', for: "custom-row-delimiter-#{id}", 'custom'

            @div class: 'control-group delimiters', =>
              @div class: 'controls', =>
                @label class: 'setting-title', 'Field Delimiter'
                @tag 'atom-text-editor', outlet: 'delimiterTextEditorElement', mini: true

              @div class: 'controls btn-group', =>
                @input type: 'radio', value: ',', name: 'delimiter', id: "comma-#{id}", checked: true
                @label class: 'btn', for: "comma-#{id}", ','
                @input type: 'radio', value: ";", name: 'delimiter', id: "semi-colon-#{id}"
                @label class: 'btn', for: "semi-colon-#{id}", ";"
                @input type: 'radio', value: "-", name: 'delimiter', id: "dash-#{id}"
                @label class: 'btn', for: "dash-#{id}", "-"
                @input type: 'radio', value: "\t", name: 'delimiter', id: "tab-#{id}"
                @label class: 'btn', for: "tab-#{id}", "\\t"
                @input type: 'radio', value: 'custom', name: 'delimiter', id: "custom-delimiter-#{id}"
                @label class: 'btn', for: "custom-delimiter-#{id}", 'custom'

            @div class: 'control-group quotes', =>
              @div class: 'controls', =>
                @label class: 'setting-title', 'Quotes'
                @tag 'atom-text-editor', outlet: 'quoteTextEditorElement', mini: true

              @div class: 'controls btn-group', =>
                @input type: 'radio', value: '&quot;', name: 'quote', id: "double-quote-#{id}", checked: true
                @label class: 'btn', for: "double-quote-#{id}", '"'
                @input type: 'radio', value: "'", name: 'quote', id: "simple-quote-#{id}"
                @label class: 'btn', for: "simple-quote-#{id}", "'"
                @input type: 'radio', value: 'custom', name: 'quote', id: "custom-quote-#{id}"
                @label class: 'btn', for: "custom-quote-#{id}", 'custom'

            @div class: 'control-group escapes', =>
              @div class: 'controls', =>
                @label class: 'setting-title', 'Escape'
                @tag 'atom-text-editor', outlet: 'escapeTextEditorElement', mini: true

              @div class: 'controls btn-group', =>
                @input type: 'radio', value: '&quot;', name: 'escape', id: "double-quote-escape-#{id}", checked: true
                @label class: 'btn', for: "double-quote-escape-#{id}", '"'
                @input type: 'radio', value: "'", name: 'escape', id: "simple-quote-escape-#{id}"
                @label class: 'btn', for: "simple-quote-escape-#{id}", "'"
                @input type: 'radio', value: "\\", name: 'escape', id: "backslash-escape-#{id}"
                @label class: 'btn', for: "backslash-escape-#{id}", "\\"
                @input type: 'radio', value: 'custom', name: 'escape', id: "custom-escape-#{id}"
                @label class: 'btn', for: "custom-escape-#{id}", 'custom'

            @div class: 'control-group comments', =>
              @div class: 'controls', =>
                @label class: 'setting-title', 'Comment'
                @tag 'atom-text-editor', outlet: 'commentTextEditorElement', mini: true

              @div class: 'controls btn-group', =>
                @input type: 'radio', value: '#', name: 'comment', id: "sharp-comment-#{id}", checked: true
                @label class: 'btn', for: "sharp-comment-#{id}", '#'
                @input type: 'radio', value: 'custom', name: 'comment', id: "custom-comment-#{id}"
                @label class: 'btn', for: "custom-comment-#{id}", 'custom'

          @div class: 'right-panel', =>
            @div class: 'control-group trim', =>
              @label class: 'setting-title', 'Trim Fields'

              @div class: 'controls btn-group', =>
                @input type: 'radio', value: 'left', name: 'trim', id: "left-trim-#{id}"
                @label class: 'btn', for: "left-trim-#{id}", 'left'
                @input type: 'radio', value: 'right', name: 'trim', id: "right-trim-#{id}"
                @label class: 'btn', for: "right-trim-#{id}", 'right'
                @input type: 'radio', value: 'both', name: 'trim', id: "both-trim-#{id}", checked: true
                @label class: 'btn', for: "both-trim-#{id}", 'both'

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


  createdCallback: ->
    @setAttribute 'tabindex', -1
    @rowDelimiterTextEditor = @rowDelimiterTextEditorElement.getModel()
    @delimiterTextEditor = @delimiterTextEditorElement.getModel()
    @quoteTextEditor = @quoteTextEditorElement.getModel()
    @escapeTextEditor = @escapeTextEditorElement.getModel()
    @commentTextEditor = @commentTextEditorElement.getModel()
    @subscriptions = new CompositeDisposable

    @subscriptions.add @subscribeTo @openTextEditorButton,
      click: => @model.openTextEditor(@collectOptions())

    @subscriptions.add @subscribeTo @openTableEditorButton,
      click: =>
        @messagesContainer.innerHTML = ''

        @model.openTableEditor(@collectOptions()).catch (reason) =>
          alert = document.createElement('div')
          alert.classList.add('alert')
          alert.classList.add('alert-danger')
          alert.textContent = reason.message

          @messagesContainer.appendChild(alert)

    @subscriptions.add @rowDelimiterTextEditor.onDidChange =>
      if @rowDelimiterTextEditor.getText() isnt ''
        @querySelector('[id^="custom-row-delimiter"]').checked = true
      else
        @querySelector('[id^="auto"]').checked = true

    @subscriptions.add @delimiterTextEditor.onDidChange =>
      if @delimiterTextEditor.getText() isnt ''
        @querySelector('[id^="custom-delimiter"]').checked = true
      else
        @querySelector('[id^="comma"]').checked = true

    @subscriptions.add @quoteTextEditor.onDidChange =>
      if @quoteTextEditor.getText() isnt ''
        @querySelector('[id^="custom-quote"]').checked = true
      else
        @querySelector('[id^="double-quote"]').checked = true

    @subscriptions.add @escapeTextEditor.onDidChange =>
      if @escapeTextEditor.getText() isnt ''
        @querySelector('[id^="custom-escape"]').checked = true
      else
        @querySelector('[id^="double-quote-escape"]').checked = true

    @subscriptions.add @commentTextEditor.onDidChange =>
      if @commentTextEditor.getText() isnt ''
        @querySelector('[id^="custom-comment"]').checked = true
      else
        @querySelector('[id^="sharp-comment"]').checked = true

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

  setModel: (@model) ->
    @subscriptions.add @model.onDidOpen ({editor}) =>
      return unless editor instanceof TableEditor

      @innerHTML = ''
      @appendChild(atom.views.getView(editor))

      @subscriptions.dispose()
      @subscriptions = new CompositeDisposable

    @model.applyChoice()

module.exports = CSVEditorElement = document.registerElement 'atom-csv-editor', prototype: CSVEditorElement.prototype

CSVEditorElement.registerViewProvider = ->
  atom.views.addViewProvider CSVEditor, (model) ->
    element = new CSVEditorElement
    element.setModel(model)
    element
