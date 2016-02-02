require './helpers/spec-helper'

{Point} = require 'atom'
TableEditor = require '../lib/table-editor'
Table = require '../lib/table'
Selection = require '../lib/selection'
Cursor = require '../lib/cursor'
Range = require '../lib/range'

describe 'Cursor', ->
  [table, displayTable, tableEditor, selection, cursor] = []

  beforeEach ->
    atom.config.set 'tablr.tableEditor.columnWidth', 100
    atom.config.set 'tablr.minimuColumnWidth', 10
    atom.config.set 'tablr.tableEditor.rowHeight', 20
    atom.config.set 'tablr.tableEditor.minimumRowHeight', 10
    atom.config.set 'tablr.tableEditor.pageMoveRowAmount', 20
    atom.config.set 'tablr.tableEditor.pageMoveColumnAmount', 20

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

  describe 'selection moves', ->
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
      selection = new Selection({
        cursor, tableEditor,
        range: new Range([28,28],[32,32])
      })

    describe '::moveLeftInSelection', ->
      it 'moves the cursor to the left', ->
        cursor.moveLeftInSelection()

        expect(cursor.position).toEqual([30,29])

      it 'does not reset the selection range', ->
        cursor.moveLeftInSelection()

        expect(selection.range).toEqual([[28,28], [32,32]])

      describe 'when the selection spans only the cursor cell', ->
        beforeEach ->
          selection.resetRangeOnCursor()

        it 'ignores the selection bounds', ->
          cursor.moveLeftInSelection()

          expect(cursor.position).toEqual([30,29])

      describe 'when it goes outside the selection bounds', ->
        it 'moves to the end of the previous selection row', ->
          cursor.moveLeftInSelection()
          cursor.moveLeftInSelection()
          cursor.moveLeftInSelection()

          expect(cursor.position).toEqual([29,31])

        it 'moves to the end of the last selection row when it goes past the first row', ->
          cursor.moveLeftInSelection() for n in [0..10]

          expect(cursor.position).toEqual([31,31])

    describe '::moveRightInSelection', ->
      it 'moves the cursor to the right', ->
        cursor.moveRightInSelection()

        expect(cursor.position).toEqual([30,31])

      it 'does not reset the selection range', ->
        cursor.moveRightInSelection()

        expect(selection.range).toEqual([[28,28], [32,32]])

      describe 'when the selection spans only the cursor cell', ->
        beforeEach ->
          selection.resetRangeOnCursor()

        it 'ignores the selection bounds', ->
          cursor.moveRightInSelection()

          expect(cursor.position).toEqual([30,31])

      describe 'when it goes outside the selection bounds', ->
        it 'moves to the end of the previous selection row', ->
          cursor.moveRightInSelection()
          cursor.moveRightInSelection()

          expect(cursor.position).toEqual([31,28])

        it 'moves to the end of the last selection row when it goes past the first row', ->
          cursor.moveRightInSelection() for n in [0..5]

          expect(cursor.position).toEqual([28,28])

    describe '::moveUpInSelection', ->
      it 'moves the cursor to the top', ->
        cursor.moveUpInSelection()

        expect(cursor.position).toEqual([29,30])

      it 'does not reset the selection range', ->
        cursor.moveUpInSelection()

        expect(selection.range).toEqual([[28,28], [32,32]])

      describe 'when the selection spans only the cursor cell', ->
        beforeEach ->
          selection.resetRangeOnCursor()

        it 'ignores the selection bounds', ->
          cursor.moveUpInSelection()

          expect(cursor.position).toEqual([29,30])

      describe 'when it goes outside the selection bounds', ->
        it 'moves to the end of the selection column row', ->
          cursor.moveUpInSelection()
          cursor.moveUpInSelection()
          cursor.moveUpInSelection()

          expect(cursor.position).toEqual([31,30])

    describe '::moveDownInSelection', ->
      it 'moves the cursor to the top', ->
        cursor.moveDownInSelection()

        expect(cursor.position).toEqual([31,30])

      it 'does not reset the selection range', ->
        cursor.moveDownInSelection()

        expect(selection.range).toEqual([[28,28], [32,32]])

      describe 'when the selection spans only the cursor cell', ->
        beforeEach ->
          selection.resetRangeOnCursor()

        it 'ignores the selection bounds', ->
          cursor.moveDownInSelection()

          expect(cursor.position).toEqual([31,30])

      describe 'when it goes outside the selection bounds', ->
        it 'moves to the end of the selection column row', ->
          cursor.moveDownInSelection()
          cursor.moveDownInSelection()

          expect(cursor.position).toEqual([28,30])

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

    ##    ########  ########  ######  ########  #######  ########  ########
    ##    ##     ## ##       ##    ##    ##    ##     ## ##     ## ##
    ##    ##     ## ##       ##          ##    ##     ## ##     ## ##
    ##    ########  ######    ######     ##    ##     ## ########  ######
    ##    ##   ##   ##             ##    ##    ##     ## ##   ##   ##
    ##    ##    ##  ##       ##    ##    ##    ##     ## ##    ##  ##
    ##    ##     ## ########  ######     ##     #######  ##     ## ########

    describe '::serialize', ->
      it 'serializes the cursor', ->
        expect(cursor.serialize()).toEqual(cursor.position.serialize())
