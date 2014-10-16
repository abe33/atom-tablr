React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'

module.exports = React.createClass
  getInitialState: ->
    firstRow: 0
    lastRow: 0
    totalRows: 0
    rowHeight: 0

  render: ->
    {firstRow, lastRow, rowHeight} = @state

    rows = for row in [firstRow...lastRow]
      rowData = @props.table.getRow(row)
      columns = []
      rowData.eachCell (cell) ->
        columns.push div className: 'table-edit-column', cell.getValue()

      div className: 'table-edit-row', style: { height: "#{rowHeight}px", top: "#{row * rowHeight}px" }, 'data-row-id': row + 1, "Row #{row + 1}", columns

    div className: 'table-edit-content', style: { height: @getTableHeight() }, rows

  getTableHeight: ->
    @state.totalRows * @state.rowHeight
