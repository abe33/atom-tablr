React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'

GutterComponent = require './gutter-component'

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

        if parentView.isSelectedPosition([row, i])
          classes.push 'selected'

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

    if gutter
      gutterProps = {parentView, height}
      gutterProps[k] = v for k,v of @state
      gutterComponent = new GutterComponent(gutterProps)
      content.unshift gutterComponent

    div {
      className: 'table-edit-content'
      style: {height}
    }, content

  getTableHeight: ->
    lastIndex = Math.max(0, @state.totalRows - 1)
    return 0 if lastIndex is 0

    @props.parentView.getRowOffsetAt(lastIndex) + @props.parentView.getRowHeightAt(lastIndex)
