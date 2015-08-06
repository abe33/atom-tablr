TableEditor = require '../lib/table-editor'
Table = require '../lib/table'

describe 'TableEditor', ->
  [table, displayTable, tableEditor] = []

  beforeEach ->
    atom.config.set 'table-edit.columnWidth', 100
    atom.config.set 'table-edit.minimuColumnWidth', 10
    atom.config.set 'table-edit.rowHeight', 20
    atom.config.set 'table-edit.minimumRowHeight', 10

  describe 'when initialized without a table', ->
    beforeEach ->
      tableEditor = new TableEditor
      {table, displayTable} = tableEditor

    it 'creates an empty table and its displayTable', ->
      expect(table).toBeDefined()
      expect(displayTable).toBeDefined()

    it 'has a default empty selection', ->
      expect(tableEditor.getLastSelection()).toBeDefined()
      expect(tableEditor.getSelections()).toEqual([tableEditor.getLastSelection()])
      expect(tableEditor.getLastSelection().getRange()).toEqual([[0,0],[0,0]])
      expect(tableEditor.getLastSelection().getCursor()).toEqual(tableEditor.getLastCursor())

    it 'has a default cursor position', ->
      expect(tableEditor.getCursorPosition()).toEqual([0,0])
      expect(tableEditor.getCursorPositions()).toEqual([[0,0]])

      expect(tableEditor.getCursorScreenPosition()).toEqual([0,0])
      expect(tableEditor.getCursorScreenPositions()).toEqual([[0,0]])

    it 'returns undefined when asked for the value at cursor', ->
      expect(tableEditor.getCursorValue()).toBeUndefined()
      expect(tableEditor.getCursorValues()).toEqual([undefined])

  describe 'when initialized with a table', ->
    beforeEach ->
      table = new Table

      table.addColumn 'key'
      table.addColumn 'value'

      table.addRow ['name', 'Jane Doe']
      table.addRow ['age', 30]
      table.addRow ['gender', 'female']

      tableEditor = new TableEditor({table})
      {displayTable} = tableEditor

      displayTable.sortBy('key')

    it 'uses the passed-in table', ->
      expect(displayTable).toBeDefined()
      expect(displayTable.table).toBe(table)
      expect(tableEditor.table).toBe(table)

    it 'has a default empty selection', ->
      expect(tableEditor.getLastSelection()).toBeDefined()
      expect(tableEditor.getSelections()).toEqual([tableEditor.getLastSelection()])
      expect(tableEditor.getLastSelection().getRange()).toEqual([[0,0],[1,1]])
      expect(tableEditor.getLastSelection().getCursor()).toEqual(tableEditor.getLastCursor())

    it 'has a default cursor position', ->
      expect(tableEditor.getCursorPosition()).toEqual([1,0])
      expect(tableEditor.getCursorPositions()).toEqual([[1,0]])

      expect(tableEditor.getCursorScreenPosition()).toEqual([0,0])
      expect(tableEditor.getCursorScreenPositions()).toEqual([[0,0]])

    it 'returns undefined when asked for the value at cursor', ->
      expect(tableEditor.getCursorValue()).toEqual('age')
      expect(tableEditor.getCursorValues()).toEqual(['age'])

    describe 'when destroyed', ->
      beforeEach ->
        tableEditor.destroy()

      it 'destroys its table and display table', ->
        expect(table.isDestroyed()).toBeTruthy()
        expect(displayTable.isDestroyed()).toBeTruthy()

      it 'is destroyed', ->
        expect(tableEditor.isDestroyed()).toBeTruthy()

      it 'removes its cursors and selections', ->
        expect(tableEditor.getCursors().length).toEqual(0)
        expect(tableEditor.getSelections().length).toEqual(0)

    ##     ######  ##     ## ########   ######   #######  ########   ######
    ##    ##    ## ##     ## ##     ## ##    ## ##     ## ##     ## ##    ##
    ##    ##       ##     ## ##     ## ##       ##     ## ##     ## ##
    ##    ##       ##     ## ########   ######  ##     ## ########   ######
    ##    ##       ##     ## ##   ##         ## ##     ## ##   ##         ##
    ##    ##    ## ##     ## ##    ##  ##    ## ##     ## ##    ##  ##    ##
    ##     ######   #######  ##     ##  ######   #######  ##     ##  ######

    describe '::addCursorAtScreenPosition', ->
      it 'adds a cursor', ->
        tableEditor.addCursorAtScreenPosition([1,1])

        expect(tableEditor.getCursors().length).toEqual(2)
        expect(tableEditor.getSelections().length).toEqual(2)

      it 'removes the duplicates when the new cursor has the same position as a previous cursor', ->
        tableEditor.addCursorAtScreenPosition([0,0])

        expect(tableEditor.getCursors().length).toEqual(1)
        expect(tableEditor.getSelections().length).toEqual(1)

      it 'dispatch a did-add-cursor event', ->
        spy = jasmine.createSpy('did-add-cursor')

        tableEditor.onDidAddCursor(spy)
        tableEditor.addCursorAtScreenPosition([1,1])

        expect(spy).toHaveBeenCalled()

      it 'dispatch a did-add-selection event', ->
        spy = jasmine.createSpy('did-add-selection')

        tableEditor.onDidAddSelection(spy)
        tableEditor.addCursorAtScreenPosition([1,1])

        expect(spy).toHaveBeenCalled()

    describe '::addCursorAtPosition', ->
      it 'adds a cursor', ->
        tableEditor.addCursorAtPosition([1,1])

        expect(tableEditor.getCursors().length).toEqual(2)
        expect(tableEditor.getSelections().length).toEqual(2)

      it 'removes the duplicates when the new cursor has the same position as a previous cursor', ->
        tableEditor.addCursorAtPosition([1,0])

        expect(tableEditor.getCursors().length).toEqual(1)
        expect(tableEditor.getSelections().length).toEqual(1)

      it 'dispatch a did-add-cursor event', ->
        spy = jasmine.createSpy('did-add-cursor')

        tableEditor.onDidAddCursor(spy)
        tableEditor.addCursorAtPosition([1,1])

        expect(spy).toHaveBeenCalled()

      it 'dispatch a did-add-selection event', ->
        spy = jasmine.createSpy('did-add-selection')

        tableEditor.onDidAddSelection(spy)
        tableEditor.addCursorAtPosition([1,1])

        expect(spy).toHaveBeenCalled()

    describe '::setCursorAtScreenPosition', ->
      it 'sets the cursor position', ->
        tableEditor.setCursorAtScreenPosition([1,1])

        expect(tableEditor.getCursors().length).toEqual(1)
        expect(tableEditor.getSelections().length).toEqual(1)
        expect(tableEditor.getCursorScreenPosition()).toEqual([1,1])
        expect(tableEditor.getCursorPosition()).toEqual([2,1])

      it 'dispatch a did-change-cursor-position event', ->
        spy = jasmine.createSpy('did-change-cursor-position')

        tableEditor.onDidChangeCursorPosition(spy)
        tableEditor.setCursorAtScreenPosition([1,1])

        expect(spy).toHaveBeenCalled()

      it 'dispatch a did-change-selection-range event', ->
        spy = jasmine.createSpy('did-change-selection-range')

        tableEditor.onDidChangeSelectionRange(spy)
        tableEditor.setCursorAtScreenPosition([1,1])

        expect(spy).toHaveBeenCalled()

      it 'removes the duplicates when the new cursor has the same position as a previous cursor', ->
        tableEditor.addCursorAtScreenPosition([2,1])
        tableEditor.addCursorAtScreenPosition([1,2])

        tableEditor.setCursorAtScreenPosition([1,1])

        expect(tableEditor.getCursors().length).toEqual(1)
        expect(tableEditor.getSelections().length).toEqual(1)
        expect(tableEditor.getCursorScreenPosition()).toEqual([1,1])
        expect(tableEditor.getCursorPosition()).toEqual([2,1])

    describe '::setCursorAtPosition', ->
      it 'sets the cursor position', ->
        tableEditor.setCursorAtPosition([2,1])

        expect(tableEditor.getCursors().length).toEqual(1)
        expect(tableEditor.getSelections().length).toEqual(1)
        expect(tableEditor.getCursorScreenPosition()).toEqual([1,1])
        expect(tableEditor.getCursorPosition()).toEqual([2,1])

      it 'removes the duplicates when the new cursor has the same position as a previous cursor', ->
        tableEditor.addCursorAtScreenPosition([2,1])
        tableEditor.addCursorAtScreenPosition([1,2])

        tableEditor.setCursorAtPosition([2,1])

        expect(tableEditor.getCursors().length).toEqual(1)
        expect(tableEditor.getSelections().length).toEqual(1)
        expect(tableEditor.getCursorScreenPosition()).toEqual([1,1])
        expect(tableEditor.getCursorPosition()).toEqual([2,1])

    ##      ######  ######## ##       ########  ######  ########  ######
    ##     ##    ## ##       ##       ##       ##    ##    ##    ##    ##
    ##     ##       ##       ##       ##       ##          ##    ##
    ##      ######  ######   ##       ######   ##          ##     ######
    ##           ## ##       ##       ##       ##          ##          ##
    ##     ##    ## ##       ##       ##       ##    ##    ##    ##    ##
    ##      ######  ######## ######## ########  ######     ##     ######

    describe '::setSelectedRange', ->
      it 'sets the selection range', ->
        tableEditor.setSelectedRange([[0,0], [2,2]])

        expect(tableEditor.getSelectedRange()).toEqual([[0,0], [2,2]])
        expect(tableEditor.getSelectedRanges()).toEqual([[[0,0], [2,2]]])

      describe 'when there is many selections', ->
        it 'merges every selections into a single one', ->
          tableEditor.addCursorAtScreenPosition([2,1])

          tableEditor.setSelectedRange([[0,0], [2,2]])

          expect(tableEditor.getSelectedRange()).toEqual([[0,0], [2,2]])
          expect(tableEditor.getSelectedRanges()).toEqual([[[0,0], [2,2]]])
          expect(tableEditor.getSelections().length).toEqual(1)
          expect(tableEditor.getCursors().length).toEqual(1)

    describe '::setSelectedRanges', ->
      it 'throws an error if called without argument', ->
        expect(-> tableEditor.setSelectedRanges()).toThrow()

      it 'throws an error if called with an empty array', ->
        expect(-> tableEditor.setSelectedRanges([])).toThrow()

      it 'creates new selections based on the passed-in ranges', ->
        tableEditor.setSelectedRanges([[[0,0], [2,2]], [[2,2],[3,3]]])

        expect(tableEditor.getSelectedRanges()).toEqual([[[0,0], [2,2]], [[2,2],[3,3]]])
        expect(tableEditor.getSelections().length).toEqual(2)
        expect(tableEditor.getCursors().length).toEqual(2)

      it 'destroys selection when there is less ranges', ->
        tableEditor.setSelectedRanges([[[0,0], [2,2]], [[2,2],[3,3]]])
        tableEditor.setSelectedRanges([[[1,1], [2,2]]])

        expect(tableEditor.getSelectedRanges()).toEqual([[[1,1], [2,2]]])
        expect(tableEditor.getSelections().length).toEqual(1)
        expect(tableEditor.getCursors().length).toEqual(1)

      describe 'when defining a selection contained in another one', ->
        it 'merges the selections', ->
          tableEditor.setSelectedRanges([[[0,0], [2,2]], [[1,1],[2,2]]])

          expect(tableEditor.getSelectedRanges()).toEqual([[[0,0], [2,2]]])
          expect(tableEditor.getSelections().length).toEqual(1)
          expect(tableEditor.getCursors().length).toEqual(1)

    ##     ######   #######  ########  ##    ##
    ##    ##    ## ##     ## ##     ##  ##  ##
    ##    ##       ##     ## ##     ##   ####
    ##    ##       ##     ## ########     ##
    ##    ##       ##     ## ##           ##
    ##    ##    ## ##     ## ##           ##
    ##     ######   #######  ##           ##

    describe '::copySelectedCells', ->
      it "copies the selected cell value onto the clipboard", ->
        tableEditor.copySelectedCells()

        expect(atom.clipboard.read()).toEqual('age')
        expect(atom.clipboard.readWithMetadata().text).toEqual('age')
        expect(atom.clipboard.readWithMetadata().metadata).toEqual(fullLine: false, indentBasis: 0, values: [['age']])

      it 'copies the selected cell values onto the clipboard', ->
        tableEditor.setSelectedRange([[0,0], [2,2]])

        tableEditor.copySelectedCells()

        expect(atom.clipboard.read()).toEqual('age\t30\ngender\tfemale')
        expect(atom.clipboard.readWithMetadata().metadata).toEqual(fullLine: false, indentBasis: 0, values: [['age',30], ['gender','female']])

      it 'copies each selections as metadata', ->
        tableEditor.setSelectedRanges([[[0,0],[1,2]], [[1,0],[2,2]]])

        tableEditor.copySelectedCells()

        expect(atom.clipboard.read()).toEqual('age\t30\ngender\tfemale')

        clipboard = atom.clipboard.readWithMetadata()
        selections = clipboard.metadata.selections
        expect(clipboard.text).toEqual('age\t30\ngender\tfemale')
        expect(selections).toBeDefined()
        expect(selections.length).toEqual(2)
        expect(selections[0].text).toEqual('age\t30')
        expect(selections[0].values).toEqual([['age',30]])
        expect(selections[1].text).toEqual('gender\tfemale')
        expect(selections[1].values).toEqual([['gender','female']])

    ##     ######  ##     ## ########
    ##    ##    ## ##     ##    ##
    ##    ##       ##     ##    ##
    ##    ##       ##     ##    ##
    ##    ##       ##     ##    ##
    ##    ##    ## ##     ##    ##
    ##     ######   #######     ##

    describe '::cutSelectedCells', ->
      it "cuts the selected cell value onto the clipboard", ->
        tableEditor.cutSelectedCells()

        expect(atom.clipboard.read()).toEqual('age')
        expect(atom.clipboard.readWithMetadata().text).toEqual('age')
        expect(atom.clipboard.readWithMetadata().metadata).toEqual(fullLine: false, indentBasis: 0, values: [['age']])

        expect(tableEditor.getValueAtScreenPosition([0,0])).toEqual(undefined)

      it 'cuts the selected cell values onto the clipboard', ->
        tableEditor.setSelectedRange([[0,0], [2,2]])

        tableEditor.cutSelectedCells()

        expect(atom.clipboard.read()).toEqual('age\t30\ngender\tfemale')
        expect(atom.clipboard.readWithMetadata().metadata).toEqual(fullLine: false, indentBasis: 0, values: [['age',30], ['gender','female']])

        expect(tableEditor.getValueAtScreenPosition([0,0])).toEqual(undefined)
        expect(tableEditor.getValueAtScreenPosition([0,1])).toEqual(undefined)
        expect(tableEditor.getValueAtScreenPosition([1,0])).toEqual(undefined)
        expect(tableEditor.getValueAtScreenPosition([1,1])).toEqual(undefined)

      it 'cuts each selections as metadata', ->
        tableEditor.setSelectedRanges([[[0,0],[1,2]], [[1,0],[2,2]]])

        tableEditor.cutSelectedCells()

        expect(atom.clipboard.read()).toEqual('age\t30\ngender\tfemale')

        clipboard = atom.clipboard.readWithMetadata()
        selections = clipboard.metadata.selections
        expect(clipboard.text).toEqual('age\t30\ngender\tfemale')
        expect(selections).toBeDefined()
        expect(selections.length).toEqual(2)
        expect(selections[0].text).toEqual('age\t30')
        expect(selections[0].values).toEqual([['age',30]])
        expect(selections[1].text).toEqual('gender\tfemale')
        expect(selections[1].values).toEqual([['gender','female']])

        expect(tableEditor.getValueAtScreenPosition([0,0])).toEqual(undefined)
        expect(tableEditor.getValueAtScreenPosition([0,1])).toEqual(undefined)
        expect(tableEditor.getValueAtScreenPosition([1,0])).toEqual(undefined)
        expect(tableEditor.getValueAtScreenPosition([1,1])).toEqual(undefined)

    ##    ########     ###     ######  ######## ########
    ##    ##     ##   ## ##   ##    ##    ##    ##
    ##    ##     ##  ##   ##  ##          ##    ##
    ##    ########  ##     ##  ######     ##    ######
    ##    ##        #########       ##    ##    ##
    ##    ##        ##     ## ##    ##    ##    ##
    ##    ##        ##     ##  ######     ##    ########

    describe '::pasteClipboard', ->
      describe 'when the clipboard only has a text', ->
        beforeEach ->
          atom.clipboard.write('foo')

        describe 'when the selection spans only one cell', ->
          it 'replaces the cell content with the clipboard text', ->
            tableEditor.pasteClipboard()

            expect(tableEditor.getCursorValue()).toEqual('foo')

        describe 'when the selection spans many cells', ->
          it 'sets the same value for each cells', ->
            tableEditor.setSelectedRange([[0,0], [2,2]])

            tableEditor.pasteClipboard()

            expect(tableEditor.getValueAtScreenPosition([0,0])).toEqual('foo')
            expect(tableEditor.getValueAtScreenPosition([0,1])).toEqual('foo')
            expect(tableEditor.getValueAtScreenPosition([1,0])).toEqual('foo')
            expect(tableEditor.getValueAtScreenPosition([1,1])).toEqual('foo')

        describe 'when there is many selections', ->
          it 'sets the same value for each cells', ->
            tableEditor.setSelectedRanges([[[0,0],[1,2]], [[1,0],[2,2]]])

            table.clearUndoStack()

            tableEditor.pasteClipboard()

            expect(tableEditor.getValueAtScreenPosition([0,0])).toEqual('foo')
            expect(tableEditor.getValueAtScreenPosition([0,1])).toEqual('foo')
            expect(tableEditor.getValueAtScreenPosition([1,0])).toEqual('foo')
            expect(tableEditor.getValueAtScreenPosition([1,1])).toEqual('foo')

            expect(table.undoStack.length).toEqual(1)

            table.undo()

            expect(tableEditor.getValueAtScreenPosition([0,0])).toEqual('age')
            expect(tableEditor.getValueAtScreenPosition([0,1])).toEqual(30)
            expect(tableEditor.getValueAtScreenPosition([1,0])).toEqual('gender')
            expect(tableEditor.getValueAtScreenPosition([1,1])).toEqual('female')

      describe 'when the clipboard comes from a text buffer', ->
        describe 'and has only one selection', ->
          beforeEach ->
            atom.clipboard.write('foo', {indentBasis: 0, fullLine: false})

          describe 'when the selection spans only one cell', ->
            it 'replaces the cell content with the clipboard text', ->
              tableEditor.pasteClipboard()

              expect(tableEditor.getCursorValue()).toEqual('foo')

          describe 'when the selection spans many cells', ->
            it 'sets the same value for each cells', ->
              tableEditor.setSelectedRange([[0,0], [2,2]])

              tableEditor.pasteClipboard()

              expect(tableEditor.getValueAtScreenPosition([0,0])).toEqual('foo')
              expect(tableEditor.getValueAtScreenPosition([0,1])).toEqual('foo')
              expect(tableEditor.getValueAtScreenPosition([1,0])).toEqual('foo')
              expect(tableEditor.getValueAtScreenPosition([1,1])).toEqual('foo')

          describe 'when there is many selections', ->
            it 'sets the same value for each cells', ->
              tableEditor.setSelectedRanges([[[0,0],[1,2]], [[1,0],[2,2]]])

              table.clearUndoStack()

              tableEditor.pasteClipboard()

              expect(tableEditor.getValueAtScreenPosition([0,0])).toEqual('foo')
              expect(tableEditor.getValueAtScreenPosition([0,1])).toEqual('foo')
              expect(tableEditor.getValueAtScreenPosition([1,0])).toEqual('foo')
              expect(tableEditor.getValueAtScreenPosition([1,1])).toEqual('foo')

              expect(table.undoStack.length).toEqual(1)

              table.undo()

              expect(tableEditor.getValueAtScreenPosition([0,0])).toEqual('age')
              expect(tableEditor.getValueAtScreenPosition([0,1])).toEqual(30)
              expect(tableEditor.getValueAtScreenPosition([1,0])).toEqual('gender')
              expect(tableEditor.getValueAtScreenPosition([1,1])).toEqual('female')

          describe 'and has many selections', ->
            describe 'when flattenBufferMultiSelectionOnPaste option is enabled', ->
              beforeEach ->
                atom.config.set 'table-edit.flattenBufferMultiSelectionOnPaste', true
                atom.clipboard.write('foo\nbar', selections: [
                  {indentBasis: 0, fullLine: false, text: 'foo'}
                  {indentBasis: 0, fullLine: false, text: 'bar'}
                ])

              describe 'when the selection spans only one cell', ->
                it 'replaces the cell content with the clipboard text', ->
                  tableEditor.pasteClipboard()

                  expect(tableEditor.getCursorValue()).toEqual('foo\nbar')

              describe 'when the selection spans many cells', ->
                it 'sets the same value for each cells', ->
                  tableEditor.setSelectedRange([[0,0], [2,2]])

                  tableEditor.pasteClipboard()

                  expect(tableEditor.getValueAtScreenPosition([0,0])).toEqual('foo\nbar')
                  expect(tableEditor.getValueAtScreenPosition([0,1])).toEqual('foo\nbar')
                  expect(tableEditor.getValueAtScreenPosition([1,0])).toEqual('foo\nbar')
                  expect(tableEditor.getValueAtScreenPosition([1,1])).toEqual('foo\nbar')

            describe 'when distributeBufferMultiSelectionOnPaste option is set to vertical', ->
              beforeEach ->
                atom.config.set 'table-edit.distributeBufferMultiSelectionOnPaste', 'vertically'
                atom.clipboard.write('foo\nbar', selections: [
                  {indentBasis: 0, fullLine: false, text: 'foo'}
                  {indentBasis: 0, fullLine: false, text: 'bar'}
                ])

              describe 'when the selection spans only one cell', ->
                it 'replaces the cell content with the clipboard text', ->
                  tableEditor.pasteClipboard()

                  expect(tableEditor.getValueAtScreenPosition([0,0])).toEqual('foo')
                  expect(tableEditor.getValueAtScreenPosition([1,0])).toEqual('bar')

              describe 'when the selection spans many cells', ->
                it 'sets the same value for each cells', ->
                  tableEditor.setSelectedRange([[0,0], [2,2]])

                  tableEditor.pasteClipboard()

                  expect(tableEditor.getValueAtScreenPosition([0,0])).toEqual('foo')
                  expect(tableEditor.getValueAtScreenPosition([0,1])).toEqual('foo')
                  expect(tableEditor.getValueAtScreenPosition([1,0])).toEqual('bar')
                  expect(tableEditor.getValueAtScreenPosition([1,1])).toEqual('bar')

            describe 'when distributeBufferMultiSelectionOnPaste option is set to horizontal', ->
              beforeEach ->
                atom.config.set 'table-edit.distributeBufferMultiSelectionOnPaste', 'horizontally'
                atom.clipboard.write('foo\nbar', selections: [
                  {indentBasis: 0, fullLine: false, text: 'foo'}
                  {indentBasis: 0, fullLine: false, text: 'bar'}
                ])

              describe 'when the selection spans only one cell', ->
                it 'replaces the cell content with the clipboard text', ->

                  tableEditor.pasteClipboard()

                  expect(tableEditor.getValueAtScreenPosition([0,0])).toEqual('foo')
                  expect(tableEditor.getValueAtScreenPosition([0,1])).toEqual('bar')

              describe 'when the selection spans many cells', ->
                it 'sets the same value for each cells', ->
                  tableEditor.setSelectedRange([[0,0], [2,2]])

                  tableEditor.pasteClipboard()

                  expect(tableEditor.getValueAtScreenPosition([0,0])).toEqual('foo')
                  expect(tableEditor.getValueAtScreenPosition([0,1])).toEqual('bar')
                  expect(tableEditor.getValueAtScreenPosition([1,0])).toEqual('foo')
                  expect(tableEditor.getValueAtScreenPosition([1,1])).toEqual('bar')

      describe 'when the clipboard comes from a table', ->
        describe 'and has only one selection', ->
          beforeEach ->
            atom.clipboard.write('foo\nbar', {
              values: [['foo','bar']]
              text: 'foo\tbar'
              indentBasis: 0
              fullLine: false
            })

          describe 'when the selection spans only one cell', ->
            it 'expands the selection to match the clipboard content', ->
              tableEditor.pasteClipboard()

              expect(tableEditor.getValueAtScreenPosition([0,0])).toEqual('foo')
              expect(tableEditor.getValueAtScreenPosition([0,1])).toEqual('bar')
              expect(tableEditor.getSelectedRange()).toEqual([[0,0],[1,2]])

          describe 'when the selection spans many cells', ->
            it 'sets the same value for each cells', ->
              tableEditor.setSelectedRange([[0,0], [2,2]])

              tableEditor.pasteClipboard()

              expect(tableEditor.getValueAtScreenPosition([0,0])).toEqual('foo')
              expect(tableEditor.getValueAtScreenPosition([0,1])).toEqual('bar')
              expect(tableEditor.getValueAtScreenPosition([1,0])).toEqual('foo')
              expect(tableEditor.getValueAtScreenPosition([1,1])).toEqual('bar')

          describe 'when there is many selections', ->
            it 'sets the same value for each cells', ->
              tableEditor.setSelectedRanges([[[0,0],[1,2]], [[1,0],[2,2]]])

              table.clearUndoStack()

              tableEditor.pasteClipboard()

              expect(tableEditor.getValueAtScreenPosition([0,0])).toEqual('foo')
              expect(tableEditor.getValueAtScreenPosition([0,1])).toEqual('bar')
              expect(tableEditor.getValueAtScreenPosition([1,0])).toEqual('foo')
              expect(tableEditor.getValueAtScreenPosition([1,1])).toEqual('bar')

              expect(table.undoStack.length).toEqual(1)

              table.undo()

              expect(tableEditor.getValueAtScreenPosition([0,0])).toEqual('age')
              expect(tableEditor.getValueAtScreenPosition([0,1])).toEqual(30)
              expect(tableEditor.getValueAtScreenPosition([1,0])).toEqual('gender')
              expect(tableEditor.getValueAtScreenPosition([1,1])).toEqual('female')

        describe 'and has many selections', ->
          beforeEach ->
            atom.clipboard.write('foo\nbar', {
              selections: [
                {
                  values: [['foo', 'oof']]
                  indentBasis: 0
                  fullLine: false
                  text: 'foo\toof'
                }
                {
                  values: [['bar', 'rab']]
                  indentBasis: 0
                  fullLine: false
                  text: 'bar\trab'
                }
              ]
            })

          describe 'when the selection spans only one cell', ->
            it 'pastes only the first selection and expands the table selection', ->
              tableEditor.pasteClipboard()

              expect(tableEditor.getValueAtScreenPosition([0,0])).toEqual('foo')
              expect(tableEditor.getValueAtScreenPosition([0,1])).toEqual('oof')

          describe 'when the selection spans many cells', ->
            it 'pastes only the first selection', ->
              tableEditor.setSelectedRange([[0,0], [2,2]])

              tableEditor.pasteClipboard()

              expect(tableEditor.getValueAtScreenPosition([0,0])).toEqual('foo')
              expect(tableEditor.getValueAtScreenPosition([0,1])).toEqual('oof')
              expect(tableEditor.getValueAtScreenPosition([1,0])).toEqual('foo')
              expect(tableEditor.getValueAtScreenPosition([1,1])).toEqual('oof')

          describe 'when there is many selections', ->
            it 'paste each clipboard selection in the corresponding table selection', ->
              tableEditor.setSelectedRanges([[[0,0],[1,2]], [[1,0],[2,2]]])

              table.clearUndoStack()

              tableEditor.pasteClipboard()

              expect(tableEditor.getValueAtScreenPosition([0,0])).toEqual('foo')
              expect(tableEditor.getValueAtScreenPosition([0,1])).toEqual('oof')
              expect(tableEditor.getValueAtScreenPosition([1,0])).toEqual('bar')
              expect(tableEditor.getValueAtScreenPosition([1,1])).toEqual('rab')

              expect(table.undoStack.length).toEqual(1)

              table.undo()

              expect(tableEditor.getValueAtScreenPosition([0,0])).toEqual('age')
              expect(tableEditor.getValueAtScreenPosition([0,1])).toEqual(30)
              expect(tableEditor.getValueAtScreenPosition([1,0])).toEqual('gender')
              expect(tableEditor.getValueAtScreenPosition([1,1])).toEqual('female')

          describe 'when there is more selections in the table', ->
            it 'loops over the clipboard selection when needed', ->
              tableEditor.setSelectedRanges([[[0,0],[1,2]], [[1,0],[2,2]], [[2,0],[3,2]]])

              table.clearUndoStack()

              tableEditor.pasteClipboard()

              expect(tableEditor.getValueAtScreenPosition([0,0])).toEqual('foo')
              expect(tableEditor.getValueAtScreenPosition([0,1])).toEqual('oof')
              expect(tableEditor.getValueAtScreenPosition([1,0])).toEqual('bar')
              expect(tableEditor.getValueAtScreenPosition([1,1])).toEqual('rab')
              expect(tableEditor.getValueAtScreenPosition([2,0])).toEqual('foo')
              expect(tableEditor.getValueAtScreenPosition([2,1])).toEqual('oof')

              expect(table.undoStack.length).toEqual(1)

              table.undo()

              expect(tableEditor.getValueAtScreenPosition([0,0])).toEqual('age')
              expect(tableEditor.getValueAtScreenPosition([0,1])).toEqual(30)
              expect(tableEditor.getValueAtScreenPosition([1,0])).toEqual('gender')
              expect(tableEditor.getValueAtScreenPosition([1,1])).toEqual('female')
              expect(tableEditor.getValueAtScreenPosition([2,0])).toEqual('name')
              expect(tableEditor.getValueAtScreenPosition([2,1])).toEqual('Jane Doe')
