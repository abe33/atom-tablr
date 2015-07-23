fs = require 'fs'
path = require 'path'
temp = require 'temp'

TableEdit = require '../lib/table-edit'
TableEditor = require '../lib/table-editor'
CSVEditor = require '../lib/csv-editor'
TableElement = require '../lib/table-element'

{click} = require './helpers/events'

describe "CSVEditor", ->
  [csvEditor, csvEditorElement] = []

  beforeEach ->
    waitsForPromise -> atom.packages.activatePackage('table-edit')

  describe 'when a csv file is opened', ->
    [csvDest, projectPath, openSpy] = []

    openFixture = (fixtureName) ->
      csvFixture = path.join(__dirname, 'fixtures', 'sample.csv')

      projectPath = temp.mkdirSync('table-edit-project')
      csvDest = path.join(projectPath, 'sample.csv')
      fs.writeFileSync(csvDest, fs.readFileSync(csvFixture))

      atom.project.setPaths([projectPath])

      waitsForPromise -> atom.workspace.open('sample.csv').then (t) ->
        csvEditor = t
        csvEditorElement = atom.views.getView(csvEditor)

    beforeEach ->
      openFixture('sample.csv')

    afterEach ->
      temp.cleanup()

    it 'opens a csv editor for the file', ->
      expect(csvEditor instanceof CSVEditor).toBeTruthy()

    describe 'when the user choose to open a text editor', ->
      beforeEach ->
        openSpy = jasmine.createSpy('did-destroy')
        csvEditor.onDidDestroy(openSpy)

        textEditorButton = csvEditorElement.openTextEditorButton
        click(textEditorButton)

        waitsFor -> openSpy.callCount > 0

      it 'opens a new text editor for that file', ->
        expect(atom.workspace.getActiveTextEditor()).toBeDefined()

      it 'destroys the csv editor pane', ->
        expect(csvEditor.isDestroyed()).toBeTruthy()

      it 'destroys the csv editor pane item', ->
        expect(atom.workspace.getActivePane().getItems().length).toEqual(1)

    xdescribe 'when the file have been loaded', ->
      it 'has a table filled with the file content', ->
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
