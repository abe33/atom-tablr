React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'

module.exports = React.createClass
  getInitialState: ->
    {}

  render: ->
    {row, cell, index, columnWidth, columnAlign, parentView} = @props

    classes = ['table-edit-cell']
    if parentView.isActiveCell(cell)
      classes.push 'active'
    else if parentView.isActiveColumn(index)
      classes.push 'active-column'

    div {
      key: "cell-#{row}-#{index}"
      className: classes.join(' ')
      style:
        width: columnWidth
        'text-align': columnAlign ? 'left'
    }, 'foo: ' + cell.getValue()
