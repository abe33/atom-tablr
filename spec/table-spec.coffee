Table = require '../lib/table'

describe 'Table', ->
  [table] = []
  describe 'created without state', ->
    beforeEach ->
      table = new Table

    it 'has 0 columns', ->
      expect(table.getColumns().length).toEqual(0)

    it 'has 0 rows', ->
      expect(table.getRows().length).toEqual(0)

    it 'has 0 cells', ->
      expect(table.getCells().length).toEqual(0)

    describe 'adding a row on a table without columns', ->
      it 'raises an exception', ->
        expect(-> table.addRow {}).toThrow()

    describe 'with columns added to the table', ->
      beforeEach ->
        table.addColumn('key')
        table.addColumn('value')

      it 'has 2 columns', ->
        expect(table.getColumns().length).toEqual(2)

      it 'raises an exception when adding a column whose name already exist in table', ->
        expect(-> table.addColumn('key')).toThrow()

      describe 'adding a row', ->
        describe 'with an object', ->
          it 'creates a row with a cell for each value', ->
            row = table.addRow key: 'foo', value: 'bar'

            expect(table.getRows().length).toEqual(1)
            expect(table.getRow(0)).toBe(row)
            expect(row.key).toEqual('foo')
            expect(row.value).toEqual('bar')

          it "creates empty cells when the value isn't provided", ->
            row = table.addRow key: 'foo'

            expect(row.key).toEqual('foo')
            expect(row.value).toBeNull()

          it 'ignores data not corresponding to a column', ->
            row = table.addRow key: 'foo', data: 'fooo'

            expect(row.key).toEqual('foo')
            expect(row.data).toBeUndefined()
