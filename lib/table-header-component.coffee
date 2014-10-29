React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'

module.exports = React.createClass
  getInitialState: ->
    columnsWidths: []
    columnsAligns: []

  render: ->
    {table, parentView} = @props
    {columnsWidths, columnsAligns} = @state

    cells = []
    for column,index in table.getColumns()
      classes = ['table-edit-header-cell']
      classes.push 'active-column' if parentView.isActiveColumn(index)

      cells.push div {
        key: "header-cell-#{index}"
        className: classes.join(' ')
        style:
          width: columnsWidths[index]
          'text-align': columnsAligns[index] ? 'left'
      }, column.name

    div className: 'table-edit-header-row', cells
