{SpacePenDSL} = require 'atom-utils'

module.exports =
class TableGutterCellElement extends HTMLElement
  SpacePenDSL.includeInto(this)

  @content: ->
    @div class: 'row-resize-handle'
    @span outlet: 'label'

  setModel: ({row}) ->
    @released = false
    classes = @getGutterCellClasses(row)
    @label.textContent = row + 1
    @className = classes.join(' ')
    @style.cssText = "
      height: #{@tableEditor.getScreenRowHeightAt(row)}px;
      top: #{@tableEditor.getScreenRowOffsetAt(row)}px;
    "

  isReleased: -> @released

  release: (dispatchEvent=true) ->
    return if @released
    @style.cssText = 'display: none;'
    @released = true

  getGutterCellClasses: (row) ->
    classes = []
    classes.push 'active-row' if @tableElement.isCursorRow(row)
    classes.push 'selected' if @tableElement.isSelectedRow(row)
    classes

module.exports = TableGutterCellElement = document.registerElement 'atom-table-gutter-cell', prototype: TableGutterCellElement.prototype
