React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'

module.exports = React.createClass
  getInitialState: ->
    columnsWidths: []
    columnsAligns: []

  render: ->
    {table, parentView} = @props
    {columnsWidths, columnsAligns, gutter, totalRows} = @state

    cells = []
    for column,index in table.getColumns()
      classes = ['table-edit-header-cell']
      classes.push 'active-column' if parentView.isActiveColumn(index)
      classes.push 'order' if parentView.order is column.name

      cells.push div {
        key: "header-cell-#{index}"
        className: classes.join(' ')
        style:
          width: columnsWidths[index]
          'text-align': columnsAligns[index] ? 'left'
      }, column.name

    row = div className: 'table-edit-header-row', cells

    content = [row]
    if gutter
      content.unshift div className: 'table-edit-header-filler', totalRows

    div className: 'table-edit-header-content', content
