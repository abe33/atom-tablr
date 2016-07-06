require './helpers/spec-helper'

TableEditor = require '../lib/table-editor'
Table = require '../lib/table'

describe 'TableEditor', ->
  [table, displayTable, tableEditor] = []

  beforeEach ->
    atom.config.set 'tablr.tableEditor.columnWidth', 100
    atom.config.set 'tablr.minimuColumnWidth', 10
    atom.config.set 'tablr.tableEditor.rowHeight', 20
    atom.config.set 'tablr.tableEditor.minimumRowHeight', 10

  describe 'when initialized without a table', ->
    beforeEach ->
      tableEditor = new TableEditor
      {table, displayTable} = tableEditor

    it 'creates an empty table and its displayTable', ->
      expect(table).toBeDefined()
      expect(displayTable).toBeDefined()

    it 'retains the table', ->
      expect(table.isRetained()).toBeTruthy()

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

    it 'retains the table', ->
      expect(table.isRetained()).toBeTruthy()

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

    it 'returns the value at cursor', ->
      expect(tableEditor.getCursorValue()).toEqual('age')
      expect(tableEditor.getCursorValues()).toEqual(['age'])

    describe '::delete', ->
      it 'deletes the content of the selected cells', ->
        initialValue = tableEditor.getCursorValue()
        expect(initialValue).not.toBeUndefined()

        tableEditor.delete()

        expect(tableEditor.getCursorValue()).toBeUndefined()

        tableEditor.undo()

        expect(tableEditor.getCursorValue()).toEqual(initialValue)

        tableEditor.redo()

        expect(tableEditor.getCursorValue()).toBeUndefined()

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

    ##    ########  ########  ######  ########  #######  ########  ########
    ##    ##     ## ##       ##    ##    ##    ##     ## ##     ## ##
    ##    ##     ## ##       ##          ##    ##     ## ##     ## ##
    ##    ########  ######    ######     ##    ##     ## ########  ######
    ##    ##   ##   ##             ##    ##    ##     ## ##   ##   ##
    ##    ##    ##  ##       ##    ##    ##    ##     ## ##    ##  ##
    ##    ##     ## ########  ######     ##     #######  ##     ## ########

    describe '::serialize', ->
      it 'serializes the table editor', ->
        expect(tableEditor.serialize()).toEqual({
          deserializer: 'TableEditor'
          displayTable: tableEditor.displayTable.serialize()
          cursors: tableEditor.getCursors().map (cursor) -> cursor.serialize()
          selections: tableEditor.getSelections().map (sel) -> sel.serialize()
        })

    describe '.deserialize', ->
      it 'restores a table editor', ->
        tableEditor = atom.deserializers.deserialize({
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

          cursors: [[2,2]]
          selections: [[[2,2],[3,4]]]
        })

        expect(tableEditor.isModified()).toBeTruthy()
        expect(tableEditor.getScreenRows()).toEqual([
          ["name","age","gender"]
          ["Jane","32","female"]
          ["John","30","male"]
          [null,null,null]
        ])
        expect(tableEditor.getSelections().length).toEqual(1)
        expect(tableEditor.getSelectedRange()).toEqual([[2,2],[3,4]])
        expect(tableEditor.getCursorPosition()).toEqual([2,2])

    ##     ######  ##     ## ########   ######   #######  ########   ######
    ##    ##    ## ##     ## ##     ## ##    ## ##     ## ##     ## ##    ##
    ##    ##       ##     ## ##     ## ##       ##     ## ##     ## ##
    ##    ##       ##     ## ########   ######  ##     ## ########   ######
    ##    ##       ##     ## ##   ##         ## ##     ## ##   ##         ##
    ##    ##    ## ##     ## ##    ##  ##    ## ##     ## ##    ##  ##    ##
    ##     ######   #######  ##     ##  ######   #######  ##     ##  ######

    describe 'for an empty table', ->
      describe 'adding a column and a row', ->
        it 'set the cursor position to 0,0', ->
          table = new Table
          tableEditor = new TableEditor({table})
          tableEditor.initializeAfterSetup()

          tableEditor.insertColumnAfter()
          tableEditor.insertRowAfter()

          expect(tableEditor.getCursorPosition()).toEqual([0,0])

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

    describe '::addCursorBelowLastSelection', ->
      beforeEach ->
        tableEditor.addColumn()
        tableEditor.addColumn()
        tableEditor.addColumn()
        tableEditor.addRow()
        tableEditor.addRow()
        tableEditor.addRow()
        tableEditor.addRow()

        tableEditor.setSelectedRange([
          [3,2]
          [5,4]
        ])

      it 'creates a new cursor', ->
        tableEditor.addCursorBelowLastSelection()

        expect(tableEditor.getCursors().length).toEqual(2)
        expect(tableEditor.getCursorScreenPosition()).toEqual([5,2])

    describe '::addCursorAboveLastSelection', ->
      beforeEach ->
        tableEditor.addColumn()
        tableEditor.addColumn()
        tableEditor.addColumn()
        tableEditor.addRow()
        tableEditor.addRow()
        tableEditor.addRow()
        tableEditor.addRow()

        tableEditor.setSelectedRange([
          [3,2]
          [5,4]
        ])

      it 'creates a new cursor', ->
        tableEditor.addCursorAboveLastSelection()

        expect(tableEditor.getCursors().length).toEqual(2)
        expect(tableEditor.getCursorScreenPosition()).toEqual([2,2])

    describe '::addCursorLeftToLastSelection', ->
      beforeEach ->
        tableEditor.addColumn()
        tableEditor.addColumn()
        tableEditor.addColumn()
        tableEditor.addRow()
        tableEditor.addRow()
        tableEditor.addRow()
        tableEditor.addRow()

        tableEditor.setSelectedRange([
          [3,2]
          [5,4]
        ])

      it 'creates a new cursor', ->
        tableEditor.addCursorLeftToLastSelection()

        expect(tableEditor.getCursors().length).toEqual(2)
        expect(tableEditor.getCursorScreenPosition()).toEqual([3,1])

    describe '::addCursorRightToLastSelection', ->
      beforeEach ->
        tableEditor.addColumn()
        tableEditor.addColumn()
        tableEditor.addColumn()
        tableEditor.addRow()
        tableEditor.addRow()
        tableEditor.addRow()
        tableEditor.addRow()

        tableEditor.setSelectedRange([
          [3,2]
          [5,4]
        ])

      it 'creates a new cursor', ->
        tableEditor.addCursorRightToLastSelection()

        expect(tableEditor.getCursors().length).toEqual(2)
        expect(tableEditor.getCursorScreenPosition()).toEqual([3,4])

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

    describe '::moveLineDown', ->
      beforeEach ->
        tableEditor = new TableEditor
        tableEditor.addColumn 'key'
        tableEditor.addColumn 'value'
        tableEditor.addColumn 'foo'

        for i in [0...100]
          tableEditor.addRow [
            "row#{i}"
            i * 100
            if i % 2 is 0 then 'yes' else 'no'
          ]

        tableEditor.addCursorAtPosition([2,0])
        tableEditor.addCursorAtPosition([4,0])

        table.clearUndoStack()

      it 'moves the lines at cursors one line down', ->
        tableEditor.moveLineDown()

        expect(tableEditor.getCursorPositions()).toEqual([
          [1,0]
          [3,0]
          [5,0]
        ])

        expect(tableEditor.getScreenRow(0)).toEqual(['row1', 100, 'no'])
        expect(tableEditor.getScreenRow(1)).toEqual(['row0', 0, 'yes'])
        expect(tableEditor.getScreenRow(2)).toEqual(['row3', 300, 'no'])
        expect(tableEditor.getScreenRow(3)).toEqual(['row2', 200, 'yes'])
        expect(tableEditor.getScreenRow(4)).toEqual(['row5', 500, 'no'])
        expect(tableEditor.getScreenRow(5)).toEqual(['row4', 400, 'yes'])

      it 'updates the selections', ->
        tableEditor.moveLineDown()

        expect(tableEditor.getSelectedRanges()).toEqual([
          [[1,0],[2,1]]
          [[3,0],[4,1]]
          [[5,0],[6,1]]
        ])

      it 'can undo the cursors moves', ->
        tableEditor.moveLineDown()

        tableEditor.undo()

        expect(tableEditor.getCursorPositions()).toEqual([
          [0,0]
          [2,0]
          [4,0]
        ])

        tableEditor.redo()

        expect(tableEditor.getCursorPositions()).toEqual([
          [1,0]
          [3,0]
          [5,0]
        ])

      describe 'when there is an order defined', ->
        beforeEach ->
          tableEditor.sortBy('key')

        it 'does nothing and creates a notification instead', ->
          spyOn(atom.notifications, 'addWarning')

          tableEditor.moveLineDown()

          expect(tableEditor.getCursorPositions()).toEqual([
            [0,0]
            [2,0]
            [4,0]
          ])

          expect(atom.notifications.addWarning).toHaveBeenCalled()

    describe '::moveLineUp', ->
      beforeEach ->
        tableEditor = new TableEditor
        tableEditor.addColumn 'key'
        tableEditor.addColumn 'value'
        tableEditor.addColumn 'foo'

        for i in [0...100]
          tableEditor.addRow [
            "row#{i}"
            i * 100
            if i % 2 is 0 then 'yes' else 'no'
          ]

        tableEditor.setCursorAtPosition([1,0])
        tableEditor.addCursorAtPosition([3,0])
        tableEditor.addCursorAtPosition([5,0])

        table.clearUndoStack()

      it 'moves the lines at cursors one line up', ->
        tableEditor.moveLineUp()

        expect(tableEditor.getCursorPositions()).toEqual([
          [0,0]
          [2,0]
          [4,0]
        ])

        expect(tableEditor.getScreenRow(0)).toEqual(['row1', 100, 'no'])
        expect(tableEditor.getScreenRow(1)).toEqual(['row0', 0, 'yes'])
        expect(tableEditor.getScreenRow(2)).toEqual(['row3', 300, 'no'])
        expect(tableEditor.getScreenRow(3)).toEqual(['row2', 200, 'yes'])
        expect(tableEditor.getScreenRow(4)).toEqual(['row5', 500, 'no'])
        expect(tableEditor.getScreenRow(5)).toEqual(['row4', 400, 'yes'])

      it 'updates the selections', ->
        tableEditor.moveLineUp()

        expect(tableEditor.getSelectedRanges()).toEqual([
          [[0,0],[1,1]]
          [[2,0],[3,1]]
          [[4,0],[5,1]]
        ])

      it 'can undo the cursors moves', ->
        tableEditor.moveLineUp()

        tableEditor.undo()

        expect(tableEditor.getCursorPositions()).toEqual([
          [1,0]
          [3,0]
          [5,0]
        ])

        tableEditor.redo()

        expect(tableEditor.getCursorPositions()).toEqual([
          [0,0]
          [2,0]
          [4,0]
        ])

      describe 'when there is an order defined', ->
        beforeEach ->
          tableEditor.sortBy('key')

        it 'does nothing and creates a notification instead', ->
          spyOn(atom.notifications, 'addWarning')

          tableEditor.moveLineUp()

          expect(tableEditor.getCursorPositions()).toEqual([
            [1,0]
            [3,0]
            [5,0]
          ])

          expect(atom.notifications.addWarning).toHaveBeenCalled()

    describe '::moveColumnLeft', ->
      beforeEach ->
        tableEditor = new TableEditor
        tableEditor.addColumn 'key'
        tableEditor.addColumn 'value'
        tableEditor.addColumn 'foo'

        for i in [0...100]
          tableEditor.addRow [
            "row#{i}"
            i * 100
            if i % 2 is 0 then 'yes' else 'no'
          ]

        tableEditor.setCursorAtPosition([1,1])
        tableEditor.addCursorAtPosition([3,2])

        table.clearUndoStack()

      it 'moves the column to the left', ->
        tableEditor.moveColumnLeft()

        expect(tableEditor.getScreenColumn(0).name).toEqual('value')
        expect(tableEditor.getScreenColumn(1).name).toEqual('foo')
        expect(tableEditor.getScreenColumn(2).name).toEqual('key')

      it 'updates the selections', ->
        tableEditor.moveColumnLeft()

        expect(tableEditor.getSelectedRanges()).toEqual([
          [[1,0],[2,1]]
          [[3,1],[4,2]]
        ])

      it 'can undo the cursors moves', ->
        tableEditor.moveColumnLeft()

        expect(tableEditor.getCursorPositions()).toEqual([
          [1,0]
          [3,1]
        ])

        tableEditor.undo()

        expect(tableEditor.getCursorPositions()).toEqual([
          [1,1]
          [3,2]
        ])

        tableEditor.redo()

        expect(tableEditor.getCursorPositions()).toEqual([
          [1,0]
          [3,1]
        ])

    describe '::moveColumnRight', ->
      beforeEach ->
        tableEditor = new TableEditor
        tableEditor.addColumn 'key'
        tableEditor.addColumn 'value'
        tableEditor.addColumn 'foo'

        for i in [0...100]
          tableEditor.addRow [
            "row#{i}"
            i * 100
            if i % 2 is 0 then 'yes' else 'no'
          ]

        tableEditor.setCursorAtPosition([1,0])
        tableEditor.addCursorAtPosition([3,1])

        table.clearUndoStack()

      it 'moves the column to the right', ->
        tableEditor.moveColumnRight()

        expect(tableEditor.getScreenColumn(0).name).toEqual('foo')
        expect(tableEditor.getScreenColumn(1).name).toEqual('key')
        expect(tableEditor.getScreenColumn(2).name).toEqual('value')

      it 'updates the selections', ->
        tableEditor.moveColumnRight()

        expect(tableEditor.getSelectedRanges()).toEqual([
          [[1,1],[2,2]]
          [[3,2],[4,3]]
        ])

      it 'can undo the cursors moves', ->
        tableEditor.moveColumnRight()

        expect(tableEditor.getCursorPositions()).toEqual([
          [1,1]
          [3,2]
        ])

        tableEditor.undo()

        expect(tableEditor.getCursorPositions()).toEqual([
          [1,0]
          [3,1]
        ])

        tableEditor.redo()

        expect(tableEditor.getCursorPositions()).toEqual([
          [1,1]
          [3,2]
        ])

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
        expect(atom.clipboard.readWithMetadata().metadata).toEqual(fullLine: false, indentBasis: 0, values: [[['age']]])

      it 'copies the selected cell values onto the clipboard', ->
        tableEditor.setSelectedRange([[0,0], [2,2]])

        tableEditor.copySelectedCells()

        expect(atom.clipboard.read()).toEqual('age\t30\ngender\tfemale')
        expect(atom.clipboard.readWithMetadata().metadata).toEqual(fullLine: false, indentBasis: 0, values: [[['age',30], ['gender','female']]])

      it 'copies each selections as metadata', ->
        tableEditor.setSelectedRanges([[[0,0],[1,2]], [[1,0],[2,2]]])

        tableEditor.copySelectedCells()

        expect(atom.clipboard.read()).toEqual('age\t30\ngender\tfemale')

        clipboard = atom.clipboard.readWithMetadata()
        metadata = clipboard.metadata
        selections = metadata.selections
        expect(clipboard.text).toEqual('age\t30\ngender\tfemale')
        expect(metadata.values).toEqual([
          [['age',30]]
          [['gender','female']]
        ])
        expect(selections).toBeDefined()
        expect(selections.length).toEqual(2)
        expect(selections[0].text).toEqual('age\t30')
        expect(selections[1].text).toEqual('gender\tfemale')

      describe 'when the treatEachCellAsASelectionWhenPastingToATextBuffer setting is enabled', ->
        beforeEach ->
          atom.config.set 'tablr.copyPaste.treatEachCellAsASelectionWhenPastingToABuffer', true

        it 'copies each cells as a buffer selection', ->
          tableEditor.setSelectedRanges([[[0,0],[1,2]], [[1,0],[2,2]]])

          tableEditor.copySelectedCells()

          expect(atom.clipboard.read()).toEqual('age\t30\ngender\tfemale')

          clipboard = atom.clipboard.readWithMetadata()
          metadata = clipboard.metadata
          selections = metadata.selections
          expect(clipboard.text).toEqual('age\t30\ngender\tfemale')
          expect(metadata.values).toEqual([
            [['age',30]]
            [['gender','female']]
          ])
          expect(selections).toBeDefined()
          expect(selections.length).toEqual(4)
          expect(selections[0].text).toEqual('age')
          expect(selections[1].text).toEqual(30)
          expect(selections[2].text).toEqual('gender')
          expect(selections[3].text).toEqual('female')

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
        expect(atom.clipboard.readWithMetadata().metadata).toEqual(fullLine: false, indentBasis: 0, values: [[['age']]])

        expect(tableEditor.getValueAtScreenPosition([0,0])).toEqual(undefined)

      it 'cuts the selected cell values onto the clipboard', ->
        tableEditor.setSelectedRange([[0,0], [2,2]])

        tableEditor.cutSelectedCells()

        expect(atom.clipboard.read()).toEqual('age\t30\ngender\tfemale')
        expect(atom.clipboard.readWithMetadata().metadata).toEqual(fullLine: false, indentBasis: 0, values: [[['age',30], ['gender','female']]])

        expect(tableEditor.getValueAtScreenPosition([0,0])).toEqual(undefined)
        expect(tableEditor.getValueAtScreenPosition([0,1])).toEqual(undefined)
        expect(tableEditor.getValueAtScreenPosition([1,0])).toEqual(undefined)
        expect(tableEditor.getValueAtScreenPosition([1,1])).toEqual(undefined)

      it 'cuts each selections as metadata', ->
        tableEditor.setSelectedRanges([[[0,0],[1,2]], [[1,0],[2,2]]])

        tableEditor.cutSelectedCells()

        expect(atom.clipboard.read()).toEqual('age\t30\ngender\tfemale')

        clipboard = atom.clipboard.readWithMetadata()
        metadata = clipboard.metadata
        selections = metadata.selections
        expect(clipboard.text).toEqual('age\t30\ngender\tfemale')
        expect(metadata.values).toEqual([
          [['age',30]]
          [['gender','female']]
        ])
        expect(selections).toBeDefined()
        expect(selections.length).toEqual(2)
        expect(selections[0].text).toEqual('age\t30')
        expect(selections[1].text).toEqual('gender\tfemale')

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
            describe 'that span one cell', ->
              it 'pastes each selection in the corresponding cells', ->
                atom.clipboard.write('foo\nbar', selections: [
                  {indentBasis: 0, fullLine: false, text: 'foo'}
                  {indentBasis: 0, fullLine: false, text: 'bar'}
                ])
                tableEditor.setSelectedRanges([[[0,0],[1,1]], [[1,0],[2,1]]])

                table.clearUndoStack()

                tableEditor.pasteClipboard()

                expect(tableEditor.getValueAtScreenPosition([0,0])).toEqual('foo')
                expect(tableEditor.getValueAtScreenPosition([1,0])).toEqual('bar')

            describe 'when flattenBufferMultiSelectionOnPaste option is enabled', ->
              beforeEach ->
                atom.config.set 'tablr.copyPaste.flattenBufferMultiSelectionOnPaste', true
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
                atom.config.set 'tablr.copyPaste.distributeBufferMultiSelectionOnPaste', 'vertically'
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
                atom.config.set 'tablr.copyPaste.distributeBufferMultiSelectionOnPaste', 'horizontally'
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
              values: [[['foo','bar']]]
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
              values: [
                [['foo', 'oof']]
                [['bar', 'rab']]
              ]
              selections: [
                {
                  indentBasis: 0
                  fullLine: false
                  text: 'foo\toof'
                }
                {
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
