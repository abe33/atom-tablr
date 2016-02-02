require './helpers/spec-helper'

{Point} = require 'atom'
TableEditor = require '../lib/table-editor'
Table = require '../lib/table'
Selection = require '../lib/selection'
Cursor = require '../lib/cursor'
Range = require '../lib/range'

describe 'Selection', ->
  [table, displayTable, tableEditor, selection, cursor] = []

  beforeEach ->
    atom.config.set 'tablr.tableEditor.columnWidth', 100
    atom.config.set 'tablr.minimuColumnWidth', 10
    atom.config.set 'tablr.tableEditor.rowHeight', 20
    atom.config.set 'tablr.tableEditor.minimumRowHeight', 10

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

    it 'has empty bounds', ->
      expect(selection.bounds()).toEqual({
        top: 1
        bottom: 1
        left: 1
        right: 1
      })

    it 'has an empty value', ->
      expect(selection.getValue()).toEqual([])

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

    it 'has the corresponding bounds', ->
      expect(selection.bounds()).toEqual({
        top: 1
        bottom: 2
        left: 1
        right: 2
      })

    it 'has a single value', ->
      expect(selection.getValue()).toEqual([['female']])

  describe 'that spans many cells', ->
    beforeEach ->
      cursor = new Cursor({tableEditor, position: new Point(1,1)})
      range = new Range([1,1], [3,2])
      selection = new Selection({cursor, range, tableEditor})

    it 'is not empty', ->
      expect(selection.isEmpty()).toBeFalsy()

    it 'spans several cells', ->
      expect(selection.spanMoreThanOneCell()).toBeTruthy()

    it 'has the corresponding bounds', ->
      expect(selection.bounds()).toEqual({
        top: 1
        bottom: 3
        left: 1
        right: 2
      })

    it 'has multiple values', ->
      expect(selection.getValue()).toEqual([
        ['female']
        ['Jane Doe']
      ])

  describe '::setRange', ->
    it 'sets the selection range', ->
      selection.setRange([[0,0],[2,2]])

      expect(selection.getRange()).toEqual([[0,0],[2,2]])

    it 'changes the cursor position if it is no longer contained', ->
      selection.setRange([[0,0],[1,3]])

      expect(selection.getRange()).toEqual([[0,0],[1,3]])
      expect(selection.getCursor().getPosition()).toEqual([0,0])

  describe 'moving with', ->
    beforeEach ->
      cursor = new Cursor({tableEditor, position: new Point(1,1)})
      range = cursor.getRange()
      selection = new Selection({cursor, range, tableEditor})

    describe '::expandLeft', ->
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

    describe '::expandToTop', ->
      it 'expands the selection to the top', ->
        selection.expandToTop()

        expect(selection.getRange()).toEqual([[0,1],[2,2]])

      it 'inverses the selection direction when expanded down', ->
        selection.expandDown()
        selection.expandToTop()

        expect(selection.getRange()).toEqual([[0,1],[2,2]])

    describe '::expandToBottom', ->
      it 'expands the selection to the bottom', ->
        selection.expandToBottom()

        expect(selection.getRange()).toEqual([[1,1],[3,2]])

      it 'inverses the selection direction when expanded down', ->
        selection.expandUp()
        selection.expandToBottom()

        expect(selection.getRange()).toEqual([[1,1],[3,2]])

    describe '::expandToLeft', ->
      it 'expands the selection to the left', ->
        selection.expandToLeft()

        expect(selection.getRange()).toEqual([[1,0],[2,2]])

      it 'inverses the selection direction when expanded on right', ->
        selection.expandRight()
        selection.expandToLeft()

        expect(selection.getRange()).toEqual([[1,0],[2,2]])

    describe '::expandToRight', ->
      it 'expands the selection to the right', ->
        selection.expandToRight()

        expect(selection.getRange()).toEqual([[1,1],[2,3]])

      it 'inverses the selection direction when expanded down', ->
        selection.expandLeft()
        selection.expandToRight()

        expect(selection.getRange()).toEqual([[1,1],[2,3]])

    describe '::selectAll', ->
      it 'selects the whole table range', ->
        selection.selectAll()

        expect(selection.getRange()).toEqual([[0,0],[3,3]])

    describe '::selectNone', ->
      it 'resets the range to the one of the cursor', ->
        selection.selectAll()
        selection.selectNone()

        expect(selection.getRange()).toEqual([[1,1],[2,2]])

    ##    ########  ########  ######  ########  #######  ########  ########
    ##    ##     ## ##       ##    ##    ##    ##     ## ##     ## ##
    ##    ##     ## ##       ##          ##    ##     ## ##     ## ##
    ##    ########  ######    ######     ##    ##     ## ########  ######
    ##    ##   ##   ##             ##    ##    ##     ## ##   ##   ##
    ##    ##    ##  ##       ##    ##    ##    ##     ## ##    ##  ##
    ##    ##     ## ########  ######     ##     #######  ##     ## ########

    describe '::serialize', ->
      it 'serializes the selection', ->
        expect(selection.serialize()).toEqual(selection.range.serialize())
