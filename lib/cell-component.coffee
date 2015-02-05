React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'

module.exports = React.createClass
  getInitialState: ->
    {}

  render: ->
    {parentView, row, cell, index, columnAlign, classes} = @props

    div {
      key: "cell-#{row}-#{index}"
      className: classes.join(' ')
      style:
        width: "#{parentView.getScreenColumnWidthAt(index)}px"
        left: "#{parentView.getScreenColumnOffsetAt(index)}px"
        'text-align': columnAlign ? 'left'
    }, cell.getValue() ? parentView.getUndefinedDisplay()
