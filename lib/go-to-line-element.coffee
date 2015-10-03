{SpacePenDSL} = require 'atom-utils'

module.exports =
class GoToLineElement extends HTMLElement
  SpacePenDSL.includeInto(this)

  @content: ->
    @tag 'atom-text-editor', mini: true, outlet: 'miniEditor'
    @div class: 'message', outlet: 'message', """
    Enter a cell row:column to go to. The column can be either specified with its name or its position.
    """

  createdCallback: ->

  attachedCallback: ->
    @miniEditor.focus()

  attach: ->
    @panel = atom.workspace.addModalPanel(item: this, visible: true)

  confirm: ->
    text = @miniEditor.getModel().getText().trim()

    if text.length > 0
      result = text.split(':').map (s) ->
        if /^\d+$/.test(s) then Number(s) else s

      @tableElement.goToLine(result)

    @destroy()

  destroy: ->
    @panel?.destroy()
    @tableElement.focus()

  setModel: (@tableElement) ->

module.exports = GoToLineElement = document.registerElement 'atom-table-go-to-line', prototype: GoToLineElement.prototype

GoToLineElement.registerCommands = ->
  atom.commands.add 'atom-table-go-to-line',
    'core:cancel': -> @destroy()
    'core:confirm': -> @confirm()

GoToLineElement.registerCommands()
