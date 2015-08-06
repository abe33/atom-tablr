fs = require 'fs'
path = require 'path'
temp = require 'temp'

{TextEditor} = require 'atom'
TableEdit = require '../lib/table-edit'
TableEditor = require '../lib/table-editor'
CSVEditor = require '../lib/csv-editor'
TableElement = require '../lib/table-element'

{click} = require './helpers/events'

CHANGE_TIMEOUT = 400

describe "CSVEditor", ->
  [csvEditor, csvEditorElement, csvDest, projectPath, tableEditor, tableEditorElement, openSpy, destroySpy, savedContent, spy, tableEditPackage, nextAnimationFrame] = []

  beforeEach ->
    [csvEditor, csvEditorElement, csvDest, projectPath, tableEditor, tableEditorElement, openSpy, destroySpy, savedContent, spy] = []

    jasmineContent = document.body.querySelector('#jasmine-content')
    workspaceElement = atom.views.getView(atom.workspace)
    jasmineContent.appendChild(workspaceElement)

    noAnimationFrame = -> throw new Error('No animation frame requested')
    nextAnimationFrame = noAnimationFrame

    requestAnimationFrameSafe = window.requestAnimationFrame
    spyOn(window, 'requestAnimationFrame').andCallFake (fn) ->
      lastFn = fn
      nextAnimationFrame = ->
        nextAnimationFrame = noAnimationFrame
        fn()

    waitsForPromise -> atom.packages.activatePackage('table-edit').then (pkg) ->
      tableEditPackage = pkg.mainModule

  sleep = (ms) ->
    start = new Date
    -> new Date - start >= ms

  openFixture = (fixtureName, settings) ->
    csvFixture = path.join(__dirname, 'fixtures', fixtureName)

    projectPath = temp.mkdirSync('table-edit-project')
    csvDest = path.join(projectPath, fixtureName)

    if settings?
      tableEditPackage.storeOptionsForPath("/private#{csvDest}", settings)

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

  afterEach ->
    temp.cleanup()

  describe 'when a csv file is opened', ->
    it 'opens a csv editor for the file', ->
      openFixture('sample.csv')
      runs ->
        expect(csvEditor instanceof CSVEditor).toBeTruthy()

    describe 'when the user choose to open a text editor', ->
      beforeEach ->
        openFixture('sample.csv')

        runs ->
          destroySpy = jasmine.createSpy('did-destroy')
          csvEditor.onDidDestroy(destroySpy)

          textEditorButton = csvEditorElement.form.openTextEditorButton
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
        openFixture('sample.csv')

        runs ->
          csvEditorElement.querySelector('[id^="remember-choice"]').checked = true

          destroySpy = jasmine.createSpy('did-destroy')
          csvEditor.onDidDestroy(destroySpy)

        waitsFor sleep CHANGE_TIMEOUT

        runs ->
          textEditorButton = csvEditorElement.form.openTextEditorButton
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
          openFixture('sample.csv')

          runs ->
            csvEditor.onDidOpen ({editor}) ->
              tableEditor = editor

            tableEditorButton = csvEditorElement.form.openTableEditorButton
            click(tableEditorButton)

          waitsFor -> tableEditor?

        it 'has a table filled with the file content', ->
          expect(tableEditor.getScreenColumnCount()).toEqual(3)
          expect(tableEditor.getScreenRowCount()).toEqual(3)

        it 'places the focus on the table element', ->
          tableElement = atom.views.getView(tableEditor)
          expect(tableElement.hiddenInput.matches(':focus')).toBeTruthy()

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

        describe 'closing the tab with pending changes', ->
          beforeEach ->
            tableEditor.addRow ['Bill', 45, 'male']
            tableEditor.addRow ['Bonnie', 42, 'female']

            spyOn(atom, 'confirm').andReturn(0)

            expect(csvEditor.isModified()).toBeTruthy()

            atom.workspace.getActivePane().destroyItem(csvEditor)

          it 'prompts the user to save', ->
            expect(atom.confirm).toHaveBeenCalled()

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
        openFixture('invalid.csv')

        runs ->
          tableEditorButton = csvEditorElement.form.openTableEditorButton
          click(tableEditorButton)

        waitsFor -> csvEditorElement.querySelector('.alert')

      it 'displays the error in the csv preview', ->
        expect(csvEditorElement.querySelector('atom-csv-preview .alert')).toExist()

      it 'disables the open table action', ->
        waitsFor -> csvEditorElement.form.openTableEditorButton.disabled

    describe 'changing the delimiter settings', ->
      beforeEach ->
        openFixture('semi-colon.csv')

        runs ->
          csvEditorElement.querySelector('[id^="semi-colon"]').checked = true
          csvEditor.onDidOpen ({editor}) ->
            tableEditor = editor

        waitsFor sleep CHANGE_TIMEOUT

        runs ->
          tableEditorButton = csvEditorElement.form.openTableEditorButton
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
        openFixture('sample.csv')

        runs ->
          csvEditorElement.querySelector('[id^="header"]').checked = true
          csvEditor.onDidOpen ({editor}) ->
            tableEditor = editor

        waitsFor sleep CHANGE_TIMEOUT

        runs ->
          tableEditorButton = csvEditorElement.form.openTableEditorButton
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
        openFixture('custom-row-delimiter.csv')

        runs ->
          csvEditorElement.querySelector('atom-text-editor').getModel().setText('::')
          csvEditorElement.querySelector('[id^="custom-row-delimiter"]').checked = true
          csvEditor.onDidOpen ({editor}) ->
            tableEditor = editor

        waitsFor sleep CHANGE_TIMEOUT

        runs ->
          tableEditorButton = csvEditorElement.form.openTableEditorButton
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

    describe 'when there is options provided at the creation of the form', ->
      beforeEach ->
        openFixture 'custom-row-delimiter.csv', {
          delimiter: ';'
          rowDelimiter: '::'
          quote: "'"
          escape: "\\"
          header: true
          ltrim: true
          comment: '//'
          eof: true
          quoted: true
          skip_empty_lines: true
        }
        runs ->
          nextAnimationFrame()

      it 'initialize the forms with the corresponding values', ->
        expect(csvEditorElement.querySelector('[name="header"]:checked')).toExist()
        expect(csvEditorElement.querySelector('[name="eof"]:checked')).toExist()
        expect(csvEditorElement.querySelector('[name="quoted"]:checked')).toExist()
        expect(csvEditorElement.querySelector('[name="skip-empty-lines"]:checked')).toExist()

        expect(csvEditorElement.querySelector('[id^="semi-colon"]:checked')).toExist()
        expect(csvEditorElement.querySelector('[id^="custom-row-delimiter"]:checked')).toExist()
        expect(csvEditorElement.form.rowDelimiterTextEditor.getText()).toEqual('::')
        expect(csvEditorElement.querySelector('[id^="custom-comment"]:checked')).toExist()
        expect(csvEditorElement.form.commentTextEditor.getText()).toEqual('//')
        expect(csvEditorElement.querySelector('[id^="single-quote-quote"]:checked')).toExist()
        expect(csvEditorElement.querySelector('[id^="backslash-escape"]:checked')).toExist()
        expect(csvEditorElement.querySelector('[id^="left-trim"]:checked')).toExist()

  describe 'when the package is disabled', ->
    beforeEach ->
      spyOn(tableEditPackage, 'deactivate').andCallThrough()

      atom.packages.observeDisabledPackages()
      atom.packages.disablePackage('table-edit')

      waitsFor -> tableEditPackage.deactivate.callCount > 0

    it 'disposes the csv opener', ->
      editor = null
      waitsForPromise -> atom.workspace.open('sample.csv').then (e) ->
        editor = e

      runs ->
        expect(editor).toBeDefined()
        expect(editor instanceof TextEditor).toBeTruthy()
