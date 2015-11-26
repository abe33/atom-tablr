{CompositeDisposable} = require 'atom'
{SpacePenDSL, registerOrUpdateElement} = require 'atom-utils'
columnName = require './column-name'

module.exports =
class TableHeaderCellElement extends HTMLElement
  SpacePenDSL.includeInto(this)

  @content: ->
    @span outlet: 'label'
    @div class: 'column-actions', =>
      @button class: 'column-fit-action', outlet: 'fitButton'
      @button class: 'column-apply-sort-action', outlet: 'sortButton'
      @button class: 'column-edit-action', outlet: 'editButton'
    @div class: 'column-resize-handle'

  createdCallback: ->
    @subscriptions = new CompositeDisposable()
    @subscriptions.add atom.tooltips.add(@editButton, {title: 'Edit column name'})
    @subscriptions.add atom.tooltips.add(@fitButton, {title: 'Adjust width to content'})
    @subscriptions.add atom.tooltips.add(@sortButton, {title: 'Apply sort on table'})

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

module.exports =
TableHeaderCellElement =
registerOrUpdateElement 'tablr-header-cell', TableHeaderCellElement.prototype
