React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'

GutterComponent = require './gutter-component'
SelectionComponent = require './selection-component'
SelectionHandleComponent = require './selection-handle-component'

module.exports = React.createClass
  getInitialState: ->
    firstRow: 0
    lastRow: 0
    totalRows: 0
    columnsWidths: []
    columnsAligns: []

  render: ->
    {firstRow, lastRow, columnsWidths, columnsAligns, gutter} = @state
    {parentView} = @props
    height = @getTableHeight()

    rows = for row in [firstRow...lastRow]
      rowData = parentView.getScreenRow(row)
      cells = []

      rowData.eachCell (cell,i) ->

        classes = ['table-edit-cell']
        if parentView.isActiveCell(cell)
          classes.push 'active'
        else if parentView.isActiveColumn(i)
          classes.push 'active-column'

        classes.push 'selected' if parentView.isSelectedPosition([row, i])

        classes.push 'order' if parentView.order is cell.getColumn().name

        cells.push new cell.column.componentClass({
          parentView
          row
          cell
          classes
          index: i
          columnWidth: columnsWidths[i]
          columnAlign: columnsAligns[i]
        })

      classes = ['table-edit-row']
      classes.push 'active-row' if parentView.isActiveRow(row)

      div {
        key: "row-#{row}"
        className: classes.join(' ')
        'data-row-id': row + 1
        style:
          height: "#{parentView.getScreenRowHeightAt(row)}px"
          top: "#{parentView.getScreenRowOffsetAt(row)}px"
      }, cells

    content = [div className: 'table-edit-rows', rows]

    subComponentProps = {parentView, height}
    subComponentProps[k] = v for k,v of @state

    if gutter
      gutterComponent = new GutterComponent(subComponentProps)
      content.unshift gutterComponent

    if parentView.selectionSpansManyCells()
      rows.push new SelectionComponent(subComponentProps)
      rows.push new SelectionHandleComponent(subComponentProps)

    div {
      className: 'table-edit-content'
      style: {height}
    }, content

  getTableHeight: ->
    lastIndex = Math.max(0, @state.totalRows - 1)
    return 0 if lastIndex is 0

    @props.parentView.getScreenRowOffsetAt(lastIndex) + @props.parentView.getScreenRowHeightAt(lastIndex)
