{Point} = require 'atom'
TableEditor = require '../lib/table-editor'
Table = require '../lib/table'
Selection = require '../lib/selection'
Cursor = require '../lib/cursor'
Range = require '../lib/range'

describe 'Cursor', ->
  [table, displayTable, tableEditor, selection, cursor] = []

  beforeEach ->
    atom.config.set 'table-edit.columnWidth', 100
    atom.config.set 'table-edit.minimuColumnWidth', 10
    atom.config.set 'table-edit.rowHeight', 20
    atom.config.set 'table-edit.minimumRowHeight', 10
    atom.config.set 'table-edit.pageMovesAmount', 20

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

    cursor = new Cursor({tableEditor, position: new Point(1,1)})
    selection = new Selection({cursor, tableEditor})

  describe '::moveUp', ->
    it 'moves the cursor up', ->
      cursor.moveUp()

      expect(cursor.position).toEqual([0,1])

    it 'resets the selection range', ->
      cursor.moveUp()

      expect(selection.range).toEqual([[0,1], [1,2]])

    describe 'when it goes outside the bounds', ->
      it 'moves to the end of the table', ->
        cursor.moveUp()
        cursor.moveUp()
        expect(cursor.position).toEqual([2,1])

  describe '::moveDown', ->
    it 'moves the cursor down', ->
      cursor.moveDown()

      expect(cursor.position).toEqual([2,1])

    it 'resets the selection range', ->
      cursor.moveDown()

      expect(selection.range).toEqual([[2,1], [3,2]])

    describe 'when it goes outside the bounds', ->
      it 'moves to the beginning of the table', ->
        cursor.moveDown()
        cursor.moveDown()
        expect(cursor.position).toEqual([0,1])

  describe '::moveLeft', ->
    it 'moves the cursor left', ->
      cursor.moveLeft()

      expect(cursor.position).toEqual([1,0])

    it 'resets the selection range', ->
      cursor.moveLeft()

      expect(selection.range).toEqual([[1,0], [2,1]])

    describe 'when it goes outside the bounds', ->
      it 'moves to the end of the previous row', ->
        cursor.moveLeft()
        cursor.moveLeft()
        expect(cursor.position).toEqual([0,2])

  describe '::moveRight', ->
    it 'moves the cursor right', ->
      cursor.moveRight()

      expect(cursor.position).toEqual([1,2])

    it 'resets the selection range', ->
      cursor.moveRight()

      expect(selection.range).toEqual([[1,2], [2,3]])

    describe 'when it goes outside the bounds', ->
      it 'moves to the beginning of the next row', ->
        cursor.moveRight()
        cursor.moveRight()
        expect(cursor.position).toEqual([2,0])

  describe '::moveToTop', ->
    it 'moves the cursor all the way to the top', ->
      cursor.moveToTop()

      expect(cursor.position).toEqual([0,1])

  describe '::moveToBottom', ->
    it 'moves the cursor all the way to the bottom', ->
      cursor.moveToBottom()

      expect(cursor.position).toEqual([2,1])

  describe '::moveToLeft', ->
    it 'moves the cursor all the way to the left', ->
      cursor.moveToLeft()

      expect(cursor.position).toEqual([1,0])

  describe '::moveToRight', ->
    it 'moves the cursor all the way to the right', ->
      cursor.moveToRight()

      expect(cursor.position).toEqual([1,2])

  describe 'page moves', ->
    beforeEach ->
      table = new Table

      for n in [0..60]
        table.addColumn "column_#{n}"

      for r in [0..60]
        row = []
        row.push("cell_#{r}_#{c}") for c in [0..60]

        table.addRow(row)

      tableEditor = new TableEditor({table})
      {displayTable} = tableEditor

      cursor = new Cursor({tableEditor, position: new Point(30,30)})
      selection = new Selection({cursor, tableEditor})

    describe '::pageUp', ->
      it 'moves the cursor by the amount of page moves', ->
        cursor.pageUp()

        expect(cursor.position).toEqual([10,30])

      it 'stops at the first line when going beyond top', ->
        cursor.pageUp()
        cursor.pageUp()

        expect(cursor.position).toEqual([0,30])

    describe '::pageDown', ->
      it 'moves the cursor by the amount of page moves', ->
        cursor.pageDown()

        expect(cursor.position).toEqual([50,30])

      it 'stops at the last line when going beyond bottom', ->
        cursor.pageDown()
        cursor.pageDown()

        expect(cursor.position).toEqual([60,30])

    describe '::pageLeft', ->
      it 'moves the cursor by the amount of page moves', ->
        cursor.pageLeft()

        expect(cursor.position).toEqual([30,10])

      it 'stops at the first column when going beyond left', ->
        cursor.pageLeft()
        cursor.pageLeft()

        expect(cursor.position).toEqual([30,0])

    describe '::pageRight', ->
      it 'moves the cursor by the amount of page moves', ->
        cursor.pageRight()

        expect(cursor.position).toEqual([30,50])

      it 'stops at the last column when going beyond right', ->
        cursor.pageRight()
        cursor.pageRight()

        expect(cursor.position).toEqual([30,60])
