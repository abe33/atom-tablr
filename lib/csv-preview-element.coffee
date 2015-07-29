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
      columnName(i) for i in [0...preview[0].length]

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

      for value in row
        cell = document.createElement('td')
        cell.textContent = value
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

module.exports = CSVPreviewElement = document.registerElement 'atom-csv-preview', prototype: CSVPreviewElement.prototype
