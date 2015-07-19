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
