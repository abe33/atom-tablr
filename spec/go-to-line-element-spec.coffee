require './helpers/spec-helper'

TableEditor = require '../lib/table-editor'
TableElement = require '../lib/table-element'
GoToLineElement = require '../lib/go-to-line-element'

describe 'GoToLineElement', ->
  [goToLineElement, tableEditor, tableElement] = []
  beforeEach ->
    GoToLineElement.registerCommands()

    jasmine.attachToDOM(atom.views.getView(atom.workspace))

    tableEditor = new TableEditor
    tableEditor.addColumn 'key'
    tableEditor.addColumn 'value'
    tableEditor.addColumn 'foo'

    for i in [0...100]
      tableEditor.addRow [
        "row#{i}"
        i * 100
        if i % 2 is 0 then 'yes' else 'no'
      ]

    atom.config.set 'tablr.tableEditor.rowHeight', 20
    atom.config.set 'tablr.tableEditor.columnWidth', 100
    atom.config.set 'tablr.tableEditor.rowOverdraw', 10
    atom.config.set 'tablr.tableEditor.columnOverdraw', 2
    atom.config.set 'tablr.tableEditor.minimumRowHeight', 10
    atom.config.set 'tablr.tableEditor.minimumColumnWidth', 40
    atom.config.set 'tablr.tableEditor.scrollSpeedDuringDrag', 20

    tableElement = atom.views.getView(tableEditor)

    goToLineElement = tableElement.openGoToLineModal()

  it 'exists', ->
    expect(goToLineElement).toBeDefined()

  describe 'core:cancel', ->
    it 'destroys the modal', ->
      atom.commands.dispatch(goToLineElement, 'core:cancel')
      expect(document.querySelector('tablr-go-to-line')).not.toExist()

  describe 'core:confirm', ->
    beforeEach ->
      spyOn(tableElement, 'goToLine')

    describe 'with only a row', ->
      it 'destroys the modal and calls the table element go to line method', ->
        goToLineElement.miniEditor.getModel().setText('10')
        atom.commands.dispatch(goToLineElement, 'core:confirm')

        expect(tableElement.goToLine).toHaveBeenCalledWith([10])

    describe 'with a row and a column index', ->
      it 'destroys the modal and calls the table element go to line method', ->
        goToLineElement.miniEditor.getModel().setText('10:20')
        atom.commands.dispatch(goToLineElement, 'core:confirm')

        expect(tableElement.goToLine).toHaveBeenCalledWith([10,20])

    describe 'with a row and a column name', ->
      it 'destroys the modal and calls the table element go to line method', ->
        goToLineElement.miniEditor.getModel().setText('10:foo')
        atom.commands.dispatch(goToLineElement, 'core:confirm')

        expect(tableElement.goToLine).toHaveBeenCalledWith([10,'foo'])

    describe 'with nothing', ->
      it 'destroys the modal and does not call the table element go to line method', ->
        atom.commands.dispatch(goToLineElement, 'core:confirm')

        expect(tableElement.goToLine).not.toHaveBeenCalled()
