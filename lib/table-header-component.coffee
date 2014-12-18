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

      if parentView.order is column.name
        classes.push 'order'

        if parentView.direction is 1
          classes.push 'ascending'
        else
          classes.push 'descending'

      editAction = div className: 'column-edit-action'
      resizeHandle = div className: 'column-resize-handle'

      cells.push div {
        key: "header-cell-#{index}"
        className: classes.join(' ')
        style:
          width: columnsWidths[index]
          'text-align': columnsAligns[index] ? 'left'
      }, column.name, editAction, resizeHandle

    row = div className: 'table-edit-header-row', cells

    content = [row]
    if gutter
      content.unshift div className: 'table-edit-header-filler', totalRows

    content.push div className: 'column-resize-ruler'

    div className: 'table-edit-header-content', content
