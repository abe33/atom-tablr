React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'
CellComponent = require './cell-component'

module.exports = React.createClass
  getInitialState: ->
    firstRow: 0
    lastRow: 0
    totalRows: 0
    rowHeight: 0
    columnsWidths: []
    columnsAligns: []

  render: ->
    {firstRow, lastRow, rowHeight, columnsWidths, columnsAligns} = @state
    {parentView} = @props

    rows = for row in [firstRow...lastRow]
      rowData = @props.table.getRow(row)
      cells = []

      rowData.eachCell (cell,i) ->
        cells.push new CellComponent({
          parentView
          row
          cell
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
          height: "#{rowHeight}px"
          top: "#{row * rowHeight}px"
      }, cells

    div {
      className: 'table-edit-content'
      style:
        height: @getTableHeight()
    }, rows

  getTableHeight: ->
    @state.totalRows * @state.rowHeight
