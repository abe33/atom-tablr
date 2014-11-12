React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'

module.exports = React.createClass
  getInitialState: ->
    {}

  render: ->
    {row, cell, index, columnWidth, columnAlign, classes} = @props

    div {
      key: "cell-#{row}-#{index}"
      className: classes.join(' ')
      style:
        width: columnWidth
        'text-align': columnAlign ? 'left'
    }, cell.getValue()
