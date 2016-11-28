require './helpers/spec-helper'

DisplayTable = require '../lib/display-table'
Table = require '../lib/table'

describe 'DisplayTable', ->
  [table, displayTable] = []

  beforeEach ->
    atom.config.set 'tablr.tableEditor.columnWidth', 100
    atom.config.set 'tablr.minimuColumnWidth', 10
    atom.config.set 'tablr.tableEditor.rowHeight', 20
    atom.config.set 'tablr.tableEditor.minimumRowHeight', 10

  describe 'when initialized without a table', ->
    beforeEach ->
      displayTable = new DisplayTable
      {table} = displayTable

    it 'creates an empty table', ->
      expect(table).toBeDefined()

  describe 'when initialized with a table', ->
    beforeEach ->
      table = new Table

      table.addColumn 'key'
      table.addColumn 'value'

      table.addRow ['name', 'Jane Doe']
      table.addRow ['age', 30]
      table.addRow ['gender', 'female']

      displayTable = new DisplayTable({table})

    it 'uses the passed-in table', ->
      expect(displayTable.table).toBe(table)

    it 'can compute the table width and height using the defaults', ->
      expect(displayTable.getContentWidth()).toEqual(200)
      expect(displayTable.getContentHeight()).toEqual(60)

    describe 'when destroyed', ->
      beforeEach ->
        displayTable.destroy()

      it 'is destroyed', ->
        expect(displayTable.isDestroyed()).toBeTruthy()

      it 'clears its screen columns', ->
        expect(displayTable.getScreenColumnCount()).toEqual(0)
        expect(displayTable.getScreenRowCount()).toEqual(0)
        expect(displayTable.rowOffsets).toEqual([])
        expect(displayTable.columnOffsets).toEqual([])

    describe 'when its table is destroyed', ->
      it 'is destroyed', ->
        table.destroy()

        expect(displayTable.isDestroyed()).toBeTruthy()

    ##    ########  ########  ######  ########  #######  ########  ########
    ##    ##     ## ##       ##    ##    ##    ##     ## ##     ## ##
    ##    ##     ## ##       ##          ##    ##     ## ##     ## ##
    ##    ########  ######    ######     ##    ##     ## ########  ######
    ##    ##   ##   ##             ##    ##    ##     ## ##   ##   ##
    ##    ##    ##  ##       ##    ##    ##    ##     ## ##    ##  ##
    ##    ##     ## ########  ######     ##     #######  ##     ## ########

    describe '::serialize', ->
      it 'serializes the display table', ->
        expect(displayTable.serialize()).toEqual({
          deserializer: 'DisplayTable'
          table: displayTable.table.serialize()
          rowHeights: displayTable.rowHeights
        })

      it 'serializes the table order when defined', ->
        displayTable.sortBy('key', -1)

        expect(displayTable.serialize()).toEqual({
          deserializer: 'DisplayTable'
          table: displayTable.table.serialize()
          rowHeights: displayTable.rowHeights
          order: 0
          direction: -1
        })

    describe '.deserialize', ->
      it 'creates a display table', ->
        displayTable = atom.deserializers.deserialize({
          deserializer: 'DisplayTable'
          rowHeights: [100,null]
          order: 0
          direction: 1
          table:
            deserializer: 'Table'
            columns: ['foo', 'bar']
            rows: [
              ['z',2]
              ['a',4]
            ]
            id: 1
        })

        expect(displayTable.getScreenRowCount()).toEqual(2)
        expect(displayTable.getScreenRows()).toEqual([
          ['a',4]
          ['z',2]
        ])
        expect(displayTable.getScreenRowHeightAt(1)).toEqual(100)
        expect(displayTable.getScreenRowHeightAt(0)).toEqual(20)

    ##      ######   #######  ##       ##     ## ##     ## ##    ##  ######
    ##     ##    ## ##     ## ##       ##     ## ###   ### ###   ## ##    ##
    ##     ##       ##     ## ##       ##     ## #### #### ####  ## ##
    ##     ##       ##     ## ##       ##     ## ## ### ## ## ## ##  ######
    ##     ##       ##     ## ##       ##     ## ##     ## ##  ####       ##
    ##     ##    ## ##     ## ##       ##     ## ##     ## ##   ### ##    ##
    ##      ######   #######  ########  #######  ##     ## ##    ##  ######

    it 'builds screen columns objects for each columns in the table', ->
      expect(displayTable.getScreenColumns().length).toEqual(2)

      column = displayTable.getScreenColumn(0)
      expect(column.width).toEqual(100)
      expect(column.align).toEqual('left')
      expect(column.grammarScope).toEqual('text.plain.null-grammar')

    it 'computes the columns offset', ->
      expect(displayTable.getScreenColumnOffsetAt(0)).toEqual(0)
      expect(displayTable.getScreenColumnOffsetAt(1)).toEqual(100)

    it 'returns the column at given screen position', ->
      expect(displayTable.getScreenColumnIndexAtPixelPosition(120)).toEqual(1)

    describe 'adding a column', ->
      describe 'at the end of the row', ->
        beforeEach ->
          displayTable.addColumn('locked')

        it 'creates a new screen column for it', ->
          expect(displayTable.getScreenColumns().length).toEqual(3)
          expect(displayTable.getScreenColumn(2).name).toEqual('locked')

        it 'computes the new column offset', ->
          expect(displayTable.getScreenColumnOffsetAt(2)).toEqual(200)

        it 'computes the new content width', ->
          expect(displayTable.getContentWidth()).toEqual(300)

      describe 'with an option object', ->
        beforeEach ->
          displayTable.addColumn('locked', width: 200, align: 'right', grammarScope: 'source.js')

        it 'creates a new screen column with the given options', ->
          expect(displayTable.getScreenColumns().length).toEqual(3)
          expect(displayTable.getScreenColumn(2).name).toEqual('locked')
          expect(displayTable.getScreenColumn(2).width).toEqual(200)
          expect(displayTable.getScreenColumn(2).align).toEqual('right')
          expect(displayTable.getScreenColumn(2).grammarScope).toEqual('source.js')

      describe 'between two other columns', ->
        beforeEach ->
          displayTable.addColumnAt(1, 'locked')

        it 'creates a new screen column for it', ->
          expect(displayTable.getScreenColumns().length).toEqual(3)
          expect(displayTable.getScreenColumn(1).name).toEqual('locked')
          expect(displayTable.getScreenColumn(2).name).toEqual('value')

        it 'computes the new column offset', ->
          expect(displayTable.getScreenColumnOffsetAt(2)).toEqual(200)

        it 'returns the column at given screen position', ->
          expect(displayTable.getScreenColumnIndexAtPixelPosition(220)).toEqual(2)

        it 'computes the new content width', ->
          expect(displayTable.getContentWidth()).toEqual(300)

    describe 'removing a column', ->
      beforeEach ->
        displayTable.removeColumn('key')

      it 'removes the corresponding column', ->
        expect(displayTable.getScreenColumns().length).toEqual(1)
        expect(displayTable.getScreenColumn(0).name).toEqual('value')
        expect(displayTable.getScreenColumn(0).width).toEqual(100)

      it 'updates the offsets', ->
        expect(displayTable.getScreenColumnOffsetAt(0)).toEqual(0)

      it 'computes the new content width', ->
        expect(displayTable.getContentWidth()).toEqual(100)

    describe 'changing the name of the column', ->
      it 'updates the screen column name', ->
        displayTable.changeColumnName('key', 'foo')
        expect(displayTable.getScreenColumn(0).name).toEqual('foo')

    describe 'setting the width of a column', ->
      beforeEach ->
        displayTable.setScreenColumnWidthAt(0, 200)

      it 'updates the columns width', ->
        expect(displayTable.getScreenColumnWidthAt(0)).toEqual(200)

      it 'updates the columns offsets', ->
        expect(displayTable.getScreenColumnOffsetAt(0)).toEqual(0)
        expect(displayTable.getScreenColumnOffsetAt(1)).toEqual(200)

      it 'returns the column at given screen position', ->
        expect(displayTable.getScreenColumnIndexAtPixelPosition(180)).toEqual(0)
        expect(displayTable.getScreenColumnIndexAtPixelPosition(220)).toEqual(1)

      it 'computes the new content width', ->
        expect(displayTable.getContentWidth()).toEqual(300)

    ##     ########   #######  ##      ##  ######
    ##     ##     ## ##     ## ##  ##  ## ##    ##
    ##     ##     ## ##     ## ##  ##  ## ##
    ##     ########  ##     ## ##  ##  ##  ######
    ##     ##   ##   ##     ## ##  ##  ##       ##
    ##     ##    ##  ##     ## ##  ##  ## ##    ##
    ##     ##     ##  #######   ###  ###   ######

    it 'builds screen rows for each columns in the table', ->
      expect(displayTable.getScreenRows().length).toEqual(3)

      expect(displayTable.getRowHeightAt(0)).toEqual(20)
      expect(displayTable.getRowHeightAt(1)).toEqual(20)
      expect(displayTable.getRowHeightAt(2)).toEqual(20)

    it 'computes the rows offset', ->
      expect(displayTable.getScreenRowOffsetAt(0)).toEqual(0)
      expect(displayTable.getScreenRowOffsetAt(1)).toEqual(20)
      expect(displayTable.getScreenRowOffsetAt(2)).toEqual(40)

    it 'returns the rows at given screen position', ->
      expect(displayTable.getRowIndexAtPixelPosition(50)).toEqual(2)
      expect(displayTable.getScreenRowIndexAtPixelPosition(50)).toEqual(2)

    describe 'setting the height of a row', ->
      beforeEach ->
        displayTable.setRowHeightAt(1, 100)

      it 'updates the rows height', ->
        expect(displayTable.getRowHeightAt(1)).toEqual(100)

      it 'updates the rows offsets', ->
        expect(displayTable.getRowOffsetAt(0)).toEqual(0)
        expect(displayTable.getRowOffsetAt(1)).toEqual(20)
        expect(displayTable.getRowOffsetAt(2)).toEqual(120)

      it 'computes the new table height', ->
        expect(displayTable.getContentHeight()).toEqual(140)

    describe 'adding a row', ->
      describe 'at the end of the table', ->
        beforeEach ->
          displayTable.addRow(['blood type', 'ab-'])

        it 'updates the screen rows', ->
          expect(displayTable.getScreenRows().length).toEqual(4)
          expect(displayTable.getScreenRow(3)).toEqual(['blood type', 'ab-'])

        it 'updates the rows offsets', ->
          expect(displayTable.getRowOffsetAt(3)).toEqual(60)

        it 'computes the new table height', ->
          expect(displayTable.getContentHeight()).toEqual(80)

        it 'returns the rows at given screen position', ->
          expect(displayTable.getRowIndexAtPixelPosition(70)).toEqual(3)
          expect(displayTable.getScreenRowIndexAtPixelPosition(70)).toEqual(3)

        it 'emits a did-add-row event with the screen row position', ->
          spy = jasmine.createSpy('did-add-row')

          displayTable.onDidAddRow(spy)

          displayTable.addRow(['blood type', 'ab-'])

          expect(spy).toHaveBeenCalled()
          expect(spy.calls[0].args[0].screenIndex).toEqual(4)
          expect(spy.calls[0].args[0].index).toEqual(4)

        it 'emits a did-change event with the screen row range', ->
          spy = jasmine.createSpy('did-change')

          displayTable.onDidChange(spy)

          displayTable.addRow(['blood type', 'ab-'])

          expect(spy).toHaveBeenCalled()
          expect(spy.calls[0].args[0].oldRange).toEqual({start: 4, end: 4})
          expect(spy.calls[0].args[0].newRange).toEqual({start: 4, end: 5})
          # expect(spy.calls[0].args[0].oldScreenRange).toEqual({start: 4, end: 4})
          # expect(spy.calls[0].args[0].newScreenRange).toEqual({start: 4, end: 5})

      describe 'at the middle of the table', ->
        beforeEach ->
          displayTable.addRowAt(1, ['blood type', 'ab-'])

        it 'updates the screen rows', ->
          expect(displayTable.getScreenRows().length).toEqual(4)
          expect(displayTable.getScreenRow(1)).toEqual(['blood type', 'ab-'])
          expect(displayTable.getScreenRow(2)).toEqual(['age', 30])

        it 'updates the rows offsets', ->
          expect(displayTable.getRowOffsetAt(1)).toEqual(20)
          expect(displayTable.getRowOffsetAt(2)).toEqual(40)
          expect(displayTable.getRowOffsetAt(3)).toEqual(60)

        it 'computes the new table height', ->
          expect(displayTable.getContentHeight()).toEqual(80)

        it 'returns the rows at given screen position', ->
          expect(displayTable.getRowIndexAtPixelPosition(50)).toEqual(2)
          expect(displayTable.getScreenRowIndexAtPixelPosition(50)).toEqual(2)

        it 'emits a did-add-row event with the screen row position', ->
          spy = jasmine.createSpy('did-add-row')

          displayTable.onDidAddRow(spy)

          displayTable.addRowAt(1, ['blood type', 'ab-'])

          expect(spy).toHaveBeenCalled()
          expect(spy.calls[0].args[0].screenIndex).toEqual(1)
          expect(spy.calls[0].args[0].index).toEqual(1)

        it 'emits a did-change event with the screen row ranges', ->
          spy = jasmine.createSpy('did-change')

          displayTable.onDidChange(spy)

          displayTable.addRowAt(1, ['blood type', 'ab-'])

          expect(spy).toHaveBeenCalled()
          expect(spy.calls[0].args[0].oldRange).toEqual({start: 1, end: 1})
          expect(spy.calls[0].args[0].newRange).toEqual({start: 1, end: 2})
          # expect(spy.calls[0].args[0].oldScreenRange).toEqual({start: 1, end: 1})
          # expect(spy.calls[0].args[0].newScreenRange).toEqual({start: 1, end: 2})

      describe 'before a row with a height', ->
        beforeEach ->
          displayTable.setRowHeightAt(1, 100)
          displayTable.addRowAt(1, ['blood type', 'ab-'])

        it 'updates the screen rows', ->
          expect(displayTable.getScreenRows().length).toEqual(4)
          expect(displayTable.getScreenRow(1)).toEqual(['blood type', 'ab-'])
          expect(displayTable.getScreenRow(2)).toEqual(['age', 30])

        it 'updates the rows heights', ->
          expect(displayTable.getRowHeightAt(1)).toEqual(20)
          expect(displayTable.getRowHeightAt(2)).toEqual(100)

        it 'updates the rows offsets', ->
          expect(displayTable.getRowOffsetAt(1)).toEqual(20)
          expect(displayTable.getRowOffsetAt(2)).toEqual(40)
          expect(displayTable.getRowOffsetAt(3)).toEqual(140)

        it 'computes the new table height', ->
          expect(displayTable.getContentHeight()).toEqual(160)

      describe 'with an option object', ->
        beforeEach ->
          displayTable.addRowAt(1, ['blood type', 'ab-'], height: 100)

        it 'updates the screen rows', ->
          expect(displayTable.getScreenRows().length).toEqual(4)
          expect(displayTable.getScreenRow(1)).toEqual(['blood type', 'ab-'])
          expect(displayTable.getScreenRow(2)).toEqual(['age', 30])

        it 'updates the rows offsets', ->
          expect(displayTable.getRowOffsetAt(1)).toEqual(20)
          expect(displayTable.getRowOffsetAt(2)).toEqual(120)
          expect(displayTable.getRowOffsetAt(3)).toEqual(140)

        it 'computes the new table height', ->
          expect(displayTable.getContentHeight()).toEqual(160)

    describe 'adding many rows', ->
      beforeEach ->
        displayTable.addRowsAt(1, [['blood type', 'ab-'],['foo', 'bar']])

      it 'updates the screen rows', ->
        expect(displayTable.getScreenRows().length).toEqual(5)
        expect(displayTable.getScreenRow(1)).toEqual(['blood type', 'ab-'])
        expect(displayTable.getScreenRow(2)).toEqual(['foo', 'bar'])
        expect(displayTable.getScreenRow(3)).toEqual(['age', 30])

      it 'updates the rows offsets', ->
        expect(displayTable.getRowOffsetAt(1)).toEqual(20)
        expect(displayTable.getRowOffsetAt(2)).toEqual(40)
        expect(displayTable.getRowOffsetAt(3)).toEqual(60)
        expect(displayTable.getRowOffsetAt(4)).toEqual(80)

      it 'computes the new table height', ->
        expect(displayTable.getContentHeight()).toEqual(100)

    describe 'removing a row', ->
      beforeEach ->
        displayTable.removeRowAt(1)

      it 'updates the screen rows', ->
        expect(displayTable.getScreenRows().length).toEqual(2)
        expect(displayTable.getScreenRow(1)).toEqual(['gender', 'female'])

      it 'updates the rows offsets', ->
        expect(displayTable.getRowOffsetAt(1)).toEqual(20)

      it 'computes the new table height', ->
        expect(displayTable.getContentHeight()).toEqual(40)

    describe 'removing many rows', ->
      spy = null
      beforeEach ->
        spy = jasmine.createSpy('did-change')

        displayTable.addRowAt(1, ['blood type', 'ab-'])
        displayTable.onDidChange(spy)

        displayTable.removeRowsInRange([1,3])

      it 'updates the screen rows', ->
        expect(displayTable.getScreenRows().length).toEqual(2)
        expect(displayTable.getScreenRow(1)).toEqual(['gender', 'female'])

      it 'updates the rows offsets', ->
        expect(displayTable.getRowOffsetAt(1)).toEqual(20)

      it 'computes the new table height', ->
        expect(displayTable.getContentHeight()).toEqual(40)

    describe 'removing many rows in screen range', ->
      spy = null
      beforeEach ->
        spy = jasmine.createSpy('did-change')

        displayTable.addRowAt(1, ['blood type', 'ab-'])

      describe 'when a sort is applied', ->
        beforeEach ->
          displayTable.sortBy('key')

          displayTable.onDidChange(spy)

          displayTable.removeRowsInScreenRange([1,3])

        it 'updates the screen rows', ->
          expect(displayTable.getScreenRows().length).toEqual(2)
          expect(displayTable.getScreenRow(0)).toEqual(['age', 30])
          expect(displayTable.getScreenRow(1)).toEqual(['name', 'Jane Doe'])

        it 'updates the rows offsets', ->
          expect(displayTable.getScreenRowOffsetAt(0)).toEqual(0)
          expect(displayTable.getScreenRowOffsetAt(1)).toEqual(20)

        it 'computes the new table height', ->
          expect(displayTable.getContentHeight()).toEqual(40)

      describe 'when no sort is applied', ->
        beforeEach ->
          displayTable.onDidChange(spy)

          displayTable.removeRowsInScreenRange([1,3])

        it 'updates the screen rows', ->
          expect(displayTable.getScreenRows().length).toEqual(2)
          expect(displayTable.getScreenRow(0)).toEqual(['name', 'Jane Doe'])
          expect(displayTable.getScreenRow(1)).toEqual(['gender', 'female'])

        it 'updates the rows offsets', ->
          expect(displayTable.getScreenRowOffsetAt(0)).toEqual(0)
          expect(displayTable.getScreenRowOffsetAt(1)).toEqual(20)

        it 'computes the new table height', ->
          expect(displayTable.getContentHeight()).toEqual(40)

    describe 'when a sort is applied', ->
      it 'changes the rows order accordingly to the key values', ->
        displayTable.sortBy('key')

        expect(displayTable.getScreenRow(0)).toEqual(['age', 30])
        expect(displayTable.getScreenRow(1)).toEqual(['gender', 'female'])
        expect(displayTable.getScreenRow(2)).toEqual(['name', 'Jane Doe'])

      it 'returns the rows at given screen position', ->
        displayTable.sortBy('key')

        expect(displayTable.getRowIndexAtPixelPosition(10)).toEqual(1)
        expect(displayTable.getScreenRowIndexAtPixelPosition(10)).toEqual(0)

        expect(displayTable.getRowIndexAtPixelPosition(30)).toEqual(2)
        expect(displayTable.getScreenRowIndexAtPixelPosition(30)).toEqual(1)

        expect(displayTable.getRowIndexAtPixelPosition(50)).toEqual(0)
        expect(displayTable.getScreenRowIndexAtPixelPosition(50)).toEqual(2)

      describe 'and there is already some custom height defined', ->
        it 'keeps the relation between the model rows and the heights', ->
          displayTable.setRowHeightAt(0, 100)
          displayTable.setRowHeightAt(1, 50)

          displayTable.sortBy('key')

          expect(displayTable.getScreenRowHeightAt(0)).toEqual(50)
          expect(displayTable.getScreenRowHeightAt(1)).toEqual(20)
          expect(displayTable.getScreenRowHeightAt(2)).toEqual(100)

    describe '::applySort', ->
      describe 'when no sort is applied', ->
        it 'does nothing', ->
          displayTable.applySort()

          expect(displayTable.getRow(0)).toEqual(['name', 'Jane Doe'])
          expect(displayTable.getRow(1)).toEqual(['age', 30])
          expect(displayTable.getRow(2)).toEqual(['gender', 'female'])

      describe 'when a sort is applied', ->
        beforeEach ->
          displayTable.sortBy('key')
          displayTable.applySort()

        it 'modifies the table to match the sort', ->
          expect(displayTable.getRow(0)).toEqual(['age', 30])
          expect(displayTable.getRow(1)).toEqual(['gender', 'female'])
          expect(displayTable.getRow(2)).toEqual(['name', 'Jane Doe'])

          expect(displayTable.getScreenRow(0)).toEqual(['age', 30])
          expect(displayTable.getScreenRow(1)).toEqual(['gender', 'female'])
          expect(displayTable.getScreenRow(2)).toEqual(['name', 'Jane Doe'])

        it 'removes the current sort', ->
          expect(displayTable.order).toBeNull()

    ##     ######  ######## ##       ##        ######
    ##    ##    ## ##       ##       ##       ##    ##
    ##    ##       ##       ##       ##       ##
    ##    ##       ######   ##       ##        ######
    ##    ##       ##       ##       ##             ##
    ##    ##    ## ##       ##       ##       ##    ##
    ##     ######  ######## ######## ########  ######

    it 'computes the cell screen positions', ->
      expect(displayTable.getScreenCellPosition([0,0])).toEqual({
        top: 0, left: 0
      })

      expect(displayTable.getScreenCellPosition([1,1])).toEqual({
        top: 20, left: 100
      })

      expect(displayTable.getScreenCellPosition([2,1])).toEqual({
        top: 40, left: 100
      })

    it 'computes the cell screen rectangle', ->
      expect(displayTable.getScreenCellRect([0,0])).toEqual({
        top: 0, left: 0, width: 100, height: 20
      })

      expect(displayTable.getScreenCellRect([1,1])).toEqual({
        top: 20, left: 100, width: 100, height: 20
      })

      expect(displayTable.getScreenCellRect([2,1])).toEqual({
        top: 40, left: 100, width: 100, height: 20
      })

    it 'can return a cell position', ->
      modelPosition = displayTable.getPositionAtPixelPosition(150, 30)
      screenPosition = displayTable.getScreenPositionAtPixelPosition(150, 30)

      expect(modelPosition).toEqual([1,1])
      expect(screenPosition).toEqual([1,1])

    describe 'when the rows are sorted', ->
      beforeEach ->
        displayTable.sortBy('key')

      it 'can modify the proper table cell', ->
        displayTable.setValueAtScreenPosition([0,1], 20)

        expect(table.getRow(1)).toEqual(['age', 20])
        expect(displayTable.getScreenRow(0)).toEqual(['age', 20])

      it 'emits a did-change-cell-value event with screen position', ->
        spy = jasmine.createSpy('did-change-cell-value')

        displayTable.onDidChangeCellValue(spy)

        displayTable.setValueAtScreenPosition([0,1], 20)

        expect(spy).toHaveBeenCalled()
        expect(spy.calls[0].args[0].screenPosition).toEqual([0,1])
        expect(spy.calls[0].args[0].position).toEqual([1,1])

      it 'can return a cell position', ->
        modelPosition = displayTable.getPositionAtPixelPosition(150, 30)
        screenPosition = displayTable.getScreenPositionAtPixelPosition(150, 30)

        expect(modelPosition).toEqual([2,1])
        expect(screenPosition).toEqual([1,1])

    describe '::setValuesAtScreenPositions', ->
      beforeEach ->
        displayTable.sortBy('key')

      it 'modifies the proper table cells', ->
        displayTable.setValuesAtScreenPositions([[0,1], [1,1]], [20, 20])

        expect(table.getRow(1)).toEqual(['age', 20])
        expect(table.getRow(2)).toEqual(['gender', 20])

        expect(displayTable.getScreenRow(0)).toEqual(['age', 20])
        expect(displayTable.getScreenRow(1)).toEqual(['gender', 20])

      it 'emits a did-change-cell-value event with screen positions', ->
        spy = jasmine.createSpy('did-change-cell-value')

        displayTable.onDidChangeCellValue(spy)

        displayTable.setValuesAtScreenPositions([[0,1], [1,1]], [20, 20])

        expect(spy).toHaveBeenCalled()
        expect(spy.calls[0].args[0].screenPositions).toEqual([[0,1], [1,1]])
        expect(spy.calls[0].args[0].positions).toEqual([[1,1],[2,1]])

    describe '::setValuesInScreenRange', ->
      describe 'when a sort is applied', ->
        beforeEach ->
          displayTable.sortBy('key')

        it 'modifies the proper table cells', ->
          displayTable.setValuesInScreenRange([[0,1], [2,2]], [[20], [20]])

          expect(table.getRow(1)).toEqual(['age', 20])
          expect(table.getRow(2)).toEqual(['gender', 20])

          expect(displayTable.getScreenRow(0)).toEqual(['age', 20])
          expect(displayTable.getScreenRow(1)).toEqual(['gender', 20])

        it 'emits a did-change-cell-value', ->
          spy = jasmine.createSpy('did-change-cell-value')

          displayTable.onDidChangeCellValue(spy)

          displayTable.setValuesInScreenRange([[0,1], [2,2]], [[20], [20]])

          expect(spy).toHaveBeenCalled()

      describe 'when no sort is applied', ->
        it 'modifies the proper table cells', ->
          displayTable.setValuesInScreenRange([[0,1], [2,2]], [[20], [20]])

          expect(table.getRow(0)).toEqual(['name', 20])
          expect(table.getRow(1)).toEqual(['age', 20])

          expect(displayTable.getScreenRow(0)).toEqual(['name', 20])
          expect(displayTable.getScreenRow(1)).toEqual(['age', 20])

        it 'emits a did-change-cell-value', ->
          spy = jasmine.createSpy('did-change-cell-value')

          displayTable.onDidChangeCellValue(spy)

          displayTable.setValuesInScreenRange([[0,1], [2,2]], [[20], [20]])

          expect(spy).toHaveBeenCalled()


  ##    ##     ## ##    ## ########   #######
  ##    ##     ## ###   ## ##     ## ##     ##
  ##    ##     ## ####  ## ##     ## ##     ##
  ##    ##     ## ## ## ## ##     ## ##     ##
  ##    ##     ## ##  #### ##     ## ##     ##
  ##    ##     ## ##   ### ##     ## ##     ##
  ##     #######  ##    ## ########   #######

  describe 'transactions', ->
    beforeEach ->
      displayTable = new DisplayTable
      {table} = displayTable

    it 'rolls back a column addition', ->
      displayTable.addColumn('key', width: 200, align: 'right')

      displayTable.undo()

      expect(displayTable.getScreenColumnCount()).toEqual(0)
      expect(table.undoStack.length).toEqual(0)
      expect(table.redoStack.length).toEqual(1)

      displayTable.redo()

      expect(table.undoStack.length).toEqual(1)
      expect(table.redoStack.length).toEqual(0)
      expect(displayTable.getScreenColumnCount()).toEqual(1)
      expect(displayTable.getScreenColumn(0).name).toEqual('key')
      expect(displayTable.getScreenColumn(0).width).toEqual(200)
      expect(displayTable.getScreenColumn(0).align).toEqual('right')

    it 'rolls back a column deletion', ->
      displayTable.addColumn('key', width: 200, align: 'right')
      displayTable.addRow(['foo'])
      displayTable.addRow(['bar'])
      displayTable.addRow(['baz'])

      displayTable.clearUndoStack()

      displayTable.removeColumn('key')

      displayTable.undo()

      expect(table.undoStack.length).toEqual(0)
      expect(table.redoStack.length).toEqual(1)
      expect(displayTable.getScreenColumnCount()).toEqual(1)
      expect(displayTable.getScreenColumn(0).name).toEqual('key')
      expect(displayTable.getScreenColumn(0).width).toEqual(200)
      expect(displayTable.getScreenColumn(0).align).toEqual('right')

      expect(displayTable.getScreenRow(0)).toEqual(['foo'])
      expect(displayTable.getScreenRow(1)).toEqual(['bar'])
      expect(displayTable.getScreenRow(2)).toEqual(['baz'])

      displayTable.redo()

      expect(table.undoStack.length).toEqual(1)
      expect(table.redoStack.length).toEqual(0)
      expect(displayTable.getScreenColumnCount()).toEqual(0)

    it 'rolls back a row addition', ->
      displayTable.addColumn('key')
      displayTable.clearUndoStack()

      displayTable.addRow(['foo'], height: 200)

      displayTable.undo()

      expect(displayTable.getScreenRowCount()).toEqual(0)
      expect(table.undoStack.length).toEqual(0)
      expect(table.redoStack.length).toEqual(1)

      displayTable.redo()

      expect(table.undoStack.length).toEqual(1)
      expect(table.redoStack.length).toEqual(0)
      expect(displayTable.getScreenRowCount()).toEqual(1)
      expect(displayTable.getScreenRow(0)).toEqual(['foo'])
      expect(displayTable.getScreenRowHeightAt(0)).toEqual(200)

    it 'rolls back many rows addition', ->
      displayTable.addColumn('key')
      displayTable.clearUndoStack()

      displayTable.addRows([
        ['foo']
        ['bar']
      ], [
        {height: 200}
        {height: 400}
      ])

      expect(displayTable.getScreenRowHeightAt(0)).toEqual(200)
      expect(displayTable.getScreenRowHeightAt(1)).toEqual(400)

      displayTable.undo()

      expect(displayTable.getScreenRowCount()).toEqual(0)
      expect(table.undoStack.length).toEqual(0)
      expect(table.redoStack.length).toEqual(1)

      displayTable.redo()

      expect(table.undoStack.length).toEqual(1)
      expect(table.redoStack.length).toEqual(0)
      expect(displayTable.getScreenRowCount()).toEqual(2)
      expect(displayTable.getScreenRow(0)).toEqual(['foo'])
      expect(displayTable.getScreenRow(1)).toEqual(['bar'])
      expect(displayTable.getScreenRowHeightAt(0)).toEqual(200)
      expect(displayTable.getScreenRowHeightAt(1)).toEqual(400)

    it 'rolls back many rows deletion', ->
      displayTable.addColumn('key')

      displayTable.addRows([
        ['foo']
        ['bar']
      ], [
        {height: 200}
        {height: 400}
      ])

      displayTable.clearUndoStack()

      displayTable.removeRowsInRange([0,2])

      displayTable.undo()

      expect(table.undoStack.length).toEqual(0)
      expect(table.redoStack.length).toEqual(1)
      expect(displayTable.getScreenRowCount()).toEqual(2)
      expect(displayTable.getScreenRow(0)).toEqual(['foo'])
      expect(displayTable.getScreenRow(1)).toEqual(['bar'])
      expect(displayTable.getScreenRowHeightAt(0)).toEqual(200)
      expect(displayTable.getScreenRowHeightAt(1)).toEqual(400)

      displayTable.redo()

      expect(displayTable.getScreenRowCount()).toEqual(0)
      expect(table.undoStack.length).toEqual(1)
      expect(table.redoStack.length).toEqual(0)

    it 'rolls back many rows deletion with screen range', ->
      displayTable.addColumn 'key'
      displayTable.addColumn 'value'

      displayTable.addRow ['name', 'Jane Doe'], height: 200
      displayTable.addRow ['age', 30], height: 50
      displayTable.addRow ['gender', 'female'], height: 100
      displayTable.addRow ['blood type', 'ab-'], height: 50

      displayTable.clearUndoStack()

      displayTable.sortBy('key')

      displayTable.removeRowsInScreenRange([1,3])

      displayTable.undo()

      expect(displayTable.getScreenRowCount()).toEqual(4)
      expect(displayTable.getScreenRow(0)).toEqual(['age', 30])
      expect(displayTable.getScreenRow(1)).toEqual(['blood type', 'ab-'])
      expect(displayTable.getScreenRow(2)).toEqual(['gender', 'female'])
      expect(displayTable.getScreenRow(3)).toEqual(['name', 'Jane Doe'])
      expect(displayTable.getScreenRowHeightAt(0)).toEqual(50)
      expect(displayTable.getScreenRowHeightAt(1)).toEqual(50)
      expect(displayTable.getScreenRowHeightAt(2)).toEqual(100)
      expect(displayTable.getScreenRowHeightAt(3)).toEqual(200)
      expect(table.undoStack.length).toEqual(0)
      expect(table.redoStack.length).toEqual(1)

      displayTable.redo()

      expect(displayTable.getScreenRowCount()).toEqual(2)
      expect(displayTable.getScreenRow(0)).toEqual(['age', 30])
      expect(displayTable.getScreenRow(1)).toEqual(['name', 'Jane Doe'])
      expect(displayTable.getScreenRowHeightAt(0)).toEqual(50)
      expect(displayTable.getScreenRowHeightAt(1)).toEqual(200)
      expect(table.undoStack.length).toEqual(1)
      expect(table.redoStack.length).toEqual(0)

    it 'rolls back many rows deletion with screen range without sort', ->
      displayTable.addColumn 'key'
      displayTable.addColumn 'value'

      displayTable.addRow ['name', 'Jane Doe'], height: 200
      displayTable.addRow ['age', 30], height: 50
      displayTable.addRow ['gender', 'female'], height: 100
      displayTable.addRow ['blood type', 'ab-'], height: 50

      displayTable.clearUndoStack()

      displayTable.removeRowsInScreenRange([1,3])

      displayTable.undo()

      expect(displayTable.getScreenRowCount()).toEqual(4)
      expect(displayTable.getScreenRow(0)).toEqual(['name', 'Jane Doe'])
      expect(displayTable.getScreenRow(1)).toEqual(['age', 30])
      expect(displayTable.getScreenRow(2)).toEqual(['gender', 'female'])
      expect(displayTable.getScreenRow(3)).toEqual(['blood type', 'ab-'])
      expect(displayTable.getScreenRowHeightAt(0)).toEqual(200)
      expect(displayTable.getScreenRowHeightAt(1)).toEqual(50)
      expect(displayTable.getScreenRowHeightAt(2)).toEqual(100)
      expect(displayTable.getScreenRowHeightAt(3)).toEqual(50)
      expect(table.undoStack.length).toEqual(0)
      expect(table.redoStack.length).toEqual(1)

      displayTable.redo()

      expect(displayTable.getScreenRowCount()).toEqual(2)
      expect(displayTable.getScreenRow(0)).toEqual(['name', 'Jane Doe'])
      expect(displayTable.getScreenRow(1)).toEqual(['blood type', 'ab-'])
      expect(displayTable.getScreenRowHeightAt(0)).toEqual(200)
      expect(displayTable.getScreenRowHeightAt(1)).toEqual(50)
      expect(table.undoStack.length).toEqual(1)
      expect(table.redoStack.length).toEqual(0)

    it 'rolls back a row deletion', ->
      displayTable.addColumn('key')
      displayTable.addRow(['foo'], height: 200)
      displayTable.clearUndoStack()

      displayTable.removeRowAt(0)

      displayTable.undo()

      expect(displayTable.getScreenRowCount()).toEqual(1)
      expect(displayTable.getScreenRow(0)).toEqual(['foo'])
      expect(displayTable.getScreenRowHeightAt(0)).toEqual(200)
      expect(table.undoStack.length).toEqual(0)
      expect(table.redoStack.length).toEqual(1)

      displayTable.redo()

      expect(table.undoStack.length).toEqual(1)
      expect(table.redoStack.length).toEqual(0)
      expect(displayTable.getScreenRowCount()).toEqual(0)

    it 'rolls back a change in rows data with a sort applied', ->
      displayTable.addColumn 'key'
      displayTable.addColumn 'value'

      displayTable.addRow ['name', 'Jane Doe'], height: 200
      displayTable.addRow ['age', 30], height: 50
      displayTable.addRow ['gender', 'female'], height: 100
      displayTable.addRow ['blood type', 'ab-'], height: 50

      displayTable.sortBy('key')

      displayTable.clearUndoStack()

      displayTable.setValuesInScreenRange([[0,1], [2,2]], [[20], [20]])

      displayTable.undo()

      expect(table.getRow(1)).toEqual(['age', 30])
      expect(table.getRow(3)).toEqual(['blood type', 'ab-'])
      expect(displayTable.getScreenRow(0)).toEqual(['age', 30])
      expect(displayTable.getScreenRow(1)).toEqual(['blood type', 'ab-'])
      expect(table.undoStack.length).toEqual(0)
      expect(table.redoStack.length).toEqual(1)

      displayTable.redo()

      expect(table.getRow(1)).toEqual(['age', 20])
      expect(table.getRow(3)).toEqual(['blood type', 20])
      expect(displayTable.getScreenRow(0)).toEqual(['age', 20])
      expect(displayTable.getScreenRow(1)).toEqual(['blood type', 20])
      expect(table.undoStack.length).toEqual(1)
      expect(table.redoStack.length).toEqual(0)

    it 'rolls back a change in rows data with no sort applied', ->
      displayTable.addColumn 'key'
      displayTable.addColumn 'value'

      displayTable.addRow ['name', 'Jane Doe'], height: 200
      displayTable.addRow ['age', 30], height: 50
      displayTable.addRow ['gender', 'female'], height: 100
      displayTable.addRow ['blood type', 'ab-'], height: 50

      displayTable.clearUndoStack()

      displayTable.setValuesInScreenRange([[0,1], [2,2]], [[20], [20]])

      displayTable.undo()

      expect(table.getRow(0)).toEqual(['name', 'Jane Doe'])
      expect(table.getRow(1)).toEqual(['age', 30])
      expect(displayTable.getScreenRow(0)).toEqual(['name', 'Jane Doe'])
      expect(displayTable.getScreenRow(1)).toEqual(['age', 30])
      expect(table.undoStack.length).toEqual(0)
      expect(table.redoStack.length).toEqual(1)

      displayTable.redo()

      expect(table.getRow(0)).toEqual(['name', 20])
      expect(table.getRow(1)).toEqual(['age', 20])
      expect(displayTable.getScreenRow(0)).toEqual(['name', 20])
      expect(displayTable.getScreenRow(1)).toEqual(['age', 20])
      expect(table.undoStack.length).toEqual(1)
      expect(table.redoStack.length).toEqual(0)

    it 'rolls back a sort applied to the underlying table', ->
      displayTable.addColumn 'key'
      displayTable.addColumn 'value'

      displayTable.addRow ['name', 'Jane Doe'], height: 200
      displayTable.addRow ['age', 30], height: 50
      displayTable.addRow ['gender', 'female'], height: 100
      displayTable.addRow ['blood type', 'ab-'], height: 50

      displayTable.clearUndoStack()

      displayTable.sortBy('key')
      displayTable.applySort()

      displayTable.undo()

      expect(table.getRow(0)).toEqual(['name', 'Jane Doe'])
      expect(table.getRow(1)).toEqual(['age', 30])
      expect(table.getRow(2)).toEqual(['gender', 'female'])
      expect(table.getRow(3)).toEqual(['blood type', 'ab-'])

      expect(displayTable.getScreenRow(0)).toEqual(['age', 30])
      expect(displayTable.getScreenRow(1)).toEqual(['blood type', 'ab-'])
      expect(displayTable.getScreenRow(2)).toEqual(['gender', 'female'])
      expect(displayTable.getScreenRow(3)).toEqual(['name', 'Jane Doe'])

      expect(table.undoStack.length).toEqual(0)
      expect(table.redoStack.length).toEqual(1)

      expect(displayTable.order).toEqual(0)

      displayTable.redo()

      expect(table.getRow(0)).toEqual(['age', 30])
      expect(table.getRow(1)).toEqual(['blood type', 'ab-'])
      expect(table.getRow(2)).toEqual(['gender', 'female'])
      expect(table.getRow(3)).toEqual(['name', 'Jane Doe'])

      expect(displayTable.getScreenRow(0)).toEqual(['age', 30])
      expect(displayTable.getScreenRow(1)).toEqual(['blood type', 'ab-'])
      expect(displayTable.getScreenRow(2)).toEqual(['gender', 'female'])
      expect(displayTable.getScreenRow(3)).toEqual(['name', 'Jane Doe'])

      expect(table.undoStack.length).toEqual(1)
      expect(table.redoStack.length).toEqual(0)

      expect(displayTable.order).toBeNull()
