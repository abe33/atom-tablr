Table = require '../lib/table'
Column = require '../lib/column'
Row = require '../lib/row'
Cell = require '../lib/cell'

describe 'Table', ->
  [table, row, column] = []
  describe 'created without state', ->
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

    describe 'with columns added to the table', ->
      beforeEach ->
        table.addColumn('key')
        column = table.addColumn('value', default: 'empty')

      it 'has 2 columns', ->
        expect(table.getColumnsCount()).toEqual(2)

      it 'returns the created column', ->
        expect(column).toEqual(table.getColumn(1))

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

        describe 'adding a column at a given index', ->
          beforeEach ->
            column = table.addColumnAt 1, 'required', default: false

          it 'adds the column at the right place', ->
            expect(table.getColumn(1)).toEqual(column)
            expect(table.getColumn(2).name).toEqual('value')

          it 'extend the existing rows at the right place', ->
            expect(row.getCell(1).getColumn()).toEqual(column)
            expect(row.getCell(2).getColumn().name).toEqual('value')

          it 'throws an error if the index is negative', ->
            expect(-> table.addColumnAt -1, 'foo').toThrow()

      describe 'removing a column', ->
        describe 'when there is alredy rows in the table', ->
          beforeEach ->
            table.addRow key: 'foo', value: 'bar'
            table.addRow key: 'oof', value: 'rab'

            table.removeColumn(column)

          it 'removes the column', ->
            expect(table.getColumnsCount()).toEqual(1)

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

          column.setName('content')

        it 'changes the accessors on the existing rows', ->
          oldDescriptor = Object.getOwnPropertyDescriptor(row, 'value')

          expect(oldDescriptor).toBeUndefined()
          expect(row.content).toEqual('bar')

      describe 'adding a row', ->
        describe 'with an object', ->
          it 'creates a row with a cell for each value', ->
            row = table.addRow key: 'foo', value: 'bar'

            expect(table.getRowsCount()).toEqual(1)
            expect(table.getRow(0)).toBe(row)
            expect(row.key).toEqual('foo')
            expect(row.value).toEqual('bar')

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

      describe 'removing a row', ->
        beforeEach ->
          row = table.addRow key: 'foo', value: 'bar'
          table.addRow key: 'oof', value: 'rab'

        it 'removes the row', ->
          table.removeRow(row)
          expect(table.getRowsCount()).toEqual(1)

        it 'throws an exception when the row is undefined', ->
          expect(-> table.removeRow()).toThrow()

        it 'throws an exception when the row is not in the table', ->
          expect(-> table.removeRow({})).toThrow()

        it 'throws an error with a negative index', ->
          expect(-> table.removeRowAt(-1)).toThrow()

        it 'throws an error with an index greater that the rows count', ->
          expect(-> table.removeRowAt(2)).toThrow()
