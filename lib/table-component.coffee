React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'

module.exports = React.createClass
  getInitialState: ->
    firstRow: 0
    lastRow: 0
    totalRows: 0
    rowHeight: 0

  render: ->
    rows = []

    {firstRow, lastRow, rowHeight} = @state

    for row in [firstRow...lastRow]
      rows.push div className: 'table-edit-row', style: { height: "#{rowHeight}px", top: "#{row * rowHeight}px" }, 'data-row-id': row + 1, "Row #{row + 1}"

    div className: 'table-edit-content', style: { height: @getTableHeight() }, rows

  getTableHeight: ->
    @state.totalRows * @state.rowHeight
