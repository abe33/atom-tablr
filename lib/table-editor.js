'use strict'

const {Point, Emitter, CompositeDisposable} = require('atom')
const Delegator = require('delegato')
const Table = require('./table')
const DisplayTable = require('./display-table')
const Cursor = require('./cursor')
const Selection = require('./selection')
const Range = require('./range')

class TableEditor {
  static initClass () {
    Delegator.includeInto(this)

    this.delegatesProperties(
      'order', 'direction',
      {toProperty: 'displayTable'}
    )
    this.delegatesMethods(
      'screenPosition', 'modelPosition',
      'screenRowToModelRow', 'modelRowToScreenRow',
      'getContentWidth', 'getContentHeight',
      'getValueAtPosition', 'setValueAtPosition', 'setValuesAtPositions', 'setValuesInRange',
      'getValueAtScreenPosition', 'setValueAtScreenPosition', 'setValuesAtScreenPositions', 'setValuesInScreenRange',
      'getRow', 'getRows', 'addRow', 'addRowAt', 'removeRow', 'removeRowAt', 'addRows', 'addRowsAt', 'removeScreenRowAt', 'removeRowsInRange', 'removeRowsInScreenRange', 'swapRows',
      'getRowHeightAt', 'getRowHeight', 'setRowHeight', 'setRowHeightAt', 'getLastRowIndex', 'getRowIndexAtPixelPosition',
      'getScreenRow', 'getScreenRowCount', 'getScreenRows', 'getScreenRowHeightAt', 'getScreenRowOffsetAt', 'setScreenRowHeightAt', 'getMinimumRowHeight', 'getScreenRowIndexAtPixelPosition', 'rowRangeFrom',
      'onDidAddRow', 'onDidRemoveRow', 'onDidChange', 'onDidChangeRowHeight',
      'getScreenColumn', 'getScreenColumns', 'getScreenColumnCount', 'getLastColumnIndex', 'getScreenColumnIndex',
      'getScreenColumnWidth', 'setScreenColumnOptions', 'setScreenColumnWidthAt', 'getScreenColumnWidthAt', 'getScreenColumnAlignAt', 'getScreenColumnOffsetAt', 'setScreenColumnAlignAt', 'getScreenColumnIndexAtPixelPosition', 'getMinimumScreenColumnWidth', 'getColumnIndex',
      'addColumn', 'addColumnAt', 'removeColumn', 'removeColumnAt', 'swapColumns', 'getColumns', 'removeScreenColumnsInRange',
      'onDidAddColumn', 'onDidRemoveColumn', 'onDidChangeColumnOption', 'onDidRenameColumn', 'onDidChangeLayout',
      'getScreenCellRect', 'getScreenCellPosition',
      'onDidChangeCellValue',
      'sortBy', 'toggleSortDirection', 'resetSort', 'applySort',
      'undo', 'redo', 'clearUndoStack', 'clearRedoStack',
      {toProperty: 'displayTable'}
    )
    this.delegatesMethods(
      'save', 'isModified', 'onDidSave', 'onWillSave', 'setSaveHandler', 'initializeAfterSetup', 'lockModifiedStatus', 'unlockModifiedStatus', 'getRowCount',
      {toProperty: 'table'}
    )

    return this
  }

  static deserialize (state) {
    state.displayTable = atom.deserializers.deserialize(state.displayTable)
    state.table = state.displayTable.table

    return new TableEditor(state)
  }

  constructor (options = {}) {
    let cursors, selections
    ({table: this.table, displayTable: this.displayTable, cursors, selections} = options)
    if (!this.table) { this.table = new Table() }
    if (!this.displayTable) {
      this.displayTable = new DisplayTable({table: this.table})
    }
    this.emitter = new Emitter()
    this.subscriptions = new CompositeDisposable()
    this.cursorSubscriptions = new WeakMap()
    this.cursors = []
    this.selections = []

    this.table.retain()

    if (selections && selections.length) {
      selections.forEach((selection, i) => {
        this.createCursorAndSelection(cursors[i], selection)
      })
    } else {
      this.addCursorAtScreenPosition(new Point(0, 0))
    }

    this.subscriptions.add(this.displayTable.onDidChange(() => {
      const selection = this.getLastSelection()
      if (selection.isEmpty()) { selection.selectNone() }

      const {column, row} = this.getCursorScreenPosition()
      let newColumn = column
      let newRow = row

      if (row > this.getLastRowIndex()) {
        newRow = this.getLastRowIndex()
      }
      if (column > this.getLastColumnIndex()) {
        newColumn = this.getLastColumnIndex()
      }
      if (newRow !== row || newColumn !== column) {
        this.setCursorAtScreenPosition([newRow, newColumn])
      }
    }))

    this.subscriptions.add(this.table.onDidDestroy(() => this.wasDestroyed()))
  }

  destroy () {
    const {table} = this
    this.displayTable = null
    this.wasDestroyed()
    table.release()
  }

  wasDestroyed () {
    this.cursors.forEach(cursor => cursor && cursor.destroy())
    this.destroyed = true
    this.emitter.emit('did-destroy', this)
    this.emitter.dispose()
    this.emitter = null
    this.subscriptions.dispose()
    this.subscriptions = null
    this.displayTable = null
    this.table = null
  }

  getTitle () { return 'Table' }

  shouldPromptToSave ({windowCloseRequested} = {}) {
    return this.isModified()
  }

  onDidDestroy (callback) {
    return this.emitter.on('did-destroy', callback)
  }

  onDidAddCursor (callback) {
    return this.emitter.on('did-add-cursor', callback)
  }

  onDidRemoveCursor (callback) {
    return this.emitter.on('did-remove-cursor', callback)
  }

  onDidChangeCursorPosition (callback) {
    return this.emitter.on('did-change-cursor-position', callback)
  }

  onDidAddSelection (callback) {
    return this.emitter.on('did-add-selection', callback)
  }

  onDidRemoveSelection (callback) {
    return this.emitter.on('did-remove-selection', callback)
  }

  onDidChangeSelectionRange (callback) {
    return this.emitter.on('did-change-selection-range', callback)
  }

  onDidChangeModified (callback) {
    return this.getTable().onDidChangeModified(callback)
  }

  isDestroyed () { return this.destroyed }

  getTable () { return this.table }

  getTableRange () {
    return Range.fromObject([
      [0, 0],
      [this.getScreenRowCount(), this.getScreenColumnCount()]
    ])
  }

  getRowRange (row) {
    return Range.fromObject([
      [row, 0],
      [row + 1, this.getScreenColumnCount()]
    ])
  }

  getRowsRange (range) {
    range = this.rowRangeFrom(range)
    return Range.fromObject([
      [range.start, 0],
      [range.end + 1, this.getScreenColumnCount()]
    ])
  }

  getColumnRange (column) {
    return Range.fromObject([
      [0, column],
      [this.getScreenRowCount(), column + 1]
    ])
  }

  createCursorAndSelection (position, range) {
    position = Point.fromObject(position)
    if (range) { range = Range.fromObject(range) }

    const cursor = new Cursor({position, tableEditor: this})
    const selection = new Selection({cursor, range, tableEditor: this})

    this.selections.push(selection)
    this.cursors.push(cursor)

    this.emitter.emit('did-add-selection', {selection, tableEditor: this})
    this.emitter.emit('did-add-cursor', {cursor, tableEditor: this})

    this.cursorSubscriptions.set(cursor, cursor.onDidDestroy(() => {
      this.cursors.splice(this.cursors.indexOf(cursor), 1)
      this.emitter.emit('did-remove-cursor', {cursor, tableEditor: this})
      this.cursorSubscriptions.get(cursor).dispose()
      this.cursorSubscriptions.delete(cursor)
    }))

    this.cursorSubscriptions.set(selection, selection.onDidDestroy(() => {
      this.selections.splice(this.selections.indexOf(selection), 1)
      this.emitter.emit('did-remove-selection', {selection, tableEditor: this})
      this.cursorSubscriptions.get(selection).dispose()
      this.cursorSubscriptions.delete(selection)
    }))
  }

  insertRowBefore () {
    const {column, row} = this.getCursorPosition()
    const newRowIndex = this.screenRowToModelRow(row)

    this.addRowAt(newRowIndex)

    this.setCursorAtScreenPosition([newRowIndex, column])
    this.ensureValidCursorCoordinates()
  }

  insertRowAfter () {
    const {column, row} = this.getCursorPosition()
    const newRowIndex = this.screenRowToModelRow(row) + 1

    this.addRowAt(newRowIndex)

    this.setCursorAtScreenPosition([newRowIndex, column])
    this.ensureValidCursorCoordinates()
  }

  delete () {
    this.table.batchTransaction(() => {
      this.getSelections().map((selection) => selection.delete())
    })
  }

  deleteRowAtCursor () {
    const {row} = this.getCursorPosition()
    this.removeScreenRowAt(this.screenRowToModelRow(row))
  }

  deleteSelectedRows () {
    this.table.batchTransaction(() => {
      this.getSelections().forEach(selection => {
        this.removeRowsInScreenRange(selection.rowsRange())
      })
    })
  }

  insertColumnBefore () {
    this.addColumnAt(this.getCursorPosition().column)
    this.ensureValidCursorCoordinates()
  }

  insertColumnAfter () {
    this.addColumnAt(this.getCursorPosition().column + 1)
    this.ensureValidCursorCoordinates()
  }

  deleteColumnAtCursor () {
    this.removeColumnAt(this.getCursorPosition().column)
    this.ensureValidCursorCoordinates()
  }

  deleteSelectedColumns () {
    this.table.batchTransaction(() => {
      this.getSelections().forEach(selection => {
        this.removeScreenColumnsInRange(selection.columnsRange())
      })
    })
  }

  serialize () {
    return {
      deserializer: 'TableEditor',
      displayTable: this.displayTable.serialize(),
      cursors: this.getCursors().map(cursor => cursor.serialize()),
      selections: this.getSelections().map(sel => sel.serialize())
    }
  }

  //     ######   #######  ########  ##    ##
  //    ##    ## ##     ## ##     ##  ##  ##
  //    ##       ##     ## ##     ##   ####
  //    ##       ##     ## ########     ##
  //    ##       ##     ## ##           ##
  //    ##    ## ##     ## ##           ##
  //     ######   #######  ##           ##

  copySelectedCells () {
    let maintainClipboard = false
    this.selections.forEach(selection => {
      selection.copy(maintainClipboard, false)
      maintainClipboard = true
    })
  }

  cutSelectedCells () {
    this.copySelectedCells()
    this.delete()
  }

  pasteClipboard (options = {}) {
    const {text: clipboardText, metadata} = atom.clipboard.readWithMetadata()

    this.table.batchTransaction(() => {
      const selections = this.getSelections()
      if (metadata) {
        let values = metadata.values
        if (values) {
          selections.forEach((selection, i) =>
            selection.fillValues(values[i % values.length])
          )
        } else if (metadata.selections) {
          if (atom.config.get('tablr.copyPaste.flattenBufferMultiSelectionOnPaste')) {
            selections.forEach(selection => selection.fill(clipboardText))
          } else if (selections.every(selection => !selection.spanMoreThanOneCell()) && selections.length === metadata.selections.length) {
            selections.map((selection, i) =>
              selection.fill(metadata.selections[i % metadata.selections.length].text))
          } else {
            switch (atom.config.get('tablr.copyPaste.distributeBufferMultiSelectionOnPaste')) {
              case 'vertically':
                values = metadata.selections.map(sel => [sel.text])
                break
              case 'horizontally':
                values = [metadata.selections.map(sel => sel.text)]
                break
            }

            selections.forEach((selection) => selection.fillValues(values))
          }
        } else {
          selections.forEach((selection) => selection.fill(clipboardText))
        }
      } else {
        selections.forEach((selection) => selection.fill(clipboardText))
      }
    })
  }

  //     ######  ######## ##       ########  ######  ########
  //    ##    ## ##       ##       ##       ##    ##    ##
  //    ##       ##       ##       ##       ##          ##
  //     ######  ######   ##       ######   ##          ##
  //          ## ##       ##       ##       ##          ##
  //    ##    ## ##       ##       ##       ##    ##    ##
  //     ######  ######## ######## ########  ######     ##

  getSelections () {
    return this.selections.slice()
  }

  hasMultipleSelections () {
    return this.getSelections().length > 1
  }

  getLastSelection () {
    return this.selections[this.selections.length - 1]
  }

  getSelectedRange () { return this.getLastSelection().getRange() }

  setSelectedRange (range) {
    return this.modifySelections(selection => selection.setRange(range))
  }

  setSelectedRow (row) {
    const range = this.getRowRange(row)
    return this.modifySelections(selection => selection.setRange(range))
  }

  setSelectedRowRange (range) {
    range = this.getRowsRange(range)
    return this.modifySelections(selection => selection.setRange(range))
  }

  getSelectedRanges () {
    return this.getSelections().map((selection) => selection.getRange())
  }

  setSelectedRanges (ranges) {
    if (!ranges.length) {
      throw new Error('Passed an empty array to setSelectedRanges')
    }

    const selections = this.getSelections()
    ranges.forEach((range) => {
      selections.length
        ? selections.shift().setRange(range)
        : this.addSelectionAtScreenRange(range)
    })

    selections.forEach(selection => selection.destroy())

    this.mergeSelections()
  }

  addSelectionAtScreenRange (range) {
    range = Range.fromObject(range)
    this.createCursorAndSelection(range.start, range)
  }

  removeSelection (selection) {
    selection.destroy()
  }

  expandUp (delta) {
    this.modifySelections(selection => selection.expandUp(delta))
  }

  expandDown (delta) {
    this.modifySelections(selection => selection.expandDown(delta))
  }

  expandLeft (delta) {
    this.modifySelections(selection => selection.expandLeft(delta))
  }

  expandRight (delta) {
    this.modifySelections(selection => selection.expandRight(delta))
  }

  expandToTop (delta) {
    this.modifySelections(selection => selection.expandToTop(delta))
  }

  expandToBottom (delta) {
    this.modifySelections(selection => selection.expandToBottom(delta))
  }

  expandToLeft (delta) {
    this.modifySelections(selection => selection.expandToLeft(delta))
  }

  expandToRight (delta) {
    this.modifySelections(selection => selection.expandToRight(delta))
  }

  modifySelections (fn) {
    this.getSelections().forEach(selection => fn(selection))
    this.mergeSelections()
  }

  mergeSelections () {
    const selections = this.getSelections()
    this.selections = selections.reduce((memo, selectionA) => {
      const isContained = this.getSelections().some(selectionB =>
        selectionA !== selectionB &&
        selectionB.getRange().containsRange(selectionA.getRange())
      )

      if (isContained) {
        selectionA.destroy()
      } else {
        return memo.concat(selectionA)
      }
      return memo
    }, [])
  }

  //     ######  ##     ## ########   ######   #######  ########   ######
  //    ##    ## ##     ## ##     ## ##    ## ##     ## ##     ## ##    ##
  //    ##       ##     ## ##     ## ##       ##     ## ##     ## ##
  //    ##       ##     ## ########   ######  ##     ## ########   ######
  //    ##       ##     ## ##   ##         ## ##     ## ##   ##         ##
  //    ##    ## ##     ## ##    ##  ##    ## ##     ## ##    ##  ##    ##
  //     ######   #######  ##     ##  ######   #######  ##     ##  ######

  getCursors () {
    return this.cursors.slice()
  }

  getCursorsInRowOrder () {
    return this.getCursors().sort((a, b) => a.getPosition().row - b.getPosition().row)
  }

  getCursorsInColumnOrder () {
    return this.getCursors().sort((a, b) => a.getPosition().column - b.getPosition().column)
  }

  hasMultipleCursors () {
    return this.getCursors().length > 1
  }

  getLastCursor () {
    return this.cursors[this.cursors.length - 1]
  }

  getCursorPosition () {
    return this.modelPosition(this.getLastCursor().getPosition())
  }

  getCursorPositions () {
    return this.getCursors().map((cursor) => this.modelPosition(cursor.getPosition()))
  }

  getCursorScreenPosition () {
    return this.getLastCursor().getPosition()
  }

  getCursorScreenPositions () {
    return this.getCursors().map((cursor) => cursor.getPosition())
  }

  getCursorValue () {
    return this.getValueAtScreenPosition(this.getCursorScreenPosition())
  }

  getCursorValues () {
    return this.getCursors().map((cursor) => this.getValueAtScreenPosition(cursor.getPosition()))
  }

  addCursorAtPosition (position) {
    this.addCursorAtScreenPosition(this.screenPosition(position))
  }

  addCursorAtScreenPosition (position) {
    position = Point.fromObject(position)
    if (this.cursors.some(cursor => cursor.getPosition().isEqual(position))) {
      return
    }

    this.createCursorAndSelection(position)
  }

  addCursorBelowLastSelection () {
    const range = this.getSelectedRange()
    const position = this.getCursorPosition()
    this.addCursorAtScreenPosition([
      range.end.row,
      position.column
    ])
  }

  addCursorAboveLastSelection () {
    const range = this.getSelectedRange()
    const position = this.getCursorPosition()
    this.addCursorAtScreenPosition([
      range.start.row - 1,
      position.column
    ])
  }

  addCursorLeftToLastSelection () {
    const range = this.getSelectedRange()
    const position = this.getCursorPosition()
    this.addCursorAtScreenPosition([
      position.row,
      range.start.column - 1
    ])
  }

  addCursorRightToLastSelection () {
    const range = this.getSelectedRange()
    const position = this.getCursorPosition()
    this.addCursorAtScreenPosition([
      position.row,
      range.end.column
    ])
  }

  setCursorAtPosition (position) {
    position = this.screenPosition(position)
    this.moveCursors(cursor => cursor.setPosition(position))
  }

  setCursorAtScreenPosition (position) {
    this.moveCursors(cursor => cursor.setPosition(position))
  }

  removeCursor (cursor) { cursor.destroy() }

  moveUp (delta = 1) { this.moveCursors(cursor => cursor.moveUp(delta)) }

  moveDown (delta = 1) { this.moveCursors(cursor => cursor.moveDown(delta)) }

  moveLeft (delta = 1) { this.moveCursors(cursor => cursor.moveLeft(delta)) }

  moveRight (delta = 1) { this.moveCursors(cursor => cursor.moveRight(delta)) }

  moveUpInSelection (delta = 1) {
    this.moveCursors(cursor => cursor.moveUpInSelection(delta))
  }

  moveDownInSelection (delta = 1) {
    this.moveCursors(cursor => cursor.moveDownInSelection(delta))
  }

  moveLeftInSelection (delta = 1) {
    this.moveCursors(cursor => cursor.moveLeftInSelection(delta))
  }

  moveRightInSelection (delta = 1) {
    this.moveCursors(cursor => cursor.moveRightInSelection(delta))
  }

  moveToTop () { this.moveCursors(cursor => cursor.moveToTop()) }

  moveToBottom () { this.moveCursors(cursor => cursor.moveToBottom()) }

  moveToLeft () { this.moveCursors(cursor => cursor.moveToLeft()) }

  moveToRight () { this.moveCursors(cursor => cursor.moveToRight()) }

  pageUp () { this.moveCursors(cursor => cursor.pageUp()) }

  pageDown () { this.moveCursors(cursor => cursor.pageDown()) }

  pageLeft () { this.moveCursors(cursor => cursor.pageLeft()) }

  pageRight () { this.moveCursors(cursor => cursor.pageRight()) }

  moveLineDown () {
    if (this.order != null) { return this.notifyLineMoveWithOrder() }

    const cursors = this.getCursorsInRowOrder().reverse()

    this.initiateCursorManipulation(() => {
      this.table.batchTransaction(() =>
        cursors.forEach(cursor => cursor.moveLineDown())
      )
    })
  }

  moveLineUp () {
    if (this.order != null) { return this.notifyLineMoveWithOrder() }

    const cursors = this.getCursorsInRowOrder()

    this.initiateCursorManipulation(() => {
      this.table.batchTransaction(() =>
        cursors.forEach(cursor => cursor.moveLineUp())
      )
    })
  }

  moveColumnLeft () {
    const cursors = this.getCursorsInColumnOrder()

    this.initiateCursorManipulation(() => {
      this.table.batchTransaction(() =>
        cursors.forEach(cursor => cursor.moveColumnLeft())
      )
    })
  }

  moveColumnRight () {
    const cursors = this.getCursorsInColumnOrder().reverse()

    this.initiateCursorManipulation(() => {
      this.table.batchTransaction(() =>
        cursors.forEach(cursor => cursor.moveColumnRight())
      )
    })
  }

  moveCursors (fn) {
    this.getCursors().forEach(cursor => fn(cursor))
    this.mergeCursors()
  }

  ensureValidCursorCoordinates () {
    this.moveCursors((cursor) => {
      const pos = cursor.getPosition()
      if (pos.column < 0 || isNaN(pos.column) ||
          pos.row < 0 || isNaN(pos.row)) {
        cursor.setPosition([0, 0])
      }
    })
  }

  initiateCursorManipulation (block) {
    const originalCursorPositions = this.getCursors().map(cursor => cursor.getPosition().copy())

    block.call(this)

    const finalCursorPositions = this.getCursors().map(cursor => cursor.getPosition().copy())

    this.table.ammendLastTransaction({
      undo: commit => {
        commit.undo()
        this.getCursors().forEach((cursor, i) => cursor.setPosition(originalCursorPositions[i]))
      },

      redo: commit => {
        commit.redo()
        this.getCursors().forEach((cursor, i) => cursor.setPosition(finalCursorPositions[i]))
      }
    })
  }

  // Merge cursors that have the same screen position
  mergeCursors () {
    this.getCursors().reduce((positions, cursor) => {
      const position = cursor.getPosition().toString()
      positions.hasOwnProperty(position)
        ? cursor.destroy()
        : positions[position] = true

      return positions
    }, {})
  }

  notifyLineMoveWithOrder () {
    atom.notifications.addWarning("Moving lines isn't possible as long as an order is defined in the table, otherwise you may alter the table without noticing.")
  }
}

module.exports = TableEditor.initClass()
