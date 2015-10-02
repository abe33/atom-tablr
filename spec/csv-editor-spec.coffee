fs = require 'fs'
fsp = require 'fs-plus'
path = require 'path'
temp = require 'temp'

{TextEditor} = require 'atom'
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

  openFixture = (fixtureName, settings) ->
    csvFixture = path.join(__dirname, 'fixtures', fixtureName)

    projectPath = temp.mkdirSync('tablr-project')
    atom.project.setPaths([projectPath])

    projectPath = atom.project.resolvePath('.')
    csvDest = path.join(projectPath, fixtureName)

    fs.writeFileSync(csvDest, fs.readFileSync(csvFixture).toString().replace(/\s+$/g,''))

    if settings?
      tableEditPackage.csvConfig.set(csvDest, 'options',  settings)

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

    waitsForPromise -> atom.packages.activatePackage('tablr').then (pkg) ->
      tableEditPackage = pkg.mainModule

  afterEach ->
    csvEditor?.destroy()
    temp.cleanup()

  describe 'when a csv file is opened', ->
    it 'opens a csv editor for the file', ->
      openFixture('sample.csv')
      runs ->
        expect(csvEditor instanceof CSVEditor).toBeTruthy()

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

          waitsFor -> changeSpy.callCount > 0

        it 'updates the preview', ->
          expect(csvEditorElement.updatePreview).toHaveBeenCalled()

      describe 'and the user has open a table', ->
        beforeEach ->
          csvEditor.onDidOpen ({editor}) ->
            tableEditor = editor

          tableEditorButton = csvEditorElement.form.openTableEditorButton
          click(tableEditorButton)

          waitsFor -> tableEditor?

        describe 'and the new content can be parsed with the current settings', ->
          describe 'when the table is in an unmodified state', ->
            beforeEach ->
              fsp.writeFileSync(csvDest, """
              foo,bar
              1,2
              """)

              waitsFor -> changeSpy.callCount > 1

            it 'replaces the table content with the new one', ->
              nextAnimationFrame()

              expect(csvEditor.editor).not.toBe(tableEditor)
              expect(csvEditorElement.tableElement.getModel()).toEqual(csvEditor.editor)

              expect(csvEditor.editor.getColumns()).toEqual([undefined, undefined])
              expect(csvEditor.editor.getRows()).toEqual([
                ['foo', 'bar']
                ['1', '2']
              ])

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

              waitsFor -> changeSpy.callCount > 1
              waitsFor -> conflictSpy.callCount > 0

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

              waitsFor -> changeSpy.callCount > 1
              waitsFor -> csvEditor.editor is undefined

            it 'replaces the table content with a form', ->
              expect(csvEditor.editor).toBeUndefined()
              expect(csvEditorElement.tableElement).toBeUndefined()
              expect(csvEditorElement.form).toBeDefined()

            describe 'and the csv setting is changed to a valid format', ->
              beforeEach ->
                tableEditor = null
                csvEditorElement.querySelector('[id^="semi-colon"]').checked = true

                csvEditor.onDidOpen ({editor}) ->
                  tableEditor = editor

                tableEditorButton = csvEditorElement.form.openTableEditorButton
                click(tableEditorButton)

                waitsFor -> tableEditor?

              it 'now opens the new version of the file', ->
                expect(csvEditor.editor.getColumns()).toEqual([undefined, undefined])
                expect(csvEditor.editor.getRows()).toEqual([
                  ['foo', 'bar']
                  ['1', '2']
                ])

    describe 'when the file is moved', ->
      [spy, newPath, spyTitle] = []

      beforeEach ->
        jasmine.useRealClock?()

        openFixture('sample.csv', {})
        runs ->
          spy = jasmine.createSpy('did-change-path')
          spyTitle = jasmine.createSpy('did-change-title')
          csvEditor.onDidChangePath(spy)
          csvEditor.onDidChangeTitle(spyTitle)

          newPath = path.join(projectPath, 'new-file.csv')
          fsp.removeSync(newPath)
          fsp.moveSync(csvEditor.getPath(), newPath)

        waitsFor -> spy.callCount > 0

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
          deleteSpy = jasmine.createSpy('delete')
          csvEditor.file.onDidDelete(deleteSpy)

          csvEditor.onDidOpen ({editor}) ->
            tableEditor = editor

          tableEditorButton = csvEditorElement.form.openTableEditorButton
          click(tableEditorButton)

        waitsFor -> tableEditor?

      describe 'when the table is modified', ->
        beforeEach ->
          csvEditor.editor.addRow()

          fsp.removeSync(csvDest)
          waitsFor -> deleteSpy.callCount > 0

        it "retains its path and reports the buffer as modified", ->
          expect(csvEditor.getPath()).toBe(csvDest)
          expect(csvEditor.isModified()).toBeTruthy()

      describe 'when the table is not modified', ->
        beforeEach ->
          fsp.removeSync(csvDest)
          waitsFor -> deleteSpy.callCount > 0

        it "retains its path and reports the buffer as not modified", ->
          expect(csvEditor.getPath()).toBe(csvDest)
          expect(csvEditor.isModified()).toBeFalsy()

      describe 'when resaved', ->
        it 'recreates the file on disk', ->
          fsp.removeSync(csvDest)
          waitsFor -> deleteSpy.callCount > 0
          runs -> expect(fs.existsSync(csvDest)).toBeFalsy()
          waitsForPromise -> csvEditor.save()
          runs -> expect(fs.existsSync(csvDest)).toBeTruthy()

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

      describe '::copy', ->
        it 'returns a CSVEditor in a pending state', ->
          copy = csvEditor.copy()

          expect(copy.choice).toEqual('TextEditor')

          copy.destroy()

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
          atom.workspace.open(path.join(projectPath, 'sample.csv')).then (t) ->
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

        it 'gives the focus to the table editor when it receive it', ->
          tableElement = atom.views.getView(tableEditor)
          spyOn(tableElement, 'focus')

          csvEditorElement.focus()

          expect(tableElement.focus).toHaveBeenCalled()

        it 'clears the csv editor content and replace it with a table element', ->
          waitsFor ->
            tableEditorElement = csvEditorElement.querySelector('atom-table-editor')

          runs ->
            expect(tableEditorElement).toExist()
            expect(csvEditorElement.children.length).toEqual(1)

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

                tableEditorButton = secondCSVEditorElement.form.openTableEditorButton
                click(tableEditorButton)

            waitsFor ->
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

                    csvEditor.onDidOpen ({editor}) ->
                      tableEditor = editor

                    tableEditorButton = csvEditorElement.form.openTableEditorButton
                    click(tableEditorButton)

                waitsFor -> tableEditor?

              it 'returns a living editor', ->
                expect(tableEditor.table.getColumnCount()).toEqual(3)
                expect(tableEditor.table.getRowCount()).toEqual(3)

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

    describe 'when the file cannot be parsed with the default', ->
      beforeEach ->
        openFixture('invalid.csv')

        runs ->
          tableEditorButton = csvEditorElement.form.openTableEditorButton
          click(tableEditorButton)

      it 'displays the error in the csv preview', ->
        waitsFor -> csvEditorElement.querySelector('atom-csv-preview .alert')

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

        waitsFor -> tableEditor?

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

      waitsFor -> tableEditPackage.deactivate.callCount > 0

    it 'disposes the csv opener', ->
      editor = null
      waitsForPromise -> atom.workspace.open('sample.csv').then (e) ->
        editor = e

      runs ->
        expect(editor).toBeDefined()
        expect(editor instanceof TextEditor).toBeTruthy()

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
        expect(csvEditor.serialize()).toEqual({
          deserializer: 'CSVEditor'
          filePath: csvDest
          options: csvEditor.options
          choice: undefined
        })

    describe 'when the editor has a choice', ->
      it 'serializes the user choice', ->
        openFixture('sample.csv')
        waitsForPromise -> csvEditor.openTableEditor()
        runs ->
          expect(csvEditor.serialize()).toEqual({
            deserializer: 'CSVEditor'
            filePath: csvDest
            options: csvEditor.options
            choice: 'TableEditor'
          })

    describe 'when the table editor has a layout', ->
      it 'serializes the layout', ->
        openFixture('sample.csv')
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

          waitsFor -> tableEditor = csvEditor.editor
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

          waitsFor -> tableEditor = restored.editor
          runs ->
            expect(restored.isModified()).toBeTruthy()
            expect(restored.editor.getColumns()).toEqual([null, null, null])
            expect(restored.editor.getRows()).toEqual([
              ["name","age","gender"]
              ["Jane","32","female"]
              ["John","30","male"]
              [null,null,null]
            ])
