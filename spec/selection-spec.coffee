{Point} = require 'atom'
TableEditor = require '../lib/table-editor'
Table = require '../lib/table'
Selection = require '../lib/selection'
Cursor = require '../lib/cursor'
Range = require '../lib/range'

describe 'Selection', ->
  [table, displayTable, tableEditor, selection, cursor] = []

  beforeEach ->
    atom.config.set 'table-edit.columnWidth', 100
    atom.config.set 'table-edit.minimuColumnWidth', 10
    atom.config.set 'table-edit.rowHeight', 20
    atom.config.set 'table-edit.minimumRowHeight', 10

    table = new Table

    table.addColumn 'key'
    table.addColumn 'value'
    table.addColumn 'mode'

    table.addRow ['name', 'Jane Doe', 'read']
    table.addRow ['age', 30, 'read']
    table.addRow ['gender', 'female', 'read']

    tableEditor = new TableEditor({table})
    {displayTable} = tableEditor

    displayTable.sortBy('key')

  describe 'with a size of zero cells', ->
    beforeEach ->
      cursor = new Cursor({tableEditor, position: new Point(1,1)})
      selection = new Selection({cursor, range: new Range(cursor.position, cursor.position), tableEditor})

    it 'is empty', ->
      expect(selection.isEmpty()).toBeTruthy()

    it 'does not span several cells', ->
      expect(selection.spanMoreThanOneCell()).toBeFalsy()

  describe 'with a size of one cell', ->
    beforeEach ->
      cursor = new Cursor({tableEditor, position: new Point(1,1)})
      range = cursor.getRange()
      selection = new Selection({cursor, range, tableEditor})

    it 'has a range', ->
      expect(selection.getRange()).toEqual([[1,1],[2,2]])

    it 'is not empty', ->
      expect(selection.isEmpty()).toBeFalsy()

    it 'does not span several cells', ->
      expect(selection.spanMoreThanOneCell()).toBeFalsy()

  describe 'that spans many cells', ->
    beforeEach ->
      cursor = new Cursor({tableEditor, position: new Point(1,1)})
      range = new Range([1,1], [3,1])
      selection = new Selection({cursor, range, tableEditor})

    it 'is not empty', ->
      expect(selection.isEmpty()).toBeFalsy()

    it 'spans several cells', ->
      expect(selection.spanMoreThanOneCell()).toBeTruthy()

  describe '::setRange', ->
    it 'sets the selection range', ->
      selection.setRange([[0,0],[2,2]])

      expect(selection.getRange()).toEqual([[0,0],[2,2]])

    it 'changes the cursor position if it is no longer contained', ->
      selection.setRange([[0,0],[1,3]])

      expect(selection.getRange()).toEqual([[0,0],[1,3]])
      expect(selection.getCursor().getPosition()).toEqual([0,0])

  describe '::expandLeft', ->
    beforeEach ->
      cursor = new Cursor({tableEditor, position: new Point(1,1)})
      range = cursor.getRange()
      selection = new Selection({cursor, range, tableEditor})

    it 'expands the selection to the left', ->
      selection.expandLeft()

      expect(selection.getRange()).toEqual([[1,0],[2,2]])

    it 'locks the selection when it reach the table bound', ->
      selection.expandLeft()
      selection.expandLeft()
      selection.expandLeft()

      expect(selection.getRange()).toEqual([[1,0],[2,2]])

    describe 'then expanding to the right', ->
      it 'reduces the selection area from the left', ->
        selection.expandLeft()
        selection.expandRight()

        expect(selection.getRange()).toEqual([[1,1],[2,2]])

      it 'inverses the selection direction with a delta bigger than the selection', ->
        selection.expandLeft()
        selection.expandRight(4)

        expect(selection.getRange()).toEqual([[1,1],[2,3]])

  describe '::expandRight', ->
    beforeEach ->
      cursor = new Cursor({tableEditor, position: new Point(1,1)})
      range = cursor.getRange()
      selection = new Selection({cursor, range, tableEditor})

    it 'expands the selection to the left', ->
      selection.expandRight()

      expect(selection.getRange()).toEqual([[1,1],[2,3]])

    it 'locks the selection when it reach the table bound', ->
      selection.expandRight()
      selection.expandRight()
      selection.expandRight()

      expect(selection.getRange()).toEqual([[1,1],[2,3]])

    describe 'then expanding to the left', ->
      it 'reduces the selection area from the right', ->
        selection.expandRight()
        selection.expandLeft()

        expect(selection.getRange()).toEqual([[1,1],[2,2]])

      it 'inverses the selection direction with a delta bigger than the selection', ->
        selection.expandRight()
        selection.expandLeft(4)

        expect(selection.getRange()).toEqual([[1,0],[2,2]])

  describe '::expandUp', ->
    beforeEach ->
      cursor = new Cursor({tableEditor, position: new Point(1,1)})
      range = cursor.getRange()
      selection = new Selection({cursor, range, tableEditor})

    it 'expands the selection to the top', ->
      selection.expandUp()

      expect(selection.getRange()).toEqual([[0,1],[2,2]])

    it 'locks the selection when it reach the table bound', ->
      selection.expandUp()
      selection.expandUp()
      selection.expandUp()

      expect(selection.getRange()).toEqual([[0,1],[2,2]])

    describe 'then expanding to the bottom', ->
      it 'reduces the selection area from the top', ->
        selection.expandUp()
        selection.expandDown()

        expect(selection.getRange()).toEqual([[1,1],[2,2]])

      it 'inverses the selection direction with a delta bigger than the selection', ->
        selection.expandUp()
        selection.expandDown(4)

        expect(selection.getRange()).toEqual([[1,1],[3,2]])

  describe '::expandDown', ->
    beforeEach ->
      cursor = new Cursor({tableEditor, position: new Point(1,1)})
      range = cursor.getRange()
      selection = new Selection({cursor, range, tableEditor})

    it 'expands the selection to the bottom', ->
      selection.expandDown()

      expect(selection.getRange()).toEqual([[1,1],[3,2]])

    it 'locks the selection when it reach the table bound', ->
      selection.expandDown()
      selection.expandDown()
      selection.expandDown()

      expect(selection.getRange()).toEqual([[1,1],[3,2]])

    describe 'then expanding to the top', ->
      it 'reduces the selection area from the bottom', ->
        selection.expandDown()
        selection.expandUp()

        expect(selection.getRange()).toEqual([[1,1],[2,2]])

      it 'inverses the selection direction with a delta bigger than the selection', ->
        selection.expandDown()
        selection.expandUp(4)

        expect(selection.getRange()).toEqual([[0,1],[2,2]])
