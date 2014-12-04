React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'

module.exports = React.createClass
  render: ->
    {firstRow, lastRow, totalRows, gutter, height, parentView} = @props

    rows = for row in [firstRow...lastRow]
      classes = ['table-edit-row-number']
      classes.push 'active-row' if parentView.isActiveRow(row)
      classes.push 'selected' if parentView.isSelectedRow(row)

      resizeHandle = div className: 'row-resize-handle'

      div {
        className: classes.join(' ')
        key: "row-number-#{row}"
        style:
          height: "#{parentView.getScreenRowHeightAt(row)}px"
          top: "#{parentView.getScreenRowOffsetAt(row)}px"
      }, row + 1, resizeHandle

    rows.unshift div className: 'table-edit-gutter-filler', totalRows

    div {
      className: 'table-edit-gutter'
      style: {height}
    }, rows
