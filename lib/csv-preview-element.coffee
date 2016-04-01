{registerOrUpdateElement} = require 'atom-utils'
columnName = require './column-name'

module.exports =
class CSVPreviewElement extends HTMLElement
  createdCallback: ->

  attachedCallback: ->

  clean: ->
    @innerHTML = "<span class='loading loading-spinner-medium inline-block'></span>"

  error: (reason) ->
    @innerHTML = "<span class=\"alert alert-danger\">#{reason.message}</span>"

  render: (preview, options={}) ->
    columns = if options.header
      preview.shift()
    else
      length = Math.max(preview.map((d) -> d.length)...)
      columnName(i) for i in [0...length]

    table = document.createElement('table')
    header = document.createElement('thead')
    body = document.createElement('tbody')

    headerRow = document.createElement('tr')
    for column in columns
      cell = document.createElement('th')
      cell.textContent = column
      headerRow.appendChild(cell)

    for row in preview
      rowElement = document.createElement('tr')

      for i in [0...columns.length]
        cell = document.createElement('td')
        cell.textContent = row[i]
        rowElement.appendChild(cell)

      body.appendChild(rowElement)

    header.appendChild(headerRow)
    table.appendChild(header)
    table.appendChild(body)

    wrapper = document.createElement('div')
    wrapper.classList.add('table-wrapper')
    wrapper.appendChild(table)

    @innerHTML = ''
    @appendChild(wrapper)

module.exports =
CSVPreviewElement =
registerOrUpdateElement 'atom-csv-preview', CSVPreviewElement.prototype
