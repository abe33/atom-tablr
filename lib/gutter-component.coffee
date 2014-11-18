React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'

module.exports = React.createClass
  render: ->
    {firstRow, lastRow, totalRows, gutter} = @props

    rows = for row in [firstRow...lastRow]
      div className: 'table-edit-row-number', key: "row-number-#{row}", row

    rows.unshift div className: 'table-edit-gutter-filler', totalRows

    div className: 'table-edit-gutter', rows
