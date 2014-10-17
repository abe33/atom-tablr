React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'

module.exports = React.createClass
  getInitialState: ->
    columnsWidths: []
    columnsAligns: []

  render: ->
    {table} = @props
    {columnsWidths, columnsAligns} = @state

    cells = []
    for column,index in table.getColumns()
      cells.push div {
        className: 'table-edit-header-cell'
        style:
          width: columnsWidths[index]
          'text-align': columnsAligns[index] ? 'left'
      }, column.name

    div className: 'table-edit-header-row', cells
