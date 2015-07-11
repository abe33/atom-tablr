TableEditor = require '../lib/table-editor'
Table = require '../lib/table'

describe 'TableEditor', ->
  [table, displayTable, tableEditor] = []

  beforeEach ->
    atom.config.set 'table-edit.columnWidth', 100
    atom.config.set 'table-edit.minimuColumnWidth', 10
    atom.config.set 'table-edit.rowHeight', 20
    atom.config.set 'table-edit.minimumRowHeight', 10

  describe 'when initialized without a table', ->
    beforeEach ->
      tableEditor = new TableEditor
      {table, displayTable} = tableEditor

    it 'creates an empty table and its displayTable', ->
      expect(table).toBeDefined()
      expect(displayTable).toBeDefined()

    it 'has a default empty selection', ->
      expect(tableEditor.getLastSelection()).toBeDefined()
      expect(tableEditor.getSelections()).toEqual([tableEditor.getLastSelection()])
      expect(tableEditor.getLastSelection().getRange()).toEqual([[0,0],[0,0]])
      expect(tableEditor.getLastSelection().getCursor()).toEqual(tableEditor.getLastCursor())

    it 'has a default cursor position', ->
      expect(tableEditor.getCursorPosition()).toEqual([0,0])
      expect(tableEditor.getCursorPositions()).toEqual([[0,0]])

      expect(tableEditor.getCursorScreenPosition()).toEqual([0,0])
      expect(tableEditor.getCursorScreenPositions()).toEqual([[0,0]])

    it 'returns undefined when asked for the value at cursor', ->
      expect(tableEditor.getCursorValue()).toBeUndefined()
      expect(tableEditor.getCursorValues()).toEqual([undefined])

  describe 'when initialized with a table', ->
    beforeEach ->
      table = new Table

      table.addColumn 'key'
      table.addColumn 'value'

      table.addRow ['name', 'Jane Doe']
      table.addRow ['age', 30]
      table.addRow ['gender', 'female']

      tableEditor = new TableEditor({table})
      {displayTable} = tableEditor

      displayTable.sortBy('key')

    it 'uses the passed-in table', ->
      expect(displayTable).toBeDefined()
      expect(displayTable.table).toBe(table)
      expect(tableEditor.table).toBe(table)

    it 'has a default empty selection', ->
      expect(tableEditor.getLastSelection()).toBeDefined()
      expect(tableEditor.getSelections()).toEqual([tableEditor.getLastSelection()])
      expect(tableEditor.getLastSelection().getRange()).toEqual([[0,0],[1,1]])
      expect(tableEditor.getLastSelection().getCursor()).toEqual(tableEditor.getLastCursor())

    it 'has a default cursor position', ->
      expect(tableEditor.getCursorPosition()).toEqual([1,0])
      expect(tableEditor.getCursorPositions()).toEqual([[1,0]])

      expect(tableEditor.getCursorScreenPosition()).toEqual([0,0])
      expect(tableEditor.getCursorScreenPositions()).toEqual([[0,0]])

    it 'returns undefined when asked for the value at cursor', ->
      expect(tableEditor.getCursorValue()).toEqual('age')
      expect(tableEditor.getCursorValues()).toEqual(['age'])
