{SpacePenDSL} = require 'atom-utils'
columnName = require './column-name'

module.exports =
class TableHeaderCellElement extends HTMLElement
  SpacePenDSL.includeInto(this)

  @content: ->
    @span outlet: 'label'
    @div class: 'column-edit-action'
    @div class: 'column-resize-handle'

  setModel: ({column, index}) ->
    @released = false
    classes = @getHeaderCellClasses(column, index)
    @label.textContent = column.name ? columnName(index)
    @className = classes.join(' ')
    @dataset.column = index
    @style.cssText = "
      width: #{@tableEditor.getScreenColumnWidthAt(index)}px;
      left: #{@tableEditor.getScreenColumnOffsetAt(index)}px;
      text-align: #{@tableEditor.getScreenColumnAlignAt(index) ? 'left'};
    "

  isReleased: -> @released

  release: (dispatchEvent=true) ->
    return if @released
    @style.cssText = 'display: none;'
    @released = true

  getHeaderCellClasses: (column, index) ->
    classes = []
    classes.push 'active-column' if @tableElement.isCursorColumn(index)
    classes.push 'selected' if @tableElement.isSelectedColumn(index)

    if @tableEditor.order is index
      classes.push 'order'

      if @tableEditor.direction is 1
        classes.push 'ascending'
      else
        classes.push 'descending'

    classes

module.exports = TableHeaderCellElement = document.registerElement 'atom-table-header-cell', prototype: TableHeaderCellElement.prototype
