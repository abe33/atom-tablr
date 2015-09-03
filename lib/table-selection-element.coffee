{CompositeDisposable} = require 'event-kit'
{EventsDelegation, SpacePenDSL} = require 'atom-utils'
Selection = require './selection'

class TableSelectionElement extends HTMLElement
  EventsDelegation.includeInto(this)
  SpacePenDSL.includeInto(this)

  @content: ->
    @div class: 'selection-box-handle', outlet: 'selectionBoxHandle'

  createdCallback: ->
    @subscriptions = new CompositeDisposable

  getModel: -> @selection

  setModel: (@selection) ->
    {@tableEditor} = @selection

    @subscriptions.add @selection.onDidDestroy => @destroy()
    @subscriptions.add @selection.onDidChangeRange => @update()

    @update()

  destroy: ->
    return if @destroyed

    @parentNode?.removeChild(this)
    @subscriptions.dispose()
    @selection = @tableEditor = null
    @destroyed = true

  update: ->
    if @selection.spanMoreThanOneCell()
      {top, left, right, bottom} = @selectionScrollRect()
      height = bottom - top
      width = right - left
      @style.cssText = """
      top: #{top}px;
      left: #{left}px;
      height: #{height}px;
      width: #{width}px;
      """

    else
      @style.cssText = "display: none"

  selectionScrollRect: ->
    range = @selection.getRange()

    left: @tableEditor.getScreenColumnOffsetAt(range.start.column)
    top: @tableEditor.getScreenRowOffsetAt(range.start.row)
    right: @tableEditor.getScreenColumnOffsetAt(range.end.column - 1) + @tableEditor.getScreenColumnWidthAt(range.end.column - 1)
    bottom: @tableEditor.getScreenRowOffsetAt(range.end.row - 1) + @tableEditor.getScreenRowHeightAt(range.end.row - 1)


module.exports = TableSelectionElement = document.registerElement 'atom-table-editor-selection', prototype: TableSelectionElement.prototype

TableSelectionElement.registerViewProvider = ->
  atom.views.addViewProvider Selection, (model) ->
    element = new TableSelectionElement
    element.setModel(model)
    element
