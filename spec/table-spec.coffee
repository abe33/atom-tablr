{Point} = require 'atom'
Table = require '../lib/table'
Column = require '../lib/column'
Row = require '../lib/row'
Cell = require '../lib/cell'

describe 'Table', ->
  [table, row, column, spy] = []
  beforeEach ->
    table = new Table

  it 'has 0 columns', ->
    expect(table.getColumnsCount()).toEqual(0)

  it 'has 0 rows', ->
    expect(table.getRowsCount()).toEqual(0)

  it 'has 0 cells', ->
    expect(table.getCellsCount()).toEqual(0)

  describe 'adding a row on a table without columns', ->
    it 'raises an exception', ->
      expect(-> table.addRow {}).toThrow()

  #     ######   #######  ##       ##     ## ##     ## ##    ##  ######
  #    ##    ## ##     ## ##       ##     ## ###   ### ###   ## ##    ##
  #    ##       ##     ## ##       ##     ## #### #### ####  ## ##
  #    ##       ##     ## ##       ##     ## ## ### ## ## ## ##  ######
  #    ##       ##     ## ##       ##     ## ##     ## ##  ####       ##
  #    ##    ## ##     ## ##       ##     ## ##     ## ##   ### ##    ##
  #     ######   #######  ########  #######  ##     ## ##    ##  ######

  describe 'with columns added to the table', ->
    beforeEach ->
      table.addColumn('key')
      column = table.addColumn('value', default: 'empty')

    it 'has 2 columns', ->
      expect(table.getColumnsCount()).toEqual(2)

    it 'returns the created column', ->
      expect(column).toEqual(table.getColumn(1))

    it 'creates the column with a single object', ->
      column = table.addColumn(name: 'foo', default: 'empty')
      expect(table.getColumnsCount()).toEqual(3)
      expect(column).toEqual(table.getColumn(2))

    it 'raises an exception if the column does not have a name', ->
      expect(-> table.addColumn({})).toThrow()

    it 'raises an exception when adding a column whose name already exist in table', ->
      expect(-> table.addColumn('key')).toThrow()

    describe 'when there is already rows in the table', ->
      beforeEach ->
        row = table.addRow key: 'foo', value: 'bar'
        table.addRow key: 'oof', value: 'rab'

      describe 'adding a column', ->
        it 'extend all the rows with a new cell', ->
          table.addColumn 'required', default: false

          expect(row.getCellsCount()).toEqual(3)

        it 'dispatches a did-add-column event', ->
          spy = jasmine.createSpy 'addColumn'

          table.onDidAddColumn spy
          table.addColumn 'required'

          expect(spy).toHaveBeenCalled()

      describe 'adding a column at a given index', ->
        beforeEach ->
          column = table.addColumnAt 1, 'required', default: false

        it 'adds the column at the right place', ->
          expect(table.getColumnsCount()).toEqual(3)
          expect(table.getColumn(1)).toEqual(column)
          expect(table.getColumn(2).name).toEqual('value')

        it 'extend the existing rows at the right place', ->
          expect(table.getRow(0).getCellsCount()).toEqual(3)
          expect(table.getRow(1).getCellsCount()).toEqual(3)

          expect(row.getCell(1).getColumn()).toEqual(column)
          expect(row.getCell(2).getColumn().name).toEqual('value')

        it 'throws an error if the index is negative', ->
          expect(-> table.addColumnAt -1, 'foo').toThrow()

    describe 'removing a column', ->
      describe 'when there is alredy rows in the table', ->
        beforeEach ->
          spy = jasmine.createSpy 'removeColumn'

          table.addRow key: 'foo', value: 'bar'
          table.addRow key: 'oof', value: 'rab'

          table.onDidRemoveColumn spy
          table.removeColumn(column)

        it 'removes the column', ->
          expect(table.getColumnsCount()).toEqual(1)

        it 'dispatches a did-add-column event', ->
          expect(spy).toHaveBeenCalled()

        it 'removes the corresponding row cell', ->
          expect(table.getRow(0).getCellsCount()).toEqual(1)
          expect(table.getRow(1).getCellsCount()).toEqual(1)

        it 'removes the rows accessors for the column', ->
          descriptor = Object.getOwnPropertyDescriptor(table.getRow(0), 'value')
          expect(descriptor).toBeUndefined()

      it 'throws an exception when the column is undefined', ->
        expect(-> table.removeColumn()).toThrow()

      it 'throws an exception when the column is not in the table', ->
        expect(-> table.removeColumn({})).toThrow()

      it 'throws an error with a negative index', ->
        expect(-> table.removeColumnAt(-1)).toThrow()

      it 'throws an error with an index greater that the columns count', ->
        expect(-> table.removeColumnAt(2)).toThrow()

    describe 'changing a column name', ->
      beforeEach ->
        row = table.addRow key: 'foo', value: 'bar'
        table.addRow key: 'oof', value: 'rab'

        column.name = 'content'

      it 'changes the accessors on the existing rows', ->
        oldDescriptor = Object.getOwnPropertyDescriptor(row, 'value')

        expect(oldDescriptor).toBeUndefined()
        expect(row.content).toEqual('bar')

    #    ########   #######  ##      ##  ######
    #    ##     ## ##     ## ##  ##  ## ##    ##
    #    ##     ## ##     ## ##  ##  ## ##
    #    ########  ##     ## ##  ##  ##  ######
    #    ##   ##   ##     ## ##  ##  ##       ##
    #    ##    ##  ##     ## ##  ##  ## ##    ##
    #    ##     ##  #######   ###  ###   ######

    describe 'adding a row', ->
      describe 'with an object', ->
        it 'creates a row with a cell for each value', ->
          row = table.addRow key: 'foo', value: 'bar'

          expect(table.getRowsCount()).toEqual(1)
          expect(table.getRow(0)).toBe(row)
          expect(row.key).toEqual('foo')
          expect(row.value).toEqual('bar')

        it 'dispatches a did-add-row event', ->
          spy = jasmine.createSpy 'addRow'
          table.onDidAddRow spy
          table.addRow key: 'foo', value: 'bar'

          expect(spy).toHaveBeenCalled()

        it 'dispatches a did-change-rows event', ->
          spy = jasmine.createSpy 'changeRows'
          table.onDidChangeRows spy
          table.addRow key: 'foo', value: 'bar'

          expect(spy).toHaveBeenCalled()
          expect(spy.calls[0].args[0]).toEqual({
            oldRange: {start: 0, end: 0}
            newRange: {start: 0, end: 1}
          })

        it "uses the column default when the value isn't provided", ->
          row = table.addRow {}

          expect(row.key).toBeNull()
          expect(row.value).toEqual('empty')

        it 'ignores data that not match any column', ->
          row = table.addRow key: 'foo', data: 'fooo'

          expect(row.key).toEqual('foo')
          expect(row.data).toBeUndefined()

        describe 'at a specified index', ->
          beforeEach ->
            table.addRow key: 'foo', value: 'bar'
            table.addRow key: 'oof', value: 'rab'

          it 'inserts the row at the specified position', ->
            table.addRowAt(1, key: 'hello', value: 'world')

            expect(table.getRowsCount()).toEqual(3)
            expect(table.getRow(1).key).toEqual('hello')
            expect(table.getRow(1).value).toEqual('world')

          it 'throws an error if the index is negative', ->
            expect(-> table.addRowAt -1, {}).toThrow()

          it 'dispatches a did-change-rows event', ->
            spy = jasmine.createSpy 'changeRows'
            table.onDidChangeRows spy
            table.addRowAt(1, key: 'hello', value: 'world')

            expect(spy).toHaveBeenCalled()
            expect(spy.calls[0].args[0]).toEqual({
              oldRange: {start: 1, end: 1}
              newRange: {start: 1, end: 2}
            })

      describe 'with an array', ->
        it 'creates a row with a cell for each value', ->
          row = table.addRow ['foo', 'bar']

          expect(table.getRowsCount()).toEqual(1)
          expect(table.getRow(0)).toBe(row)
          expect(row.key).toEqual('foo')
          expect(row.value).toEqual('bar')

        it "uses the column default when the value isn't provided", ->
          row = table.addRow []

          expect(row.key).toBeNull()
          expect(row.value).toEqual('empty')

        describe 'at a specified index', ->
          beforeEach ->
            table.addRow ['foo', 'bar']
            table.addRow ['oof', 'rab']

          it 'inserts the row at the specified position', ->
            table.addRowAt(1, ['hello', 'world'])

            expect(table.getRowsCount()).toEqual(3)
            expect(table.getRow(1).key).toEqual('hello')
            expect(table.getRow(1).value).toEqual('world')

    describe 'adding many rows', ->
      beforeEach ->
        spy = jasmine.createSpy 'changeRows'
        table.onDidChangeRows spy
        table.addRows [
          { key: 'foo', value: 'bar' }
          { key: 'oof', value: 'rab' }
        ]

      it 'adds the rows in the table', ->
        expect(table.getRowsCount()).toEqual(2)

      it 'dispatch only one did-change-rows event', ->
        expect(spy).toHaveBeenCalled()
        expect(spy.calls.length).toEqual(1)
        expect(spy.calls[0].args[0]).toEqual({
          oldRange: {start: 0, end: 0}
          newRange: {start: 0, end: 2}
        })

      describe 'at a given index', ->
        beforeEach ->
          spy = jasmine.createSpy 'changeRows'
          table.onDidChangeRows spy
          table.addRowsAt 1, [
            { key: 'foo', value: 'bar' }
            { key: 'oof', value: 'rab' }
          ]

        it 'adds the rows in the table', ->
          expect(table.getRowsCount()).toEqual(4)

        it 'dispatch only one did-change-rows event', ->
          expect(spy).toHaveBeenCalled()
          expect(spy.calls.length).toEqual(1)
          expect(spy.calls[0].args[0]).toEqual({
            oldRange: {start: 1, end: 1}
            newRange: {start: 1, end: 3}
          })

    describe 'removing a row', ->
      beforeEach ->
        spy = jasmine.createSpy 'removeRow'

        row = table.addRow key: 'foo', value: 'bar'
        table.addRow key: 'oof', value: 'rab'

        table.onDidRemoveRow spy

      it 'removes the row', ->
        table.removeRow(row)
        expect(table.getRowsCount()).toEqual(1)

      it 'dispatches a did-remove-row event', ->
        table.removeRow(row)
        expect(spy).toHaveBeenCalled()

      it 'dispatches a did-change-rows event', ->
        spy = jasmine.createSpy 'changeRows'
        table.onDidChangeRows spy
        table.removeRow(row)

        expect(spy).toHaveBeenCalled()
        expect(spy.calls[0].args[0]).toEqual({
          oldRange: {start: 0, end: 1}
          newRange: {start: 0, end: 0}
        })

      it 'throws an exception when the row is undefined', ->
        expect(-> table.removeRow()).toThrow()

      it 'throws an exception when the row is not in the table', ->
        expect(-> table.removeRow({})).toThrow()

      it 'throws an error with a negative index', ->
        expect(-> table.removeRowAt(-1)).toThrow()

      it 'throws an error with an index greater that the rows count', ->
        expect(-> table.removeRowAt(2)).toThrow()

    describe 'removing many rows', ->
      beforeEach ->
        table.addRow key: 'foo', value: 'bar'
        table.addRow key: 'oof', value: 'rab'
        table.addRow key: 'ofo', value: 'arb'

        spy = jasmine.createSpy 'removeRows'

        table.onDidChangeRows spy

        table.removeRowsInRange([0,2])

      it 'removes the rows from the table', ->
        expect(table.getRowsCount()).toEqual(1)
        expect(table.getRow(0).key).toEqual('ofo')
        expect(table.getRow(0).value).toEqual('arb')

      it 'dispatches a single did-change-rows', ->
        expect(spy).toHaveBeenCalled()
        expect(spy.calls.length).toEqual(1)
        expect(spy.calls[0].args[0]).toEqual({
          oldRange: {start: 0, end: 2}
          newRange: {start: 0, end: 0}
        })

    describe '::removeRowsInRange', ->
      it 'throws an error without range', ->
        expect(-> table.removeRowsInRange()).toThrow()

      it 'throws an error with an invalid range', ->
        expect(-> table.removeRowsInRange {start: 1}).toThrow()
        expect(-> table.removeRowsInRange [1]).toThrow()

  #     ######  ######## ##       ##        ######
  #    ##    ## ##       ##       ##       ##    ##
  #    ##       ##       ##       ##       ##
  #    ##       ######   ##       ##        ######
  #    ##       ##       ##       ##             ##
  #    ##    ## ##       ##       ##       ##    ##
  #     ######  ######## ######## ########  ######

  describe '::cellAtPosition', ->
    beforeEach ->
      table.addColumn('name')
      table.addColumn('age')

      table.addRow(['John Doe', 30])
      table.addRow(['Jane Doe', 30])

    it 'returns the cell at the given position array', ->
      expect(table.cellAtPosition([1,0]).getValue()).toEqual('Jane Doe')

    it 'returns the cell at the given position object', ->
      expect(table.cellAtPosition(row: 1, column: 0).getValue()).toEqual('Jane Doe')

    it 'throws an error without a position', ->
      expect(-> table.cellAtPosition()).toThrow()

    it 'returns undefined with a position out of bounds', ->
      expect(table.cellAtPosition(row: 2, column: 0)).toBeUndefined()
      expect(table.cellAtPosition(row: 0, column: 2)).toBeUndefined()

  describe '::positionOfCell', ->
    beforeEach ->
      table.addColumn('name')
      table.addColumn('age')

      table.addRow(['John Doe', 30])
      table.addRow(['Jane Doe', 30])

    it 'returns the position of the cell', ->
      cell = table.cellAtPosition([1,1])

      expect(table.positionOfCell(cell)).toEqual(row: 1, column: 1)

    it 'throws an error without a cell', ->
      expect(-> table.positionOfCell()).toThrow()

  #    ##     ## ##    ## ########   #######
  #    ##     ## ###   ## ##     ## ##     ##
  #    ##     ## ####  ## ##     ## ##     ##
  #    ##     ## ## ## ## ##     ## ##     ##
  #    ##     ## ##  #### ##     ## ##     ##
  #    ##     ## ##   ### ##     ## ##     ##
  #     #######  ##    ## ########   #######

  describe 'transactions', ->
    it 'drops old transactions when reaching the size limit', ->
      Table.MAX_HISTORY_SIZE = 10

      table.addColumn('foo')

      table.addRow ["foo#{i}"] for i in [0...20]

      expect(table.undoStack.length).toEqual(10)

      table.undo()

      expect(table.getLastRow().foo).toEqual('foo18')

    it 'rolls back a column addition', ->
      table.addColumn('key')

      table.undo()

      expect(table.getColumnsCount()).toEqual(0)
      expect(table.undoStack.length).toEqual(0)
      expect(table.redoStack.length).toEqual(1)

      table.redo()

      expect(table.undoStack.length).toEqual(1)
      expect(table.redoStack.length).toEqual(0)
      expect(table.getColumnsCount()).toEqual(1)
      expect(table.getColumn(0).name).toEqual('key')

    it 'rolls back a column deletion', ->
      column = table.addColumn('key')

      table.addRow(['foo'])
      table.addRow(['bar'])
      table.addRow(['baz'])
      table.clearUndoStack()

      table.removeColumn(column)

      table.undo()

      expect(table.getColumnsCount()).toEqual(1)
      expect(table.undoStack.length).toEqual(0)
      expect(table.redoStack.length).toEqual(1)
      expect(table.getColumn(0).name).toEqual('key')
      expect(table.getRow(0).getValues()).toEqual(['foo'])
      expect(table.getRow(1).getValues()).toEqual(['bar'])
      expect(table.getRow(2).getValues()).toEqual(['baz'])

      table.redo()

      expect(table.undoStack.length).toEqual(1)
      expect(table.redoStack.length).toEqual(0)
      expect(table.getColumnsCount()).toEqual(0)

    describe 'with columns in the table', ->
      beforeEach ->
        table.addColumn('key')
        column = table.addColumn('value', default: 'empty')

      it 'rolls back a row addition', ->
        table.clearUndoStack()

        row = table.addRow ['foo', 'bar'], height: 100

        table.undo()

        expect(table.getRowsCount()).toEqual(0)
        expect(table.undoStack.length).toEqual(0)
        expect(table.redoStack.length).toEqual(1)

        table.redo()

        expect(table.undoStack.length).toEqual(1)
        expect(table.redoStack.length).toEqual(0)
        expect(table.getRowsCount()).toEqual(1)
        expect(table.getRow(0).key).toEqual('foo')
        expect(table.getRow(0).value).toEqual('bar')
        expect(table.getRow(0).height).toEqual(100)

      it 'rolls back a batched rows addition', ->
        table.clearUndoStack()

        rows = table.addRows [
          ['foo', 'bar']
          ['bar', 'baz']
        ], [
          {height: 50}
          {height: 100}
        ]

        table.undo()

        expect(table.getRowsCount()).toEqual(0)
        expect(table.undoStack.length).toEqual(0)
        expect(table.redoStack.length).toEqual(1)

        table.redo()

        expect(table.undoStack.length).toEqual(1)
        expect(table.redoStack.length).toEqual(0)
        expect(table.getRowsCount()).toEqual(2)
        expect(table.getRow(0).key).toEqual('foo')
        expect(table.getRow(0).value).toEqual('bar')
        expect(table.getRow(0).height).toEqual(50)
        expect(table.getRow(1).key).toEqual('bar')
        expect(table.getRow(1).value).toEqual('baz')
        expect(table.getRow(1).height).toEqual(100)

      it 'rolls back a row deletion', ->
        row = table.addRow ['foo', 'bar']
        row.height = 100

        table.clearUndoStack()

        table.removeRowAt(0)

        table.undo()

        expect(table.getRowsCount()).toEqual(1)
        expect(table.undoStack.length).toEqual(0)
        expect(table.redoStack.length).toEqual(1)
        expect(table.getRow(0).key).toEqual('foo')
        expect(table.getRow(0).value).toEqual('bar')
        expect(table.getRow(0).height).toEqual(100)

        table.redo()

        expect(table.undoStack.length).toEqual(1)
        expect(table.redoStack.length).toEqual(0)
        expect(table.getRowsCount()).toEqual(0)

      it 'rolls back a batched rows deletion', ->
        rows = table.addRows [
          ['foo', 'bar']
          ['bar', 'baz']
        ]

        rows[0].height = 50
        rows[1].height = 100

        table.clearUndoStack()

        table.removeRowsInRange([0,2])

        table.undo()

        expect(table.getRowsCount()).toEqual(2)
        expect(table.undoStack.length).toEqual(0)
        expect(table.redoStack.length).toEqual(1)
        expect(table.getRow(0).key).toEqual('foo')
        expect(table.getRow(0).value).toEqual('bar')
        expect(table.getRow(0).height).toEqual(50)
        expect(table.getRow(1).key).toEqual('bar')
        expect(table.getRow(1).value).toEqual('baz')
        expect(table.getRow(1).height).toEqual(100)

        table.redo()

        expect(table.undoStack.length).toEqual(1)
        expect(table.redoStack.length).toEqual(0)
        expect(table.getRowsCount()).toEqual(0)

      it 'rolls back a change in a column', ->
        table.clearUndoStack()

        column.name = 'foo'

        table.undo()

        expect(column.name).toEqual('value')

        expect(table.undoStack.length).toEqual(0)
        expect(table.redoStack.length).toEqual(1)

        table.redo()

        expect(column.name).toEqual('foo')

        expect(table.undoStack.length).toEqual(1)
        expect(table.redoStack.length).toEqual(0)

      it 'rolls back a change in a row data', ->
        table.addRows [
          ['foo', 'bar']
          ['bar', 'baz']
        ]

        table.clearUndoStack()

        row = table.getRow(0)
        row.key = 'hello'

        table.undo()

        expect(table.undoStack.length).toEqual(0)
        expect(table.redoStack.length).toEqual(1)

        expect(row.key).toEqual('foo')

        table.redo()

        expect(table.undoStack.length).toEqual(1)
        expect(table.redoStack.length).toEqual(0)

        expect(row.key).toEqual('hello')

      it 'rolls back a change in a row options', ->
        table.addRows [
          ['foo', 'bar']
          ['bar', 'baz']
        ]

        table.clearUndoStack()

        row = table.getRow(0)
        row.height = 100

        table.undo()

        expect(table.undoStack.length).toEqual(0)
        expect(table.redoStack.length).toEqual(1)

        expect(row.height).toEqual(undefined)

        table.redo()

        expect(table.undoStack.length).toEqual(1)
        expect(table.redoStack.length).toEqual(0)

        expect(row.height).toEqual(100)

      it 'rolls back a change in a cell data', ->
        table.addRows [
          ['foo', 'bar']
          ['bar', 'baz']
        ]

        table.clearUndoStack()

        cell = table.cellAtPosition([0, 0])

        cell.setValue 'hello'

        table.undo()

        expect(table.undoStack.length).toEqual(0)
        expect(table.redoStack.length).toEqual(1)

        expect(cell.getValue()).toEqual('foo')

        table.redo()

        expect(table.undoStack.length).toEqual(1)
        expect(table.redoStack.length).toEqual(0)

        expect(cell.getValue()).toEqual('hello')

      describe '::clearUndoStack', ->
        it 'removes all the transactions in the undo stack', ->
          table.addRows [
            ['foo', 'bar']
            ['bar', 'baz']
          ]

          cell = table.cellAtPosition([0, 0])

          cell.setValue 'hello'

          table.undo()

          table.clearUndoStack()

          expect(table.undoStack.length).toEqual(0)

      describe '::clearRedoStack', ->
        it 'removes all the transactions in the redo stack', ->
          table.addRows [
            ['foo', 'bar']
            ['bar', 'baz']
          ]

          cell = table.cellAtPosition([0, 0])

          cell.setValue 'hello'

          table.undo()

          table.clearRedoStack()

          expect(table.redoStack.length).toEqual(0)
