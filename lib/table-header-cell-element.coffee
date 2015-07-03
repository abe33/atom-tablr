{SpacePenDSL} = require 'atom-utils'

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
    @label.textContent = column.name
    @className = classes.join(' ')
    @dataset.column = index
    @style.cssText = "
      width: #{@tableElement.getScreenColumnWidthAt(index)}px;
      left: #{@tableElement.getScreenColumnOffsetAt(index)}px;
      text-align: #{@tableElement.getColumnAlign(index) ? 'left'};
    "

  isReleased: -> @released

  release: (dispatchEvent=true) ->
    return if @released
    @style.cssText = 'display: none;'
    @released = true

  getHeaderCellClasses: (column, index) ->
    classes = []
    classes.push 'active-column' if @tableElement.isActiveColumn(index)

    if @tableElement.order is column.name
      classes.push 'order'

      if @tableElement.direction is 1
        classes.push 'ascending'
      else
        classes.push 'descending'

    classes

module.exports = TableHeaderCellElement = document.registerElement 'atom-table-header-cell', prototype: TableHeaderCellElement.prototype
