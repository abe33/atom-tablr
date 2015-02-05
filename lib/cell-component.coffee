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
      'data-row-id': row + 1
      'data-column-id': index + 1
      style:
        width: "#{parentView.getScreenColumnWidthAt(index)}px"
        left: "#{parentView.getScreenColumnOffsetAt(index)}px"
        height: "#{parentView.getScreenRowHeightAt(row)}px"
        top: "#{parentView.getScreenRowOffsetAt(row)}px"
        'text-align': columnAlign ? 'left'
    }, cell.getValue() ? parentView.getUndefinedDisplay()
