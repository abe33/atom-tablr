require './helpers/spec-helper'

os = require 'os'
fs = require 'fs'
fsp = require 'fs-plus'
path = require 'path'
temp = require 'temp'

TableEdit = require '../lib/tablr'
TableEditor = require '../lib/table-editor'
CSVEditor = require '../lib/csv-editor'
TableElement = require '../lib/table-element'

{click} = require './helpers/events'

CHANGE_TIMEOUT = 400

describe "CSVEditor", ->
  [csvEditor, csvEditorElement, csvDest, projectPath, tableEditor, tableEditorElement, openSpy, destroySpy, savedContent, spy, tableEditPackage, nextAnimationFrame] = []

  sleep = (ms) ->
    start = new Date
    -> new Date - start >= ms

  openFixture = (fixtureName, settings, noCopy) ->
    csvFixture = path.join(__dirname, 'fixtures', fixtureName)

    if noCopy
      waitsForPromise ->
        atom.workspace.open(fixtureName).then (t) ->
          csvEditor = t
          csvEditorElement = atom.views.getView(csvEditor)

      runs ->
        expect(csvEditor.file).toBeDefined()

      return

    projectPath = temp.mkdirSync('tablr-project')
    atom.project.setPaths([projectPath])

    projectPath = atom.project.resolvePath('.')
    csvDest = path.join(projectPath, fixtureName)

    fs.writeFileSync(csvDest, fs.readFileSync(csvFixture))

    if settings?
      tableEditPackage.csvConfig.set(csvDest, 'options',  settings)

    waitsForPromise ->
      atom.workspace.open(fixtureName).then (t) ->
        csvEditor = t
        csvEditorElement = atom.views.getView(csvEditor)

    runs -> expect(csvEditor.file).toBeDefined()

  modifyAndSave = (block) ->
    waitsFor 'tablr editor attached to DOM', ->
      csvEditorElement.querySelector('tablr-editor')

    runs block

    runs ->
      expect(tableEditor.isModified()).toBeTruthy()
      expect(csvEditor.isModified()).toBeTruthy()

      spyOn(fs, 'writeFile').andCallFake (path, data, callback) ->
        savedContent = String(data)
        callback()

      tableEditor.save()

    waitsFor 'file written on disk', -> fs.writeFile.callCount > 0

  beforeEach ->
    [csvEditor, csvEditorElement, csvDest, projectPath, tableEditor, tableEditorElement, openSpy, destroySpy, savedContent, spy] = []

    atom.config.set('tablr.csvEditor.rowDelimiter', 'auto')
    atom.config.set('tablr.csvEditor.columnDelimiter', ',')
    atom.config.set('tablr.csvEditor.quote', '"')
    atom.config.set('tablr.csvEditor.escape', '"')
    atom.config.set('tablr.csvEditor.comment', '#')
    atom.config.set('tablr.csvEditor.quoted', false)
    atom.config.set('tablr.csvEditor.header', false)
    atom.config.set('tablr.csvEditor.eof', false)
    atom.config.set('tablr.csvEditor.skipEmptyLines', false)
    atom.config.set('tablr.csvEditor.trim', 'no')
    atom.config.set('tablr.csvEditor.encoding', 'UTF-8')
    atom.config.set('tablr.csvEditor.maximumRowsInPreview', 100)
    atom.config.set('tablr.csvEditor.tableCreationBatchSize', 1000)

    jasmineContent = document.body.querySelector('#jasmine-content')
    workspaceElement = atom.views.getView(atom.workspace)
    jasmineContent.appendChild(workspaceElement)

    stackedFrames = []
    noAnimationFrame = -> throw new Error('No animation frame requested')
    nextAnimationFrame = noAnimationFrame

    requestAnimationFrameSafe = window.requestAnimationFrame
    spyOn(window, 'requestAnimationFrame').andCallFake (fn) ->
      if stackedFrames.length is 0
        nextAnimationFrame = ->
          nextAnimationFrame = noAnimationFrame
          while stackedFrames.length
            fn = stackedFrames.shift()
            fn()

      stackedFrames.push(fn)

    waitsForPromise -> atom.packages.activatePackage('tablr').then (pkg) ->
      tableEditPackage = pkg.mainModule

  afterEach ->
    csvEditor?.destroy()
    temp.cleanup()

  describe 'when opening a file whose name contains CSV', ->
    it 'does not open a csv editor for the file', ->
      waitsForPromise ->
        atom.workspace.open('CSVExporter.coffee').then (t) -> csvEditor = t
      runs ->
        expect(csvEditor instanceof CSVEditor).toBeFalsy()

  describe 'when an empty csv file is opened', ->
    it 'opens a csv editor for the file', ->
      openFixture('empty.csv')
      runs ->
        expect(csvEditor instanceof CSVEditor).toBeTruthy()

    describe 'when the user choose to open a table editor', ->
      beforeEach ->
        openFixture('empty.csv')

        runs ->
          nextAnimationFrame()

          csvEditor.onDidOpen ({editor}) ->
            tableEditor = editor

          tableEditorButton = csvEditorElement.form.openTableEditorButton
          click(tableEditorButton)

        waitsFor 'table editor created', -> tableEditor?

      it 'has a table filled with the file content', ->
        expect(tableEditor.getScreenColumnCount()).toEqual(0)
        expect(tableEditor.getScreenRowCount()).toEqual(0)

  describe 'when a csv file is opened', ->
    it 'opens a csv editor for the file', ->
      openFixture('sample.csv')
      runs ->
        expect(csvEditor instanceof CSVEditor).toBeTruthy()

    it 'fills the form with the default values from the config', ->
      atom.config.set('tablr.csvEditor.columnDelimiter', '\\t')
      atom.config.set('tablr.csvEditor.rowDelimiter', '\\r')
      atom.config.set('tablr.csvEditor.quote', '\'')
      atom.config.set('tablr.csvEditor.escape', '\\')
      atom.config.set('tablr.csvEditor.comment', '$')
      atom.config.set('tablr.csvEditor.quoted', true)
      atom.config.set('tablr.csvEditor.header', true)
      atom.config.set('tablr.csvEditor.eof', true)
      atom.config.set('tablr.csvEditor.skipEmptyLines', true)
      atom.config.set('tablr.csvEditor.trim', 'left')
      atom.config.set('tablr.csvEditor.encoding', 'Western (ISO 8859-1)')

      openFixture('sample.csv')
      runs ->
        nextAnimationFrame()

        expect(csvEditorElement.querySelector('[id^="tab"]:checked')).toExist()
        expect(csvEditorElement.querySelector('[id^="char-return"]:checked')).toExist()
        expect(csvEditorElement.querySelector('[id^="custom-comment"]:checked')).toExist()
        expect(csvEditorElement.form.commentTextEditor.getText()).toEqual('$')
        expect(csvEditorElement.querySelector('[id^="single-quote-quote"]:checked')).toExist()
        expect(csvEditorElement.querySelector('[id^="backslash-escape"]:checked')).toExist()
        expect(csvEditorElement.querySelector('[id^="quoted"]:checked')).toExist()
        expect(csvEditorElement.querySelector('[id^="header"]:checked')).toExist()
        expect(csvEditorElement.querySelector('[id^="eof"]:checked')).toExist()
        expect(csvEditorElement.querySelector('[id^="skip-empty-lines"]:checked')).toExist()
        expect(csvEditorElement.querySelector('[id^="left-trim"]:checked')).toExist()
        expect(csvEditorElement.form.encodingSelect.value).toEqual('ISO 8859-1')

    describe '::copy', ->
      it 'returns a CSVEditor in a pending state', ->
        openFixture('sample.csv')
        runs ->
          copy = csvEditor.copy()

          expect(copy.getPath()).toEqual(csvEditor.getPath())

          copy.destroy()

    describe 'when the file is changed on disk', ->
      [changeSpy, changeSubscription] = []
      beforeEach ->
        jasmine.useRealClock?()
        openFixture('sample.csv')

        runs ->
          nextAnimationFrame()
          changeSpy = jasmine.createSpy('did-change')
          changeSubscription = csvEditor.file.onDidChange(changeSpy)

      afterEach ->
        changeSubscription?.dispose()

      describe 'and the user has still to make a choice', ->
        beforeEach ->
          spyOn(csvEditorElement, 'updatePreview')

          fsp.writeFileSync(csvDest, """
          foo,bar
          1,2
          """)

          waitsFor 'change callback called', -> changeSpy.callCount > 0

        it 'updates the preview', ->
          expect(csvEditorElement.updatePreview).toHaveBeenCalled()

      describe 'and the user has open a table', ->
        beforeEach ->
          csvEditor.onDidOpen ({editor}) ->
            tableEditor = editor

          tableEditorButton = csvEditorElement.form.openTableEditorButton
          click(tableEditorButton)

          waitsFor 'table editor created', -> tableEditor?

        describe 'and the new content can be parsed with the current settings', ->
          describe 'when the table is in an unmodified state', ->
            beforeEach ->

              runs ->
                fsp.writeFileSync(csvDest, """
                foo,bar
                1,2
                """)

              waitsFor 'change callback called', ->
                csvEditor.editor isnt tableEditor

            it 'replaces the table content with the new one', ->
              nextAnimationFrame()

              expect(csvEditor.editor).not.toBe(tableEditor)
              expect(csvEditorElement.tableElement.getModel()).toEqual(csvEditor.editor)

              expect(csvEditor.editor.getColumns()).toEqual([undefined, undefined])
              expect(csvEditor.editor.getRows()).toEqual([
                ['foo', 'bar']
                ['1', '2']
              ])

            describe 'making new changes', ->
              [modifiedSpy] = []

              beforeEach ->
                nextAnimationFrame()

                modifiedSpy = jasmine.createSpy('did-change-modified')

                csvEditor.onDidChangeModified(modifiedSpy)

              describe 'on the previous table', ->
                beforeEach ->
                  tableEditor.addRow ['Jack', 68, 'male']

                it 'does not dispatch a did-change-modified event', ->
                  expect(modifiedSpy).not.toHaveBeenCalled()

              describe 'on the new table', ->
                beforeEach ->
                  csvEditor.editor.addRow ['Jack', 68, 'male']

                it 'dispatches a did-change-modified event', ->
                  expect(modifiedSpy).toHaveBeenCalled()

          describe 'when the table is in a modified state', ->
            [conflictSpy] = []
            beforeEach ->
              conflictSpy = jasmine.createSpy('did-conflict')
              csvEditor.onDidConflict(conflictSpy)
              tableEditor.addRow()

              fsp.writeFileSync(csvDest, """
              foo,bar
              1,2
              """)

              waitsFor 'change callback called', -> changeSpy.callCount > 0
              waitsFor 'conflict callback called', -> conflictSpy.callCount > 0

            it 'leaves the table in a modified state', ->
              expect(csvEditor.editor).toBe(tableEditor)
              expect(csvEditor.isModified()).toBeTruthy()

        describe 'and the new content cannot be parsed with the current settings', ->
          describe 'when the table is in an unmodified state', ->
            beforeEach ->
              fsp.writeFileSync(csvDest, """
              "foo";"bar"
              "1";"2"
              """)

              waitsFor 'change callback called', -> changeSpy.callCount > 0
              waitsFor -> csvEditor.editor is undefined

            it 'replaces the table content with a form', ->
              expect(csvEditor.editor).toBeUndefined()
              expect(csvEditorElement.tableElement).toBeUndefined()
              expect(csvEditorElement.form).toBeDefined()

            describe 'and the csv setting is changed to a valid format', ->
              beforeEach ->
                nextAnimationFrame()

                tableEditor = null
                csvEditorElement.querySelector('[id^="semi-colon"]').checked = true

                csvEditor.onDidOpen ({editor}) ->
                  tableEditor = editor

                tableEditorButton = csvEditorElement.form.openTableEditorButton
                click(tableEditorButton)

                waitsFor 'table editor created', -> tableEditor?

              it 'now opens the new version of the file', ->
                expect(csvEditor.editor.getColumns()).toEqual([
                  undefined, undefined
                  ])
                expect(csvEditor.editor.getRows()).toEqual([
                  ['foo', 'bar']
                  ['1', '2']
                ])

    # File moves aren't detected on linux
    if os.platform() is 'darwin'
      describe 'when the file is moved', ->
        [spy, newPath, spyTitle] = []

        beforeEach ->
          jasmine.useRealClock?()

          openFixture('sample.csv', {})
          runs ->
            nextAnimationFrame()
            spy = jasmine.createSpy('did-change-path')
            spyTitle = jasmine.createSpy('did-change-title')
            csvEditor.onDidChangePath(spy)
            csvEditor.onDidChangeTitle(spyTitle)

            newPath = path.join(projectPath, 'new-file.csv')
            fsp.removeSync(newPath)
            fsp.moveSync(csvEditor.getPath(), newPath)

          waitsFor 'change path callback called', -> spy.callCount > 0

        it 'detects the change in path', ->
          expect(spy).toHaveBeenCalledWith(newPath)
          expect(csvEditor.getPath()).toEqual(newPath)

        it 'changes the key path to the settings', ->
          expect(tableEditPackage.csvConfig.get(csvDest)).toBeUndefined()
          expect(tableEditPackage.csvConfig.get(newPath)).toBeDefined()

        it 'dispatches a did-change-title event', ->
          expect(spyTitle).toHaveBeenCalledWith('new-file.csv')

    describe 'when the file is deleted', ->
      [deleteSpy] = []

      beforeEach ->
        jasmine.useRealClock?()

        openFixture('sample.csv', {})
        runs ->
          nextAnimationFrame()
          deleteSpy = jasmine.createSpy('delete')
          csvEditor.file.onDidDelete(deleteSpy)

          csvEditor.onDidOpen ({editor}) ->
            tableEditor = editor

          tableEditorButton = csvEditorElement.form.openTableEditorButton
          click(tableEditorButton)

        waitsFor 'table editor created', -> tableEditor?

      describe 'when the table is modified', ->
        beforeEach ->
          csvEditor.editor.addRow()

          fsp.removeSync(csvDest)
          waitsFor 'delete callback called', -> deleteSpy.callCount > 0

        it "retains its path and reports the buffer as modified", ->
          expect(csvEditor.getPath()).toBe(csvDest)
          expect(csvEditor.isModified()).toBeTruthy()

      describe 'when the table is not modified', ->
        beforeEach ->
          fsp.removeSync(csvDest)
          waitsFor 'delete callback called', -> deleteSpy.callCount > 0

        it "retains its path and reports the buffer as not modified", ->
          expect(csvEditor.getPath()).toBe(csvDest)
          expect(csvEditor.isModified()).toBeFalsy()

      describe 'when resaved', ->
        it 'recreates the file on disk', ->
          fsp.removeSync(csvDest)
          waitsFor 'delete callback called', -> deleteSpy.callCount > 0
          runs -> expect(fs.existsSync(csvDest)).toBeFalsy()
          waitsForPromise -> csvEditor.save()
          runs -> expect(fs.existsSync(csvDest)).toBeTruthy()

    describe 'when the user choose to open a text editor', ->
      beforeEach ->
        openFixture('sample.csv')

        runs ->
          nextAnimationFrame()

          destroySpy = jasmine.createSpy('did-destroy')
          csvEditor.onDidDestroy(destroySpy)

          textEditorButton = csvEditorElement.form.openTextEditorButton
          click(textEditorButton)

        waitsFor 'destroy callback called', -> destroySpy.callCount > 0

      it 'opens a new text editor for that file', ->
        expect(atom.workspace.getActiveTextEditor()).toBeDefined()

      it 'destroys the csv editor pane', ->
        expect(csvEditor.isDestroyed()).toBeTruthy()

      it 'destroys the csv editor pane item', ->
        expect(atom.workspace.getActivePane().getItems().length).toEqual(1)

      describe '::copy', ->
        it 'returns a CSVEditor in a pending state', ->
          copy = csvEditor.copy()

          expect(copy.choice).toEqual('TextEditor')

          copy.destroy()

    describe 'when the remember choice setting is enabled', ->
      beforeEach ->
        openFixture('sample.csv')

        runs ->
          nextAnimationFrame()

          csvEditorElement.querySelector('[id^="remember-choice"]').checked = true

          destroySpy = jasmine.createSpy('did-destroy')
          csvEditor.onDidDestroy(destroySpy)

        waitsFor "for #{CHANGE_TIMEOUT}ms", sleep CHANGE_TIMEOUT

        runs ->
          textEditorButton = csvEditorElement.form.openTextEditorButton
          click(textEditorButton)

        waitsFor 'destroy callback called', -> destroySpy.callCount > 0

        runs ->
          csvEditor.destroy()

        waitsForPromise ->
          atom.workspace.open(path.join(projectPath, 'sample.csv')).then (t) ->
            csvEditor = t
            csvEditorElement = atom.views.getView(csvEditor)

      it 'does not show the choice form again', ->
        expect(atom.workspace.getActiveTextEditor()).toBeDefined()

    describe 'when the user choose to open a table editor', ->
      describe 'with a escaped chars in column delimiter setting', ->
        beforeEach ->
          atom.config.set('tablr.csvEditor.columnDelimiter', '\\t')
          openFixture('tab-delimiter.csv')

          runs ->
            nextAnimationFrame()

            csvEditor.onDidOpen ({editor}) -> tableEditor = editor

            tableEditorButton = csvEditorElement.form.openTableEditorButton
            click(tableEditorButton)

          waitsFor 'table editor created', -> tableEditor?

        it 'properly unescape the delimiter value', ->
          expect(tableEditor.getScreenColumnCount()).toEqual(2)

      describe 'when the csv has inconsistent row length', ->
        describe 'due to an incomplete first row', ->
          beforeEach ->
            openFixture('incomplete-first-row.csv')

            runs ->
              nextAnimationFrame()

              csvEditor.onDidOpen ({editor}) ->
                tableEditor = editor

              tableEditorButton = csvEditorElement.form.openTableEditorButton
              click(tableEditorButton)

            waitsFor 'table editor created', -> tableEditor?

          it 'has a table filled with the file content', ->
            expect(tableEditor.getScreenColumnCount()).toEqual(5)
            expect(tableEditor.getScreenRowCount()).toEqual(2)

        describe 'due to an incomplete row later in the file', ->
          beforeEach ->
            openFixture('inconsistent-column-count.csv')

            runs ->
              nextAnimationFrame()

              csvEditor.onDidOpen ({editor}) ->
                tableEditor = editor

              tableEditorButton = csvEditorElement.form.openTableEditorButton
              click(tableEditorButton)

            waitsFor 'table editor created', -> tableEditor?

          it 'has a table filled with the file content', ->
            expect(tableEditor.getScreenColumnCount()).toEqual(6)
            expect(tableEditor.getScreenRowCount()).toEqual(108)

      describe 'with the default options', ->
        beforeEach ->
          openFixture('sample.csv')

          runs ->
            nextAnimationFrame()

            csvEditor.onDidOpen ({editor}) ->
              tableEditor = editor

            tableEditorButton = csvEditorElement.form.openTableEditorButton
            click(tableEditorButton)

          waitsFor 'table editor created', -> tableEditor?

        it 'has a table filled with the file content', ->
          expect(tableEditor.getScreenColumnCount()).toEqual(3)
          expect(tableEditor.getScreenRowCount()).toEqual(3)

        it 'places the focus on the table element', ->
          tableElement = atom.views.getView(tableEditor)

          expect(document.activeElement).toBe(tableElement.hiddenInput)

        it 'has an empty undo stack', ->
          expect(tableEditor.getTable().undoStack).toBeUndefined()

        it 'leaves the table in a unmodified state', ->
          expect(tableEditor.isModified()).toBeFalsy()

        it 'gives the focus to the table editor when it receive it', ->
          tableElement = atom.views.getView(tableEditor)
          spyOn(tableElement, 'focus')

          csvEditorElement.focus()

          expect(tableElement.focus).toHaveBeenCalled()

        it 'clears the csv editor content and replace it with a table element', ->
          waitsFor 'tablr editor attached to DOM', ->
            tableEditorElement = csvEditorElement.querySelector('tablr-editor')

          runs ->
            expect(tableEditorElement).toExist()
            expect(csvEditorElement.children.length).toEqual(1)

        describe '::saveAs', ->
          newPath = null
          beforeEach ->
            newPath = "#{projectPath}/other-sample.csv"

            waitsForPromise ->
              csvEditor.saveAs(newPath)

          it 'saves the csv at the specified path', ->
            expect(fs.existsSync(newPath)).toBeTruthy()

          it 'changes the csvEditor path', ->
            expect(csvEditor.getPath()).toEqual(newPath)

          it 'saves the layout and display settings at the new path', ->
            expect(tableEditPackage.csvConfig.get(newPath, 'layout')).toEqual({
              columns: [
                {}
                {}
                {}
              ]
              rowHeights: [
                undefined
                undefined
                undefined
              ]
            })

        describe '::copy', ->
          it 'returns a CSVEditor in a pending state', ->
            copy = csvEditor.copy()

            expect(copy.choice).toEqual('TableEditor')

            copy.destroy()

        describe 'when panes are split', ->
          [secondCSVEditor, secondCSVEditorElement] = []
          beforeEach ->
            newPane = atom.workspace.getActivePane().splitRight()
            expect(newPane).toBe(atom.workspace.getActivePane())

            waitsForPromise ->
              atom.workspace.open(path.join(projectPath, 'sample.csv')).then (t) ->
                secondCSVEditor = t
                secondCSVEditorElement = atom.views.getView(secondCSVEditor)

                nextAnimationFrame()

                tableEditorButton = secondCSVEditorElement.form.openTableEditorButton
                click(tableEditorButton)

            waitsFor 'second editor choice applied', ->
              secondCSVEditor.editor

          it 'reuses the same table for two different table editors', ->
            expect(csvEditor.editor.table).toBe(secondCSVEditor.editor.table)
            expect(csvEditor.editor.displayTable).toBe(secondCSVEditor.editor.displayTable)
            expect(csvEditor).not.toBe(secondCSVEditor)
            expect(csvEditorElement).not.toBe(secondCSVEditorElement)

          describe 'when all the editors have been closed', ->
            it 'releases the table', ->
              {table} = secondCSVEditor.editor
              secondCSVEditor.destroy()
              expect(table.isDestroyed()).toBeFalsy()

              csvEditor.destroy()
              expect(table.isDestroyed()).toBeTruthy()

            describe 'when a new table editor is opened', ->
              beforeEach ->
                secondCSVEditor.destroy()
                csvEditor.destroy()

                tableEditor = null
                csvEditor = null

                waitsForPromise ->
                  atom.workspace.open(path.join(projectPath, 'sample.csv')).then (t) ->
                    csvEditor = t
                    csvEditorElement = atom.views.getView(csvEditor)

                    nextAnimationFrame()

                    csvEditor.onDidOpen ({editor}) ->
                      tableEditor = editor

                    tableEditorButton = csvEditorElement.form.openTableEditorButton
                    click(tableEditorButton)

                waitsFor 'table editor created', -> tableEditor?

              it 'returns a living editor', ->
                expect(tableEditor.table.getColumnCount()).toEqual(3)
                expect(tableEditor.table.getRowCount()).toEqual(3)

        describe 'closing the tab with pending changes', ->
          beforeEach ->
            tableEditor.addRow ['Bill', 45, 'male']
            tableEditor.addRow ['Bonnie', 42, 'female']

            spyOn(atom.workspace.applicationDelegate, 'confirm').andReturn(0)

            expect(csvEditor.isModified()).toBeTruthy()

            atom.workspace.getActivePane().destroyItem(csvEditor)

          it 'prompts the user to save', ->
            expect(atom.workspace.applicationDelegate.confirm).toHaveBeenCalled()

        describe 'when the table is modified', ->
          beforeEach ->
            modifyAndSave ->
              tableEditor.addRow ['Bill', 45, 'male']
              tableEditor.addRow ['Bonnie', 42, 'female']

              tableEditor.getScreenColumn(0).width = 200
              tableEditor.getScreenColumn(0).align = 'right'
              tableEditor.getScreenColumn(1).width = 300
              tableEditor.getScreenColumn(2).align = 'center'
              tableEditor.setScreenRowHeightAt(1, 100)
              tableEditor.setScreenRowHeightAt(3, 200)

          describe 'when saved', ->
            it 'saves the new csv content on disk', ->
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

            it 'saves the layout and display settings', ->
              expect(tableEditPackage.csvConfig.get(csvEditor.getPath(), 'layout')).toEqual({
                columns: [
                  {width: 200, align: 'right'}
                  {width: 300}
                  {align: 'center'}
                ]
                rowHeights: [
                  undefined
                  100
                  undefined
                  200
                  undefined
                ]
              })

            describe 'making new changes', ->
              [modifiedSpy] = []

              beforeEach ->
                modifiedSpy = jasmine.createSpy('did-change-modified')

                csvEditor.onDidChangeModified(modifiedSpy)

                tableEditor.addRow ['Jack', 68, 'male']

              it 'dispatches a did-change-modified event', ->
                expect(modifiedSpy).toHaveBeenCalled()

      describe 'with a specific encoding', ->
        beforeEach ->
          openFixture('iso-8859-1.csv')

          runs ->
            nextAnimationFrame()

            csvEditor.onDidOpen ({editor}) -> tableEditor = editor

            encodingSelect = csvEditorElement.form.encodingSelect
            encodingSelect.value = 'ISO 8859-1'

        describe 'when the table editor is opened', ->
          beforeEach ->
            tableEditorButton = csvEditorElement.form.openTableEditorButton
            click(tableEditorButton)

            waitsFor 'table editor created', -> tableEditor?

          it 'uses the given encoding to fill the table', ->
            expect(tableEditor.table.getColumnValues(0)).toEqual([
              'name',
              'Cédric',
              'Émile'
            ])

          describe 'when save again', ->
            beforeEach ->
              modifyAndSave ->
                tableEditor.addRow ['Bill', 45, 'male']

            it 'honors the specified encoding', ->
              expect(savedContent).not.toEqual('''
              name,age,gender
              Cédric,34,male
              Émile,30,male
              Bill,45,male
              ''')

    describe 'when the file cannot be parsed with the default', ->
      beforeEach ->
        openFixture('invalid.csv')

        runs ->
          nextAnimationFrame()

      it 'displays the error in the csv preview', ->
        waitsFor 'csv alert displayed in the DOM', ->
          csvEditorElement.querySelector('atom-csv-preview .alert')

      it 'disables the open table action', ->
        waitsFor 'open button disabled', ->
          csvEditorElement.form.openTableEditorButton.disabled

    describe 'changing the delimiter settings', ->
      beforeEach ->
        openFixture('semi-colon.csv')

        runs ->
          nextAnimationFrame()

          csvEditorElement.querySelector('[id^="semi-colon"]').checked = true
          csvEditor.onDidOpen ({editor}) ->
            tableEditor = editor

        waitsFor "for #{CHANGE_TIMEOUT}ms", sleep CHANGE_TIMEOUT

        runs ->
          tableEditorButton = csvEditorElement.form.openTableEditorButton
          click(tableEditorButton)

        waitsFor 'table editor created', -> tableEditor?

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
          nextAnimationFrame()

          csvEditorElement.querySelector('[id^="header"]').checked = true
          csvEditor.onDidOpen ({editor}) ->
            tableEditor = editor

        waitsFor "for #{CHANGE_TIMEOUT}ms", sleep CHANGE_TIMEOUT

        runs ->
          tableEditorButton = csvEditorElement.form.openTableEditorButton
          click(tableEditorButton)

        waitsFor 'table editor created', -> tableEditor?

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
          nextAnimationFrame()

          csvEditorElement.querySelector('atom-text-editor').getModel().setText('::')
          csvEditorElement.querySelector('[id^="custom-row-delimiter"]').checked = true
          csvEditor.onDidOpen ({editor}) ->
            tableEditor = editor

        waitsFor "for #{CHANGE_TIMEOUT}ms", sleep CHANGE_TIMEOUT

        runs ->
          tableEditorButton = csvEditorElement.form.openTableEditorButton
          click(tableEditorButton)

        waitsFor 'table editor created', -> tableEditor?

      it 'now parses the table data properly', ->
        expect(tableEditor).toBeDefined()
        expect(tableEditor.getScreenColumnCount()).toEqual(2)
        expect(tableEditor.getScreenRowCount()).toEqual(2)

      describe 'when modified and saved', ->
        beforeEach ->
          modifyAndSave ->
            tableEditor.setValueAtPosition([1,1], "34\n")

            tableEditor.addRow ['GHI', 56]
            tableEditor.addRow ['JKL', 78]

        it 'save the new csv content on disk', ->
          expect(savedContent).toEqual("ABC,12::DEF,\"34\n\"::GHI,56::JKL,78")

        it 'marks the table editor as saved', ->
          expect(tableEditor.isModified()).toBeFalsy()
          expect(csvEditor.isModified()).toBeFalsy()

    describe 'when there is a previous layout saved for the file', ->
      beforeEach ->
        openFixture('sample.csv')
        runs ->
          nextAnimationFrame()
          tableEditPackage.csvConfig.set csvEditor.getPath(), 'layout', {
            columns: [
              {width: 200, align: 'right'}
              {width: 300}
              {align: 'center'}
            ]
            rowHeights: [
              undefined
              100
              200
            ]
          }

          csvEditor.onDidOpen ({editor}) -> tableEditor = editor

          tableEditorButton = csvEditorElement.form.openTableEditorButton
          click(tableEditorButton)

        waitsFor 'table editor created', -> tableEditor?

      it 'uses this layout to setup the display table', ->
        expect(tableEditor.getScreenRowHeightAt(1)).toEqual(100)
        expect(tableEditor.getScreenRowHeightAt(2)).toEqual(200)

        expect(tableEditor.getScreenColumnWidthAt(0)).toEqual(200)
        expect(tableEditor.getScreenColumnWidthAt(1)).toEqual(300)

        expect(tableEditor.getScreenColumn(0).align).toEqual('right')
        expect(tableEditor.getScreenColumn(2).align).toEqual('center')

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
      atom.packages.disablePackage('tablr')

      waitsFor "package deactivated", -> tableEditPackage.deactivate.callCount > 0

    it 'disposes the csv opener', ->
      editor = null
      waitsForPromise -> atom.workspace.open('sample.csv').then (e) ->
        editor = e

      runs ->
        expect(editor).toBeDefined()
        expect(editor.getText?).toBeTruthy()

  ##     ######  ##     ## ########
  ##    ##    ## ###   ### ##     ##
  ##    ##       #### #### ##     ##
  ##    ##       ## ### ## ##     ##
  ##    ##       ##     ## ##     ##
  ##    ##    ## ##     ## ##     ##
  ##     ######  ##     ## ########

  describe 'storage commands', ->
    beforeEach ->
      tableEditPackage.csvConfig.set '/some/path/to.csv', 'layout', {
        columns: [
          {width: 200, align: 'right'}
          {width: 300}
          {align: 'center'}
        ]
        rowHeights: [
          undefined
          100
          200
        ]
      }
      tableEditPackage.csvConfig.set '/some/path/to.csv', 'choice', 'TableEditor'

    describe 'tablr:clear-csv-storage', ->
      it 'removes the stored data', ->
        atom.commands.dispatch(atom.views.getView(atom.workspace), 'tablr:clear-csv-storage')

        expect(tableEditPackage.csvConfig.get '/some/path/to.csv').toBeUndefined()

    describe 'tablr:clear-csv-choice', ->
      it 'removes only the stored choice', ->
        atom.commands.dispatch(atom.views.getView(atom.workspace), 'tablr:clear-csv-choice')

        expect(tableEditPackage.csvConfig.get '/some/path/to.csv').not.toBeUndefined()
        expect(tableEditPackage.csvConfig.get '/some/path/to.csv', 'layout').not.toBeUndefined()
        expect(tableEditPackage.csvConfig.get '/some/path/to.csv', 'choice').toBeUndefined()

    describe 'tablr:clear-csv-layout', ->
      it 'removes only the stored choice', ->
        atom.commands.dispatch(atom.views.getView(atom.workspace), 'tablr:clear-csv-layout')

        expect(tableEditPackage.csvConfig.get '/some/path/to.csv').not.toBeUndefined()
        expect(tableEditPackage.csvConfig.get '/some/path/to.csv', 'layout').toBeUndefined()
        expect(tableEditPackage.csvConfig.get '/some/path/to.csv', 'choice').not.toBeUndefined()

  ##    ########  ########  ######  ########  #######  ########  ########
  ##    ##     ## ##       ##    ##    ##    ##     ## ##     ## ##
  ##    ##     ## ##       ##          ##    ##     ## ##     ## ##
  ##    ########  ######    ######     ##    ##     ## ########  ######
  ##    ##   ##   ##             ##    ##    ##     ## ##   ##   ##
  ##    ##    ##  ##       ##    ##    ##    ##     ## ##    ##  ##
  ##    ##     ## ########  ######     ##     #######  ##     ## ########

  describe '::serialize', ->
    it 'serializes the csv editor', ->
      openFixture('sample.csv')
      runs ->
        nextAnimationFrame()

        expect(csvEditor.serialize()).toEqual({
          deserializer: 'CSVEditor'
          filePath: csvDest
          options: csvEditor.options
          choice: undefined
        })

    describe 'when the editor has a choice', ->
      it 'serializes the user choice', ->
        openFixture('sample.csv')
        runs -> nextAnimationFrame()
        waitsForPromise -> csvEditor.openTableEditor()
        runs ->
          expect(csvEditor.serialize()).toEqual({
            deserializer: 'CSVEditor'
            filePath: csvDest
            options: csvEditor.options
            choice: 'TableEditor'
            layout:
              columns: [{},{},{}]
              rowHeights: [undefined, undefined, undefined]
          })

    describe 'when the table editor has a layout', ->
      it 'serializes the layout', ->
        openFixture('sample.csv')
        runs -> nextAnimationFrame()
        waitsForPromise -> csvEditor.openTableEditor()
        runs ->
          {editor: tableEditor} = csvEditor

          tableEditor.getScreenColumn(0).width = 200
          tableEditor.getScreenColumn(0).align = 'right'
          tableEditor.getScreenColumn(1).width = 300
          tableEditor.getScreenColumn(2).align = 'center'
          tableEditor.setScreenRowHeightAt(1, 100)
          tableEditor.setScreenRowHeightAt(2, 200)
          csvEditor.saveLayout()

          expect(csvEditor.serialize()).toEqual({
            deserializer: 'CSVEditor'
            filePath: csvDest
            options: csvEditor.options
            choice: 'TableEditor'
            layout:
              columns: [
                {width: 200, align: 'right'}
                {width: 300}
                {align: 'center'}
              ]
              rowHeights: [
                undefined
                100
                200
              ]
          })

    describe 'that has unsaved changes', ->
      it 'serializes the table editor and its children', ->
        openFixture('sample.csv')
        runs -> nextAnimationFrame()
        waitsForPromise -> csvEditor.openTableEditor()
        runs ->
          csvEditor.editor.addRow()

          expect(csvEditor.serialize()).toEqual({
            deserializer: 'CSVEditor'
            filePath: csvDest
            options: csvEditor.options
            choice: 'TableEditor'
            editor: csvEditor.editor.serialize()
          })

  describe '.deserialize', ->
    it 'restores a CSVEditor using the provided state', ->
      csvEditor = atom.deserializers.deserialize({
        deserializer: 'CSVEditor'
        filePath: "#{atom.project.getPaths()[0]}/sample.csv"
        options: {}
        choice: undefined
      })

      expect(csvEditor).toBeDefined()

    describe 'with a state corresponding to a table choice', ->
      it 'applies the choice on creation', ->
        spyOn(CSVEditor.prototype, 'applyChoice')
        csvEditor = atom.deserializers.deserialize({
          deserializer: 'CSVEditor'
          filePath: "#{atom.project.getPaths()[0]}/sample.csv"
          options: {}
          choice: 'TableEditor'
        })

        expect(csvEditor).toBeDefined()
        expect(CSVEditor::applyChoice).toHaveBeenCalled()

      describe 'that has a layout defined', ->
        it 'applies the restored layout', ->
          csvEditor = atom.deserializers.deserialize({
            deserializer: 'CSVEditor'
            filePath: "#{atom.project.getPaths()[0]}/sample.csv"
            options: {}
            choice: 'TableEditor'
            layout:
              columns: [
                {width: 200, align: 'right'}
                {width: 300}
                {align: 'center'}
              ]
              rowHeights: [
                undefined
                100
                200
              ]
          })

          waitsFor 'table editor restored', -> tableEditor = csvEditor.editor
          runs ->
            expect(tableEditor.getScreenRowHeightAt(1)).toEqual(100)
            expect(tableEditor.getScreenRowHeightAt(2)).toEqual(200)

            expect(tableEditor.getScreenColumnWidthAt(0)).toEqual(200)
            expect(tableEditor.getScreenColumnWidthAt(1)).toEqual(300)

            expect(tableEditor.getScreenColumn(0).align).toEqual('right')
            expect(tableEditor.getScreenColumn(2).align).toEqual('center')

      describe 'that has an editor with unsaved changes', ->
        it 'applies the modified state', ->
          restored = atom.deserializers.deserialize({
            deserializer: "CSVEditor"
            filePath:"/path/to/file/sample.csv"
            options: {}
            choice: "TableEditor"
            editor:
              deserializer: 'TableEditor'
              displayTable:
                deserializer: 'DisplayTable'
                rowHeights: [null,null,null,null]
                table:
                  deserializer: 'Table'
                  modified: true
                  cachedContents: undefined
                  columns: [null,null,null]
                  rows: [
                    ["name","age","gender"]
                    ["Jane","32","female"]
                    ["John","30","male"]
                    [null,null,null]
                  ]
                  id: 1

              cursors: [[0,0]]
              selections: [[[0,0],[1,1]]]
          })

          waitsFor 'table editor restored', -> tableEditor = restored.editor
          runs ->
            expect(restored.isModified()).toBeTruthy()
            expect(restored.editor.getColumns()).toEqual([null, null, null])
            expect(restored.editor.getRows()).toEqual([
              ["name","age","gender"]
              ["Jane","32","female"]
              ["John","30","male"]
              [null,null,null]
            ])
