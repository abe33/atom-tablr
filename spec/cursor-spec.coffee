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
    atom.config.set 'table-edit.pageMovesAmount', 3

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

  describe '::pageUp', ->
    it 'moves the cursor by the amount of page moves', ->
      spyOn(cursor, 'moveUp')

      cursor.pageUp()

      expect(cursor.moveUp).toHaveBeenCalledWith(atom.config.get 'table-edit.pageMovesAmount')

  describe '::pageDown', ->
    it 'moves the cursor by the amount of page moves', ->
      spyOn(cursor, 'moveDown')

      cursor.pageDown()

      expect(cursor.moveDown).toHaveBeenCalledWith(atom.config.get 'table-edit.pageMovesAmount')

  describe '::pageLeft', ->
    it 'moves the cursor by the amount of page moves', ->
      spyOn(cursor, 'moveLeft')

      cursor.pageLeft()

      expect(cursor.moveLeft).toHaveBeenCalledWith(atom.config.get 'table-edit.pageMovesAmount')

  describe '::pageRight', ->
    it 'moves the cursor by the amount of page moves', ->
      spyOn(cursor, 'moveRight')

      cursor.pageRight()

      expect(cursor.moveRight).toHaveBeenCalledWith(atom.config.get 'table-edit.pageMovesAmount')
