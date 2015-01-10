React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'

module.exports = React.createClass
  render: ->
    {parentView} = @props

    {top, left, width, height} = parentView.selectionScrollRect()

    div className: 'selection-box-handle', style: {
      top: (top + height) + 'px'
      left: width + 'px'
      transform: "translate(#{left + 'px'}, 0)"
    }
