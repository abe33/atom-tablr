require './helpers/spec-helper'

{Point} = require 'atom'
Table = require '../lib/table'

describe 'Table', ->
  [table, row, column, spy] = []
  beforeEach ->
    table = new Table

  it 'has 0 columns', ->
    expect(table.getColumnCount()).toEqual(0)

  it 'has 0 rows', ->
    expect(table.getRowCount()).toEqual(0)

  it 'has 0 cells', ->
    expect(table.getCellCount()).toEqual(0)

  describe 'adding a row on a table without columns', ->
    it 'raises an exception', ->
      expect(-> table.addRow {}).toThrow()

  describe 'when destroyed', ->
    beforeEach ->
      table.addColumn('name')
      table.addColumn('age')

      table.addRow(['John Doe', 30])
      table.addRow(['Jane Doe', 30])

      table.destroy()

    it 'clears its content', ->
      expect(table.getRowCount()).toEqual(0)
      expect(table.getColumnCount()).toEqual(0)

    it 'throws an error when adding a row', ->
      expect(-> table.addRow(['foo'])).toThrow()
      expect(-> table.addRows([['foo']])).toThrow()

    it 'throws an error when adding a column', ->
      expect(-> table.addColumn('foo')).toThrow()

  describe '::retain', ->
    it 'increments the reference count', ->
      expect(table.refcount).toEqual(0)

      table.retain()

      expect(table.refcount).toEqual(1)
      expect(table.isRetained()).toBeTruthy()

      table.retain()

      expect(table.refcount).toEqual(2)

  describe '::release', ->
    it 'decrements the reference count', ->
      table.retain()
      table.retain()

      table.release()

      expect(table.refcount).toEqual(1)
      expect(table.isRetained()).toBeTruthy()

      table.release()

      expect(table.refcount).toEqual(0)
      expect(table.isRetained()).toBeFalsy()

    it 'destroys the table when the refcount drop to 0', ->
      spy = jasmine.createSpy('did-destroy')
      table.onDidDestroy(spy)
      table.retain()
      table.retain()

      table.release()
      table.release()

      expect(spy).toHaveBeenCalled()
      expect(table.isDestroyed()).toBeTruthy()

  #     ######     ###    ##     ## ########
  #    ##    ##   ## ##   ##     ## ##
  #    ##        ##   ##  ##     ## ##
  #     ######  ##     ## ##     ## ######
  #          ## #########  ##   ##  ##
  #    ##    ## ##     ##   ## ##   ##
  #     ######  ##     ##    ###    ########

  describe '::save', ->
    describe 'when modified', ->
      beforeEach ->
        table.addColumn('name')
        table.addColumn('age')

        table.addRow(['John Doe', 30])
        table.addRow(['Jane Doe', 30])

        expect(table.isModified()).toBeTruthy()

      it 'is marked as saved', ->
        table.save()

        expect(table.isModified()).toBeFalsy()

    describe 'with a synchronous save handler', ->
      it 'calls the handler on save', ->
        calls = []
        table.addColumn('age')
        table.setSaveHandler -> calls.push 'save'
        table.onDidSave -> calls.push 'did-save'

        table.save()

        expect(calls).toEqual(['save', 'did-save'])

      it 'marks the table as saved if the handler returned true', ->
        table.addColumn('age')
        table.setSaveHandler -> true
        table.save()

        expect(table.isModified()).toBeFalsy()

      it 'leaves the table as modified if the handler returned false', ->
        table.addColumn('age')
        table.setSaveHandler -> false
        table.save()

        expect(table.isModified()).toBeTruthy()

      describe 'when not modified', ->
        it 'does nothing', ->
          calls = []
          table.setSaveHandler -> calls.push 'save'
          table.onDidSave -> calls.push 'did-save'

          table.save()

          expect(calls).toEqual([])

    describe 'with an asynchronous save handler', ->
      promise = null
      it 'calls the handler on save', ->
        calls = []
        table.addColumn('age')
        table.setSaveHandler -> promise = new Promise (resolve) ->
          calls.push('save')
          resolve()
        table.onDidSave -> calls.push 'did-save'

        table.save()

        waitsForPromise -> promise

        runs -> expect(calls).toEqual(['save', 'did-save'])

      it 'marks the table as saved if the handler resolve the promise', ->
        table.addColumn('age')
        table.setSaveHandler -> promise = new Promise (resolve) -> resolve()
        table.save()

        waitsForPromise -> promise

        runs -> expect(table.isModified()).toBeFalsy()

      it 'leaves the table as modified if the handler reject the promise', ->
        table.addColumn('age')
        table.setSaveHandler ->
          promise = new Promise (resolve, reject) -> reject()
        table.save()

        waitsForPromise shouldReject: true, -> promise

        runs -> expect(table.isModified()).toBeTruthy()

  #    ########  ########  ######  ########  #######  ########  ########
  #    ##     ## ##       ##    ##    ##    ##     ## ##     ## ##
  #    ##     ## ##       ##          ##    ##     ## ##     ## ##
  #    ########  ######    ######     ##    ##     ## ########  ######
  #    ##   ##   ##             ##    ##    ##     ## ##   ##   ##
  #    ##    ##  ##       ##    ##    ##    ##     ## ##    ##  ##
  #    ##     ## ########  ######     ##     #######  ##     ## ########

  describe '::serialize', ->
    it 'serializes the empty table', ->
      expect(table.serialize()).toEqual({
        deserializer: 'Table'
        columns: []
        rows: []
        id: table.id
      })

    it 'serializes the table with its empty rows and columns', ->
      table.addColumn()
      table.addColumn()

      table.addRow()
      table.addRow()
      table.save()

      expect(table.serialize()).toEqual({
        deserializer: 'Table'
        columns: [null, null]
        rows: [
          [undefined, undefined]
          [undefined, undefined]
        ]
        id: table.id
      })

    it 'serializes the table with its values', ->
      table.addColumn('foo')
      table.addColumn('bar')

      table.addRow([1,2])
      table.addRow([3,4])
      table.save()

      expect(table.serialize()).toEqual({
        deserializer: 'Table'
        columns: ['foo', 'bar']
        rows: [
          [1,2]
          [3,4]
        ]
        id: table.id
      })

    it 'serializes the table in its modified state', ->
      table.addColumn('foo')
      table.addColumn('bar')

      table.addRow([1,2])
      table.addRow([3,4])

      expect(table.serialize()).toEqual({
        deserializer: 'Table'
        columns: ['foo', 'bar']
        modified: true
        cachedContents: undefined
        rows: [
          [1,2]
          [3,4]
        ]
        id: table.id
      })

  describe '.deserialize', ->
    it 'deserialize a table', ->
      table = atom.deserializers.deserialize({
        deserializer: 'Table'
        columns: ['foo', 'bar']
        rows: [
          [1,2]
          [3,4]
        ]
        id: 1
      })

      expect(table.id).toEqual(1)
      expect(table.getColumns()).toEqual(['foo','bar'])
      expect(table.getRows()).toEqual([
        [1,2]
        [3,4]
      ])
      expect(table.isModified()).toBeFalsy()

    it 'deserialize a table in a modified state', ->
      table = atom.deserializers.deserialize({
        deserializer: 'Table'
        columns: ['foo', 'bar']
        modified: true
        cachedContents: undefined
        rows: [
          [1,2]
          [3,4]
        ]
        id: 1
      })

      expect(table.getColumns()).toEqual(['foo','bar'])
      expect(table.getRows()).toEqual([
        [1,2]
        [3,4]
      ])
      expect(table.isModified()).toBeTruthy()


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
      table.addColumn('value')

    it 'has 2 columns', ->
      expect(table.getColumnCount()).toEqual(2)
      expect(table.getColumn(0)).toEqual('key')
      expect(table.getColumn(1)).toEqual('value')

    it 'is marked as modified', ->
      expect(table.isModified()).toBeTruthy()

    describe 'when adding a column whose name already exist in table', ->
      it 'does not raise an exception', ->
        expect(-> table.addColumn('key')).not.toThrow()

    describe 'when adding a column whose name is undefined', ->
      it 'does not raise an exception', ->
        expect(-> table.addColumn('key')).not.toThrow()

    describe 'when there is already rows in the table', ->
      beforeEach ->
        table.addRow ['foo', 'bar']
        table.addRow ['oof', 'rab']

      describe 'adding a column', ->
        it 'extend all the rows with a new cell', ->
          table.addColumn 'required'

          expect(table.getRow(0).length).toEqual(3)

        it 'dispatches a did-add-column event', ->
          spy = jasmine.createSpy 'addColumn'

          table.onDidAddColumn spy
          table.addColumn 'required'

          expect(spy).toHaveBeenCalled()

      describe 'adding a column at a given index', ->
        beforeEach ->
          column = table.addColumnAt 1, 'required'

        it 'adds the column at the right place', ->
          expect(table.getColumnCount()).toEqual(3)
          expect(table.getColumn(1)).toEqual('required')
          expect(table.getColumn(2)).toEqual('value')

        it 'extend the existing rows at the right place', ->
          expect(table.getRow(0).length).toEqual(3)
          expect(table.getRow(1).length).toEqual(3)

        it 'throws an error if the index is negative', ->
          expect(-> table.addColumnAt -1, 'foo').toThrow()

    describe 'removing a column', ->
      describe 'when there is alredy rows in the table', ->
        beforeEach ->
          spy = jasmine.createSpy 'removeColumn'

          table.addRow ['foo', 'bar']
          table.addRow ['oof', 'rab']

          table.onDidRemoveColumn spy
          table.removeColumn('value')

        it 'removes the column', ->
          expect(table.getColumnCount()).toEqual(1)

        it 'dispatches a did-add-column event', ->
          expect(spy).toHaveBeenCalled()

        it 'removes the corresponding row cell', ->
          expect(table.getRow(0).length).toEqual(1)
          expect(table.getRow(1).length).toEqual(1)

      it 'throws an exception when the column is undefined', ->
        expect(-> table.removeColumn()).toThrow()

      it 'throws an error with a negative index', ->
        expect(-> table.removeColumnAt(-1)).toThrow()

      it 'throws an error with an index greater that the columns count', ->
        expect(-> table.removeColumnAt(2)).toThrow()

      describe 'when saved', ->
        beforeEach ->
          table.addRow ['foo', 'bar']
          table.addRow ['oof', 'rab']
          table.save()

          table.removeColumn('value')

        it 'is marked as modified', ->
          expect(table.isModified()).toBeTruthy()

    describe 'changing a column name', ->
      beforeEach ->
        row = table.addRow ['foo', 'bar']
        table.addRow ['oof', 'rab']


      it 'changes the column name', ->
        table.changeColumnName 'value', 'content'
        expect(table.getColumn(1)).toEqual('content')

      describe 'when saved', ->
        beforeEach ->
          table.addRow ['foo', 'bar']
          table.save()

          table.changeColumnName 'value', 'content'

        it 'is marked as modified', ->
          expect(table.isModified()).toBeTruthy()

    #    ########   #######  ##      ##  ######
    #    ##     ## ##     ## ##  ##  ## ##    ##
    #    ##     ## ##     ## ##  ##  ## ##
    #    ########  ##     ## ##  ##  ##  ######
    #    ##   ##   ##     ## ##  ##  ##       ##
    #    ##    ##  ##     ## ##  ##  ## ##    ##
    #    ##     ##  #######   ###  ###   ######

    describe 'adding a row', ->
      describe 'with an object', ->
        it 'is marked as modified', ->
          table.addRow key: 'foo', value: 'bar'

          expect(table.isModified()).toBeTruthy()

        it 'creates a row containing the values', ->
          table.addRow key: 'foo', value: 'bar'

          expect(table.getRowCount()).toEqual(1)
          expect(table.getRow(0)).toEqual(['foo', 'bar'])

        it 'dispatches a did-add-row event', ->
          spy = jasmine.createSpy 'addRow'
          table.onDidAddRow spy
          table.addRow key: 'foo', value: 'bar'

          expect(spy).toHaveBeenCalled()

        it 'dispatches a did-change event', ->
          spy = jasmine.createSpy 'changeRows'
          table.onDidChange spy
          table.addRow key: 'foo', value: 'bar'

          expect(spy).toHaveBeenCalled()
          expect(spy.calls[0].args[0]).toEqual({
            oldRange: {start: 0, end: 0}
            newRange: {start: 0, end: 1}
          })

        it "fills the row with undefined values", ->
          row = table.addRow {}

          expect(row).toEqual(new Array(2))

        it 'ignores data that not match any column', ->
          row = table.addRow key: 'foo', data: 'fooo'

          expect(row).toEqual(['foo', undefined])

        describe 'at a specified index', ->
          beforeEach ->
            table.addRow key: 'foo', value: 'bar'
            table.addRow key: 'oof', value: 'rab'

          it 'inserts the row at the specified position', ->
            table.addRowAt(1, key: 'hello', value: 'world')

            expect(table.getRowCount()).toEqual(3)
            expect(table.getRow(1)).toEqual(['hello','world'])

          it 'throws an error if the index is negative', ->
            expect(-> table.addRowAt -1, {}).toThrow()

          it 'dispatches a did-change event', ->
            spy = jasmine.createSpy 'changeRows'
            table.onDidChange spy
            table.addRowAt(1, key: 'hello', value: 'world')

            expect(spy).toHaveBeenCalled()
            expect(spy.calls[0].args[0]).toEqual({
              oldRange: {start: 1, end: 1}
              newRange: {start: 1, end: 2}
            })

      describe 'with an array', ->
        it 'creates a row with a cell for each value', ->
          table.addRow ['foo', 'bar']

          expect(table.getRowCount()).toEqual(1)
          expect(table.getRow(0)).toEqual(['foo', 'bar'])

        it "fills the row with undefined values", ->
          row = table.addRow []

          expect(row).toEqual(new Array(2))

        describe 'at a specified index', ->
          beforeEach ->
            table.addRow ['foo', 'bar']
            table.addRow ['oof', 'rab']

          it 'inserts the row at the specified position', ->
            table.addRowAt(1, ['hello', 'world'])

            expect(table.getRowCount()).toEqual(3)
            expect(table.getRow(1)).toEqual(['hello', 'world'])

    describe 'adding many rows', ->
      beforeEach ->
        spy = jasmine.createSpy 'changeRows'
        table.onDidChange spy
        table.addRows [
          { key: 'foo', value: 'bar' }
          { key: 'oof', value: 'rab' }
        ]

      it 'adds the rows in the table', ->
        expect(table.getRowCount()).toEqual(2)

      it 'is marked as modified', ->
        expect(table.isModified()).toBeTruthy()

      it 'dispatch only one did-change event', ->
        expect(spy).toHaveBeenCalled()
        expect(spy.calls.length).toEqual(1)
        expect(spy.calls[0].args[0]).toEqual({
          oldRange: {start: 0, end: 0}
          newRange: {start: 0, end: 2}
        })

      describe 'at a given index', ->
        beforeEach ->
          spy = jasmine.createSpy 'changeRows'
          table.onDidChange spy
          table.addRowsAt 1, [
            { key: 'foo', value: 'bar' }
            { key: 'oof', value: 'rab' }
          ]

        it 'adds the rows in the table', ->
          expect(table.getRowCount()).toEqual(4)

        it 'dispatch only one did-change event', ->
          expect(spy).toHaveBeenCalled()
          expect(spy.calls.length).toEqual(1)
          expect(spy.calls[0].args[0]).toEqual({
            oldRange: {start: 1, end: 1}
            newRange: {start: 1, end: 3}
          })

    describe '::removeRow', ->
      beforeEach ->
        spy = jasmine.createSpy 'removeRow'

        row = table.addRow key: 'foo', value: 'bar'
        table.addRow key: 'oof', value: 'rab'

        table.onDidRemoveRow spy

      it 'removes the row', ->
        table.removeRow(row)
        expect(table.getRowCount()).toEqual(1)

      it 'dispatches a did-remove-row event', ->
        table.removeRow(row)
        expect(spy).toHaveBeenCalled()

      it 'dispatches a did-change event', ->
        spy = jasmine.createSpy 'changeRows'
        table.onDidChange spy
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

      describe 'when saved', ->
        beforeEach ->
          table.save()
          table.removeRow(row)

        it 'is marked as modified', ->
          expect(table.isModified()).toBeTruthy()

    describe '::removeRowsInRange', ->
      beforeEach ->
        table.addRow key: 'foo', value: 'bar'
        table.addRow key: 'oof', value: 'rab'
        table.addRow key: 'ofo', value: 'arb'

        spy = jasmine.createSpy 'removeRows'

        table.onDidChange spy

      it 'removes the rows from the table', ->
        table.removeRowsInRange([0,2])
        expect(table.getRowCount()).toEqual(1)
        expect(table.getRow(0)).toEqual(['ofo', 'arb'])

      it 'dispatches a single did-change', ->
        table.removeRowsInRange([0,2])
        expect(spy).toHaveBeenCalled()
        expect(spy.calls.length).toEqual(1)
        expect(spy.calls[0].args[0]).toEqual({
          oldRange: {start: 0, end: 2}
          newRange: {start: 0, end: 0}
        })

      it 'throws an error without range', ->
        expect(-> table.removeRowsInRange()).toThrow()

      it 'throws an error with an invalid range', ->
        expect(-> table.removeRowsInRange {start: 1}).toThrow()
        expect(-> table.removeRowsInRange [1]).toThrow()

      describe 'with a range running to infinity', ->
        it 'removes all the rows in the table', ->
          table.removeRowsInRange([0, Infinity])

          expect(table.getRowCount()).toEqual(0)

      describe 'when saved', ->
        beforeEach ->
          table.save()
          table.removeRowsInRange([0,2])

        it 'is marked as modified', ->
          expect(table.isModified()).toBeTruthy()

    describe '::removeRowsAtIndices', ->
      beforeEach ->
        table.addRow key: 'foo', value: 'bar'
        table.addRow key: 'oof', value: 'rab'
        table.addRow key: 'ofo', value: 'arb'

        spy = jasmine.createSpy 'removeRows'

        table.onDidChange spy

      it 'removes the rows at indices', ->
        table.removeRowsAtIndices([0,2])

        expect(table.getRowCount()).toEqual(1)
        expect(table.getRow(0)).toEqual(['oof','rab'])

      describe 'when saved', ->
        beforeEach ->
          table.save()
          table.removeRowsAtIndices([0,2])

        it 'is marked as modified', ->
          expect(table.isModified()).toBeTruthy()

    describe '::swapRows', ->
      beforeEach ->
        table.addRow key: 'foo', value: 'bar'
        table.addRow key: 'oof', value: 'rab'
        table.addRow key: 'ofo', value: 'arb'

      it 'swaps the rows', ->
        table.swapRows(0,2)

        expect(table.getRows()).toEqual([
          ['ofo','arb']
          ['oof','rab']
          ['foo','bar']
        ])

      it 'dispatches a change event', ->
        changeSpy = jasmine.createSpy('did-change')
        table.onDidChange(changeSpy)

        table.swapRows(0,2)

        expect(changeSpy).toHaveBeenCalledWith({rowIndices: [0,2]})

    describe '::swapColumns', ->
      beforeEach ->
        table.addRow key: 'foo', value: 'bar'
        table.addRow key: 'oof', value: 'rab'
        table.addRow key: 'ofo', value: 'arb'

      it 'swaps the column', ->
        table.swapColumns(0,1)

        expect(table.getRows()).toEqual([
          ['bar', 'foo']
          ['rab', 'oof']
          ['arb', 'ofo']
        ])

        expect(table.getColumn(0)).toEqual('value')
        expect(table.getColumn(1)).toEqual('key')

      it 'dispatches a change event', ->
        changeSpy = jasmine.createSpy('did-change')
        swapSpy = jasmine.createSpy('did-swap-columns')
        table.onDidChange(changeSpy)
        table.onDidSwapColumns(swapSpy)

        table.swapColumns(0,1)

        expect(changeSpy).toHaveBeenCalledWith({
          oldRange: {start: 0, end: 3}
          newRange: {start: 0, end: 3}
        })
        expect(swapSpy).toHaveBeenCalledWith({
          columnA: 0
          columnB: 1
        })


  #     ######  ######## ##       ##        ######
  #    ##    ## ##       ##       ##       ##    ##
  #    ##       ##       ##       ##       ##
  #    ##       ######   ##       ##        ######
  #    ##       ##       ##       ##             ##
  #    ##    ## ##       ##       ##       ##    ##
  #     ######  ######## ######## ########  ######

  describe '::getValueAtPosition', ->
    beforeEach ->
      table.addColumn('name')
      table.addColumn('age')

      table.addRow(['John Doe', 30])
      table.addRow(['Jane Doe', 30])

    it 'returns the cell at the given position array', ->
      expect(table.getValueAtPosition([1,0])).toEqual('Jane Doe')

    it 'returns the cell at the given position object', ->
      expect(table.getValueAtPosition(row: 1, column: 0)).toEqual('Jane Doe')

    it 'throws an error without a position', ->
      expect(-> table.getValueAtPosition()).toThrow()

    it 'returns undefined with a position out of bounds', ->
      expect(table.getValueAtPosition(row: 2, column: 0)).toBeUndefined()
      expect(table.getValueAtPosition(row: 0, column: 2)).toBeUndefined()

  describe '::setValueAtPosition', ->
    beforeEach ->
      table.addColumn('name')
      table.addColumn('age')

      table.addRow(['John Doe', 30])
      table.addRow(['Jane Doe', 30])

    it 'changes the value at the given position', ->
      table.setValueAtPosition([1,1], 40)

      expect(table.getRow(1)).toEqual(['Jane Doe', 40])

    it 'emits a did-change-cell-value event', ->
      spy = jasmine.createSpy('did-change-cell-value')
      table.onDidChangeCellValue(spy)

      table.setValueAtPosition([1,1], 40)

      expect(spy).toHaveBeenCalled()

    describe 'when saved', ->
      beforeEach ->
        table.save()
        table.setValueAtPosition([1,1], 40)

      it 'is marked as modified', ->
        expect(table.isModified()).toBeTruthy()

  describe '::setValuesAtPositions', ->
    beforeEach ->
      table.addColumn('name')
      table.addColumn('age')

      table.addRow(['John Doe', 30])
      table.addRow(['Jane Doe', 30])

    it 'changes the value at the given position', ->
      table.setValuesAtPositions([[0,1], [1,1]],[40, 40])

      expect(table.getRow(0)).toEqual(['John Doe', 40])
      expect(table.getRow(1)).toEqual(['Jane Doe', 40])

    it 'emits a did-change-cell-value event', ->
      spy = jasmine.createSpy('did-change-cell-value')
      table.onDidChangeCellValue(spy)

      table.setValuesAtPositions([[0,1], [1,1]],[40, 40])

      expect(spy).toHaveBeenCalled()

    describe 'when saved', ->
      beforeEach ->
        table.save()
        table.setValuesAtPositions([[0,1], [1,1]],[40, 40])

      it 'is marked as modified', ->
        expect(table.isModified()).toBeTruthy()

  describe '::setValuesInRange', ->
    beforeEach ->
      table.addColumn('name')
      table.addColumn('age')

      table.addRow(['John Doe', 30])
      table.addRow(['Jane Doe', 30])

    it 'changes the value at the given position', ->
      table.setValuesInRange([[0,1], [2,2]],[[40], [40]])

      expect(table.getRow(0)).toEqual(['John Doe', 40])
      expect(table.getRow(1)).toEqual(['Jane Doe', 40])

    it 'emits a did-change-cell-value event', ->
      spy = jasmine.createSpy('did-change-cell-value')
      table.onDidChangeCellValue(spy)

      table.setValuesInRange([[0,1], [2,2]],[[40], [40]])

      expect(spy).toHaveBeenCalled()

    describe 'when saved', ->
      beforeEach ->
        table.save()
        table.setValuesInRange([[0,1], [2,2]],[[40], [40]])

      it 'is marked as modified', ->
        expect(table.isModified()).toBeTruthy()

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

      expect(table.getLastRow()).toEqual(['foo18'])

    it 'rolls back a column addition', ->
      table.addColumn('key')

      table.save()
      table.undo()

      expect(table.isModified()).toBeTruthy()
      expect(table.getColumnCount()).toEqual(0)
      expect(table.undoStack.length).toEqual(0)
      expect(table.redoStack.length).toEqual(1)

      table.redo()

      expect(table.isModified()).toBeFalsy()
      expect(table.undoStack.length).toEqual(1)
      expect(table.redoStack.length).toEqual(0)
      expect(table.getColumnCount()).toEqual(1)
      expect(table.getColumn(0)).toEqual('key')

    it 'rolls back a column deletion', ->
      column = table.addColumn('key')

      table.addRow(['foo'])
      table.addRow(['bar'])
      table.addRow(['baz'])
      table.clearUndoStack()

      table.removeColumn(column)

      table.save()
      table.undo()

      expect(table.isModified()).toBeTruthy()
      expect(table.getColumnCount()).toEqual(1)
      expect(table.undoStack.length).toEqual(0)
      expect(table.redoStack.length).toEqual(1)
      expect(table.getColumn(0)).toEqual('key')
      expect(table.getRow(0)).toEqual(['foo'])
      expect(table.getRow(1)).toEqual(['bar'])
      expect(table.getRow(2)).toEqual(['baz'])

      table.redo()

      expect(table.isModified()).toBeFalsy()
      expect(table.undoStack.length).toEqual(1)
      expect(table.redoStack.length).toEqual(0)
      expect(table.getColumnCount()).toEqual(0)

    describe 'with columns in the table', ->
      beforeEach ->
        table.addColumn('key')
        column = table.addColumn('value')

      it 'rolls back a row addition', ->
        table.clearUndoStack()

        row = table.addRow ['foo', 'bar']

        table.save()
        table.undo()

        expect(table.isModified()).toBeTruthy()
        expect(table.getRowCount()).toEqual(0)
        expect(table.undoStack.length).toEqual(0)
        expect(table.redoStack.length).toEqual(1)

        table.redo()

        expect(table.isModified()).toBeFalsy()
        expect(table.undoStack.length).toEqual(1)
        expect(table.redoStack.length).toEqual(0)
        expect(table.getRowCount()).toEqual(1)
        expect(table.getRow(0)).toEqual(['foo', 'bar'])

      it 'rolls back a batched rows addition', ->
        table.clearUndoStack()

        rows = table.addRows [
          ['foo', 'bar']
          ['bar', 'baz']
        ]

        table.save()
        table.undo()

        expect(table.isModified()).toBeTruthy()
        expect(table.getRowCount()).toEqual(0)
        expect(table.undoStack.length).toEqual(0)
        expect(table.redoStack.length).toEqual(1)

        table.redo()

        expect(table.isModified()).toBeFalsy()
        expect(table.undoStack.length).toEqual(1)
        expect(table.redoStack.length).toEqual(0)
        expect(table.getRowCount()).toEqual(2)
        expect(table.getRow(0)).toEqual(['foo', 'bar'])
        expect(table.getRow(1)).toEqual(['bar', 'baz'])

      it 'rolls back a row deletion', ->
        row = table.addRow ['foo', 'bar']

        table.clearUndoStack()

        table.removeRowAt(0)

        table.save()
        table.undo()

        expect(table.isModified()).toBeTruthy()
        expect(table.getRowCount()).toEqual(1)
        expect(table.undoStack.length).toEqual(0)
        expect(table.redoStack.length).toEqual(1)
        expect(table.getRow(0)).toEqual(['foo', 'bar'])

        table.redo()

        expect(table.isModified()).toBeFalsy()
        expect(table.undoStack.length).toEqual(1)
        expect(table.redoStack.length).toEqual(0)
        expect(table.getRowCount()).toEqual(0)

      it 'rolls back a batched rows deletion', ->
        table.addRows [
          ['foo', 'bar']
          ['bar', 'baz']
        ]

        table.clearUndoStack()

        table.removeRowsInRange([0,2])

        table.save()
        table.undo()

        expect(table.isModified()).toBeTruthy()
        expect(table.getRowCount()).toEqual(2)
        expect(table.undoStack.length).toEqual(0)
        expect(table.redoStack.length).toEqual(1)
        expect(table.getRow(0)).toEqual(['foo', 'bar'])
        expect(table.getRow(1)).toEqual(['bar', 'baz'])

        table.redo()

        expect(table.isModified()).toBeFalsy()
        expect(table.undoStack.length).toEqual(1)
        expect(table.redoStack.length).toEqual(0)
        expect(table.getRowCount()).toEqual(0)

      it 'rolls back a batched rows deletion by indices', ->
        table.addRows [
          ['foo', 'bar']
          ['bar', 'baz']
          ['baz', 'foo']
        ]

        table.clearUndoStack()

        table.removeRowsAtIndices([0,2])

        table.save()
        table.undo()

        expect(table.isModified()).toBeTruthy()
        expect(table.getRowCount()).toEqual(3)
        expect(table.undoStack.length).toEqual(0)
        expect(table.redoStack.length).toEqual(1)
        expect(table.getRow(0)).toEqual(['foo', 'bar'])
        expect(table.getRow(1)).toEqual(['bar', 'baz'])
        expect(table.getRow(2)).toEqual(['baz', 'foo'])

        table.redo()

        expect(table.isModified()).toBeFalsy()
        expect(table.undoStack.length).toEqual(1)
        expect(table.redoStack.length).toEqual(0)
        expect(table.getRowCount()).toEqual(1)

      it 'rolls back a change in a column', ->
        table.clearUndoStack()

        table.changeColumnName('value', 'foo')

        table.save()
        table.undo()

        expect(table.isModified()).toBeTruthy()
        expect(table.getColumn(1)).toEqual('value')
        expect(table.undoStack.length).toEqual(0)
        expect(table.redoStack.length).toEqual(1)

        table.redo()

        expect(table.isModified()).toBeFalsy()
        expect(table.getColumn(1)).toEqual('foo')
        expect(table.undoStack.length).toEqual(1)
        expect(table.redoStack.length).toEqual(0)

      it 'rolls back a change in a row data', ->
        table.addRows [
          ['foo', 'bar']
          ['bar', 'baz']
        ]

        table.clearUndoStack()

        table.setValueAtPosition([0,0], 'hello')
        expect(table.getRow(0)).toEqual(['hello', 'bar'])

        table.save()
        table.undo()

        expect(table.isModified()).toBeTruthy()
        expect(table.undoStack.length).toEqual(0)
        expect(table.redoStack.length).toEqual(1)
        expect(table.getRow(0)).toEqual(['foo', 'bar'])

        table.redo()

        expect(table.isModified()).toBeFalsy()
        expect(table.undoStack.length).toEqual(1)
        expect(table.redoStack.length).toEqual(0)
        expect(table.getRow(0)).toEqual(['hello', 'bar'])

      it 'rolls back many changes in row data', ->
        table.addRows [
          ['foo', 'bar']
          ['bar', 'baz']
        ]

        table.clearUndoStack()

        table.setValuesAtPositions([[0,0], [1,1]], ['hello', 'world'])
        expect(table.getRow(0)).toEqual(['hello', 'bar'])
        expect(table.getRow(1)).toEqual(['bar', 'world'])

        table.save()
        table.undo()

        expect(table.isModified()).toBeTruthy()
        expect(table.undoStack.length).toEqual(0)
        expect(table.redoStack.length).toEqual(1)
        expect(table.getRow(0)).toEqual(['foo', 'bar'])
        expect(table.getRow(1)).toEqual(['bar', 'baz'])

        table.redo()

        expect(table.isModified()).toBeFalsy()
        expect(table.undoStack.length).toEqual(1)
        expect(table.redoStack.length).toEqual(0)
        expect(table.getRow(0)).toEqual(['hello', 'bar'])
        expect(table.getRow(1)).toEqual(['bar', 'world'])

      it 'rolls back many changes in row data', ->
        table.addRows [
          ['foo', 'bar']
          ['bar', 'baz']
        ]

        table.clearUndoStack()

        table.setValuesInRange([[0,0], [1,2]], [['hello', 'world']])
        expect(table.getRow(0)).toEqual(['hello', 'world'])

        table.save()
        table.undo()

        expect(table.isModified()).toBeTruthy()
        expect(table.undoStack.length).toEqual(0)
        expect(table.redoStack.length).toEqual(1)
        expect(table.getRow(0)).toEqual(['foo', 'bar'])

        table.redo()

        expect(table.isModified()).toBeFalsy()
        expect(table.undoStack.length).toEqual(1)
        expect(table.redoStack.length).toEqual(0)
        expect(table.getRow(0)).toEqual(['hello', 'world'])

      it 'rolls back a swap of rows', ->
        table.addRows([
          ['foo', 'bar']
          ['oof', 'rab']
          ['ofo', 'arb']
        ])

        table.clearUndoStack()
        table.save()

        table.swapRows(0,2)

        table.undo()

        expect(table.isModified()).toBeFalsy()
        expect(table.undoStack.length).toEqual(0)
        expect(table.redoStack.length).toEqual(1)
        expect(table.getRows()).toEqual([
          ['foo', 'bar']
          ['oof', 'rab']
          ['ofo', 'arb']
        ])

        table.redo()

        expect(table.isModified()).toBeTruthy()
        expect(table.undoStack.length).toEqual(1)
        expect(table.redoStack.length).toEqual(0)
        expect(table.getRows()).toEqual([
          ['ofo','arb']
          ['oof','rab']
          ['foo','bar']
        ])

      it 'rolls back a swap of columns', ->
        table.addRows([
          ['foo', 'bar']
          ['oof', 'rab']
          ['ofo', 'arb']
        ])

        table.clearUndoStack()
        table.save()

        table.swapColumns(0,1)

        table.undo()

        expect(table.isModified()).toBeFalsy()
        expect(table.undoStack.length).toEqual(0)
        expect(table.redoStack.length).toEqual(1)
        expect(table.getColumn(1)).toEqual('value')
        expect(table.getColumn(0)).toEqual('key')
        expect(table.getRows()).toEqual([
          ['foo', 'bar']
          ['oof', 'rab']
          ['ofo', 'arb']
        ])

        table.redo()

        expect(table.isModified()).toBeTruthy()
        expect(table.undoStack.length).toEqual(1)
        expect(table.redoStack.length).toEqual(0)
        expect(table.getColumn(0)).toEqual('value')
        expect(table.getColumn(1)).toEqual('key')
        expect(table.getRows()).toEqual([
          ['bar', 'foo']
          ['rab', 'oof']
          ['arb', 'ofo']
        ])

      describe '::clearUndoStack', ->
        it 'removes all the transactions in the undo stack', ->
          table.addRows [
            ['foo', 'bar']
            ['bar', 'baz']
          ]

          table.setValueAtPosition([0, 0], 'hello')

          table.undo()

          table.clearUndoStack()

          expect(table.undoStack.length).toEqual(0)

      describe '::clearRedoStack', ->
        it 'removes all the transactions in the redo stack', ->
          table.addRows [
            ['foo', 'bar']
            ['bar', 'baz']
          ]

          table.setValueAtPosition([0, 0], 'hello')

          table.undo()

          table.clearRedoStack()

          expect(table.redoStack.length).toEqual(0)
