fs = require 'fs'
path = require 'path'
temp = require 'temp'

TableEdit = require '../lib/table-edit'
TableEditor = require '../lib/table-editor'
CSVEditor = require '../lib/csv-editor'
TableElement = require '../lib/table-element'

{click} = require './helpers/events'

WRITE_TIMEOUT = 400

describe "CSVEditor", ->
  [csvEditor, csvEditorElement] = []

  beforeEach ->
    jasmineContent = document.body.querySelector('#jasmine-content')
    workspaceElement = atom.views.getView(atom.workspace)
    jasmineContent.appendChild(workspaceElement)

    waitsForPromise -> atom.packages.activatePackage('table-edit')

  describe 'when a csv file is opened', ->
    [csvDest, projectPath, tableEditor, tableEditorElement, openSpy, destroySpy, savedContent, spy] = []

    sleep = (ms) ->
      start = new Date
      -> new Date - start >= ms

    openFixture = (fixtureName) ->
      csvFixture = path.join(__dirname, 'fixtures', fixtureName)

      projectPath = temp.mkdirSync('table-edit-project')
      csvDest = path.join(projectPath, fixtureName)
      fs.writeFileSync(csvDest, fs.readFileSync(csvFixture).toString().replace(/\s+$/g,''))

      atom.project.setPaths([projectPath])

      waitsForPromise ->
        atom.workspace.open(fixtureName).then (t) ->
          csvEditor = t
          csvEditorElement = atom.views.getView(csvEditor)

    modifyAndSave = (block) ->
      waitsFor ->
        csvEditorElement.querySelector('atom-table-editor')

      runs block

      runs ->
        expect(tableEditor.isModified()).toBeTruthy()
        expect(csvEditor.isModified()).toBeTruthy()

        spyOn(fs, 'writeFile').andCallFake (path, data, callback) ->
          savedContent = data
          callback()

        tableEditor.save()

      waitsFor -> fs.writeFile.callCount > 0

    beforeEach ->
      openFixture('sample.csv')

    afterEach ->
      temp.cleanup()

    it 'opens a csv editor for the file', ->
      expect(csvEditor instanceof CSVEditor).toBeTruthy()

    describe 'when the user choose to open a text editor', ->
      beforeEach ->
        destroySpy = jasmine.createSpy('did-destroy')
        csvEditor.onDidDestroy(destroySpy)

        textEditorButton = csvEditorElement.openTextEditorButton
        click(textEditorButton)

        waitsFor ->
          destroySpy.callCount > 0

      it 'opens a new text editor for that file', ->
        expect(atom.workspace.getActiveTextEditor()).toBeDefined()

      it 'destroys the csv editor pane', ->
        expect(csvEditor.isDestroyed()).toBeTruthy()

      it 'destroys the csv editor pane item', ->
        expect(atom.workspace.getActivePane().getItems().length).toEqual(1)

      describe 'when the remember choice setting is enabled', ->
        beforeEach ->
          csvEditor.destroy()

          openFixture('sample.csv')

          runs ->
            csvEditorElement.querySelector('#remember-choice').checked = true

            destroySpy = jasmine.createSpy('did-destroy')
            csvEditor.onDidDestroy(destroySpy)

            textEditorButton = csvEditorElement.openTextEditorButton
            click(textEditorButton)

          waitsFor -> destroySpy.callCount > 0

          runs ->
            csvEditor.destroy()

          waitsForPromise ->
            atom.workspace.open(path.join(projectPath, 'sample.json')).then (t) ->
              csvEditor = t
              csvEditorElement = atom.views.getView(csvEditor)

        it 'does not show the choice form again', ->
          expect(atom.workspace.getActiveTextEditor()).toBeDefined()

    describe 'when the user choose to open a table editor', ->
      describe 'with the default options', ->
        beforeEach ->
          csvEditor.onDidOpen ({editor}) ->
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

        it 'clears the csv editor content and replace it with a table element', ->
          waitsFor ->
            tableEditorElement = csvEditorElement.querySelector('atom-table-editor')

          runs ->
            expect(tableEditorElement).toExist()
            expect(csvEditorElement.children.length).toEqual(1)

        describe 'when the table is modified', ->
          beforeEach ->
            modifyAndSave ->
              tableEditor.addRow ['Bill', 45, 'male']
              tableEditor.addRow ['Bonnie', 42, 'female']

          describe 'when saved', ->
            it 'save the new csv content on disk', ->
              expect(savedContent).toEqual("""
              name,age,gender
              Jane,32,female
              John,30,male
              Bill,45,male
              Bonnie,42,female
              """)

            it 'marks the table editor as saved', ->
              expect(tableEditor.isModified()).toBeFalsy()
              expect(csvEditor.isModified()).toBeFalsy()

        describe 'when the file cannot be parsed with the default', ->
          beforeEach ->
            tableEditor = tableEditorElement = null
            openFixture('invalid.csv')

            runs ->
              tableEditorButton = csvEditorElement.openTableEditorButton
              click(tableEditorButton)

            waitsFor -> csvEditorElement.querySelector('.alert')

          it 'displays the error in the settings form', ->
            expect(csvEditorElement.querySelector('.alert')).toExist()

          describe 'clicking again on the open button', ->
            it 'clears the previously created alert', ->
              tableEditorButton = csvEditorElement.openTableEditorButton
              click(tableEditorButton)

              expect(csvEditorElement.querySelector('.alert')).not.toExist()

        describe 'changing the delimiter settings', ->
          beforeEach ->
            tableEditor = tableEditorElement = null
            openFixture('semi-colon.csv')

            runs ->
              csvEditorElement.querySelector('#semi-colon').checked = true
              csvEditor.onDidOpen ({editor}) ->
                tableEditor = editor

              tableEditorButton = csvEditorElement.openTableEditorButton
              click(tableEditorButton)

            waitsFor -> tableEditor?

          it 'now parses the table data properly', ->
            expect(tableEditor).toBeDefined()

          describe 'when modified and saved', ->
            beforeEach ->
              modifyAndSave ->
                tableEditor.addRow ['Bill', 45, 'male']
                tableEditor.addRow ['Bonnie', 42, 'female']

            it 'save the new csv content on disk', ->
              expect(savedContent).toEqual("""
              name;age;gender
              Jane;32;female
              John;30;male
              Bill;45;male
              Bonnie;42;female
              """)

            it 'marks the table editor as saved', ->
              expect(tableEditor.isModified()).toBeFalsy()
              expect(csvEditor.isModified()).toBeFalsy()

        describe 'changing the header settings', ->
          beforeEach ->
            tableEditor = tableEditorElement = null
            openFixture('sample.csv')

            runs ->
              csvEditorElement.querySelector('#header').checked = true
              csvEditor.onDidOpen ({editor}) ->
                tableEditor = editor

              tableEditorButton = csvEditorElement.openTableEditorButton
              click(tableEditorButton)

            waitsFor -> tableEditor?

          it 'now parses the table data properly', ->
            expect(tableEditor).toBeDefined()
            expect(tableEditor.getScreenColumnCount()).toEqual(3)
            expect(tableEditor.getColumns()).toEqual(['name', 'age', 'gender'])
            expect(tableEditor.getScreenRowCount()).toEqual(2)

          describe 'when modified and saved', ->
            beforeEach ->
              modifyAndSave ->
                tableEditor.addRow ['Bill', 45, 'male']
                tableEditor.addRow ['Bonnie', 42, 'female']

            it 'save the new csv content on disk', ->
              expect(savedContent).toEqual("""
              name,age,gender
              Jane,32,female
              John,30,male
              Bill,45,male
              Bonnie,42,female
              """)

            it 'marks the table editor as saved', ->
              expect(tableEditor.isModified()).toBeFalsy()
              expect(csvEditor.isModified()).toBeFalsy()

        describe 'changing the row delimiter settings', ->
          beforeEach ->
            tableEditor = tableEditorElement = null
            openFixture('custom-row-delimiter.csv')

            runs ->
              csvEditorElement.querySelector('atom-text-editor').getModel().setText('::')
              csvEditorElement.querySelector('#custom-row-delimiter').checked = true
              csvEditor.onDidOpen ({editor}) ->
                tableEditor = editor

              tableEditorButton = csvEditorElement.openTableEditorButton
              click(tableEditorButton)

            waitsFor -> tableEditor?

          it 'now parses the table data properly', ->
            expect(tableEditor).toBeDefined()
            expect(tableEditor.getScreenColumnCount()).toEqual(2)
            expect(tableEditor.getScreenRowCount()).toEqual(2)

          describe 'when modified and saved', ->
            beforeEach ->
              modifyAndSave ->
                tableEditor.addRow ['GHI', 56]
                tableEditor.addRow ['JKL', 78]

            it 'save the new csv content on disk', ->
              expect(savedContent).toEqual("ABC,12::DEF,34::GHI,56::JKL,78")

            it 'marks the table editor as saved', ->
              expect(tableEditor.isModified()).toBeFalsy()
              expect(csvEditor.isModified()).toBeFalsy()
