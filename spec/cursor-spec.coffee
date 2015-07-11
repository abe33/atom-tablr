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
      it 'moves to the end of the table', ->
        cursor.moveLeft()
        cursor.moveLeft()
        expect(cursor.position).toEqual([1,2])

  describe '::moveRight', ->
    it 'moves the cursor right', ->
      cursor.moveRight()

      expect(cursor.position).toEqual([1,2])

    it 'resets the selection range', ->
      cursor.moveRight()

      expect(selection.range).toEqual([[1,2], [2,3]])

    describe 'when it goes outside the bounds', ->
      it 'moves to the beginning of the table', ->
        cursor.moveRight()
        cursor.moveRight()
        expect(cursor.position).toEqual([1,0])
