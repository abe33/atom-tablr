fs = require 'fs'
csv = require 'csv'
TableEditor = require './table-editor'

module.exports =
class CSVTable
  constructor: (@uriToOpen, @options={}) ->

  open: ->
    new Promise (resolve, reject) =>
      fileContent = fs.readFileSync(@uriToOpen)
      csv.parse fileContent, (err, data) =>
        return reject(err) if err?

        tableEditor = new TableEditor
        return resolve(tableEditor) if data.length is 0

        for i in [0...data[0].length]
          tableEditor.addColumn(tableEditor.getColumnName(i), {}, false)

        tableEditor.addRows(data)
        tableEditor.setSaveHandler(@save)
        tableEditor.initializeAfterOpen()

        resolve(tableEditor)

  save: (editor) =>
    new Promise (resolve, reject) =>
      csv.stringify editor.getRows(), @options, (err, data) =>
        return reject(err) if err?

        fs.writeFile @uriToOpen, data, (err) =>
          return reject(err) if err?
          resolve()
