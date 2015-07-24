fs = require 'fs'
path = require 'path'
temp = require 'temp'

TableEdit = require '../lib/table-edit'
TableEditor = require '../lib/table-editor'
CSVEditor = require '../lib/csv-editor'
TableElement = require '../lib/table-element'

{click} = require './helpers/events'

fdescribe "CSVEditor", ->
  [csvEditor, csvEditorElement] = []

  beforeEach ->
    waitsForPromise -> atom.packages.activatePackage('table-edit')

  describe 'when a csv file is opened', ->
    [csvDest, projectPath, openSpy] = []

    openFixture = (fixtureName) ->
      csvFixture = path.join(__dirname, 'fixtures', fixtureName)

      projectPath = temp.mkdirSync('table-edit-project')
      csvDest = path.join(projectPath, fixtureName)
      fs.writeFileSync(csvDest, fs.readFileSync(csvFixture))

      atom.project.setPaths([projectPath])

      waitsForPromise -> atom.workspace.open(fixtureName).then (t) ->
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

    describe 'when the user choose to open a table editor', ->
      describe 'with the default options', ->
        [tableEditor, tableEditorElement] = []

        beforeEach ->
          csvEditor.onDidOpen (editor) ->
            tableEditor = editor

          tableEditorButton = csvEditorElement.openTableEditorButton
          click(tableEditorButton)

          waitsFor -> tableEditor?

        it 'has a table filled with the file content', ->
          expect(tableEditor.getScreenColumnCount()).toEqual(3)
          expect(tableEditor.getScreenRowCount()).toEqual(3)

        it 'clears the table undo stack', ->
          expect(tableEditor.getTable().undoStack.length).toEqual(0)

        it 'leaves the table in a unmodified state', ->
          expect(tableEditor.isModified()).toBeFalsy()

        xdescribe 'when the table is modified', ->
          beforeEach ->
            tableEditor.addRow ['Bill', 45, 'male']
            tableEditor.addRow ['Bonnie', 42, 'female']

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
