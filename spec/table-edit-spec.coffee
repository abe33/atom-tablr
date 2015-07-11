TableEdit = require '../lib/table-edit'
Table = require '../lib/table'
TableElement = require '../lib/table-element'

# Use the command `window:run-package-specs` (cmd-alt-ctrl-p) to run specs.
#
# To run a specific `it` or `describe` block add an `f` to the front (e.g. `fit`
# or `fdescribe`). Remove the `f` to unfocus the block.

describe "TableEdit", ->
  [table, tableEditor] = []

  beforeEach ->
    waitsForPromise -> atom.packages.activatePackage('table-edit')

  describe 'when a csv file is opened', ->
    beforeEach ->
      waitsForPromise -> atom.workspace.open('sample.csv').then (t) -> table = t

    it 'opens a table editor for the file', ->
      expect(table instanceof Table).toBeTruthy()
      expect(table.getColumnCount()).toEqual(3)
      expect(table.getRowCount()).toEqual(2)
