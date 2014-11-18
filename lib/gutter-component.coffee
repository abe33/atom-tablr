React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'

module.exports = React.createClass
  render: ->
    {firstRow, lastRow, totalRows, gutter, height, parentView} = @props

    rows = for row in [firstRow...lastRow]
      classes = ['table-edit-row-number']
      classes.push 'active-row' if parentView.isActiveRow(row)

      div {
        className: classes.join(' ')
        key: "row-number-#{row}"
        style:
          height: "#{parentView.getRowHeightAt(row)}px"
          top: "#{parentView.getRowOffsetAt(row)}px"
      }, row + 1

    rows.unshift div className: 'table-edit-gutter-filler', totalRows

    div {
      className: 'table-edit-gutter'
      style: {height}
    }, rows
