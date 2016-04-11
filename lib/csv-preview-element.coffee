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
    return if preview.length is 0

    columns = if options.header
      preview.shift()
    else
      length = Math.max(0, preview.map((d) -> d.length)...)
      columnName(i) for i in [0...length]

    table = document.createElement('table')
    header = document.createElement('thead')
    body = document.createElement('tbody')

    headerRow = document.createElement('tr')

    cell = document.createElement('th')
    cell.textContent = '#'
    headerRow.appendChild(cell)

    for column in columns
      cell = document.createElement('th')
      cell.textContent = column
      headerRow.appendChild(cell)

    for row,r in preview
      rowElement = document.createElement('tr')

      cell = document.createElement('td')
      cell.textContent = r + 1
      rowElement.appendChild(cell)

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
