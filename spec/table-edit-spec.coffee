TableEdit = require '../lib/table-edit'
TableEditor = require '../lib/table-editor'
TableElement = require '../lib/table-element'

describe "TableEdit", ->
  [table, tableEditor] = []

  beforeEach ->
    waitsForPromise -> atom.packages.activatePackage('table-edit')

  describe 'when a csv file is opened', ->
    beforeEach ->
      waitsForPromise -> atom.workspace.open('sample.csv').then (t) -> table = t

    it 'opens a table editor for the file', ->
      expect(table instanceof TableEditor).toBeTruthy()
      expect(table.getScreenColumnCount()).toEqual(3)
      expect(table.getScreenRowCount()).toEqual(2)

    it 'clears the table undo stack', ->
      expect(table.getTable().undoStack.length).toEqual(0)

    it 'leaves the table in a unmodified state', ->
      expect(table.isModified()).toBeFalsy()
