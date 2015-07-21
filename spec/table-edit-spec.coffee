fs = require 'fs'
path = require 'path'
temp = require 'temp'

TableEdit = require '../lib/table-edit'
TableEditor = require '../lib/table-editor'
TableElement = require '../lib/table-element'

describe "TableEdit", ->
  [table, tableEditor] = []

  beforeEach ->
    waitsForPromise -> atom.packages.activatePackage('table-edit')

  describe 'when a csv file is opened', ->
    [csvDest, projectPath] = []

    beforeEach ->
      csvFixture = path.join(__dirname, 'fixtures', 'sample.csv')

      projectPath = temp.mkdirSync('table-edit-project')
      csvDest = path.join(projectPath, 'sample.csv')
      fs.writeFileSync(csvDest, fs.readFileSync(csvFixture))

      atom.project.setPaths([projectPath])

      waitsForPromise -> atom.workspace.open('sample.csv').then (t) -> table = t

    afterEach ->
      temp.cleanup()

    it 'opens a table editor for the file', ->
      expect(table instanceof TableEditor).toBeTruthy()
      expect(table.getScreenColumnCount()).toEqual(3)
      expect(table.getScreenRowCount()).toEqual(3)

    it 'clears the table undo stack', ->
      expect(table.getTable().undoStack.length).toEqual(0)

    it 'leaves the table in a unmodified state', ->
      expect(table.isModified()).toBeFalsy()

    describe 'when the table is modified', ->
      beforeEach ->
        table.addRow ['Bill', 45, 'male']
        table.addRow ['Bonnie', 42, 'female']

      describe 'when saved', ->
        spy = null
        beforeEach ->
          spy = jasmine.createSpy('did-save')
          table.onDidSave(spy)

          table.save()

          waitsFor -> spy.callCount > 0

        it 'save the new csv content on disk', ->
          content = fs.readFileSync(csvDest)

          expect(String(content)).toEqual("""
          name,age,gender
          Jane,32,female
          John,30,male
          Bill,45,male
          Bonnie,42,female

          """)

        it 'marks the table editor as saved', ->
          expect(table.isModified()).toBeFalsy()
