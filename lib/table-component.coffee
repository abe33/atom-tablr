React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'

module.exports = React.createClass
  getInitialState: ->
    firstRow: 0
    lastRow: 0
    totalRows: 0
    rowHeight: 0
    columnsWidth: []

  render: ->
    {firstRow, lastRow, rowHeight, columnsWidth} = @state

    console.log columnsWidth

    rows = for row in [firstRow...lastRow]
      rowData = @props.table.getRow(row)
      columns = []
      rowData.eachCell (cell,i) ->
        columns.push div className: 'table-edit-column', style: { width: columnsWidth[i] }, cell.getValue()

      div className: 'table-edit-row', style: { height: "#{rowHeight}px", top: "#{row * rowHeight}px" }, 'data-row-id': row + 1, columns

    div className: 'table-edit-content', style: { height: @getTableHeight() }, rows

  getTableHeight: ->
    @state.totalRows * @state.rowHeight
