React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'

module.exports = React.createClass
  render: ->
    {parentView} = @props
    {top, left, width, height} = parentView.selectionScrollRect()

    div className: 'selection-box', style: {
      top: top + 'px'
      left: left + 'px'
      height: height + 'px'
      width: width + 'px'
    }
