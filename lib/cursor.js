'use strict'

const {Point, Emitter} = require('atom')
const Range = require('./range')

module.exports = class Cursor {
  constructor ({tableEditor, position}) {
    this.tableEditor = tableEditor
    this.position = position || new Point()
    this.emitter = new Emitter()
  }

  onDidChangePosition (callback) {
    return this.emitter.on('did-change-position', callback)
  }

  onDidDestroy (callback) {
    return this.emitter.on('did-destroy', callback)
  }

  bind (binding) {
    this.binding = binding
    this.selection = binding.selection

    this.bindingSubscription = this.binding.onDidDestroy(() => {
      this.emitter.emit('did-destroy', this)
      this.emitter.dispose()
      this.bindingSubscription.dispose()
      delete this.binding
      delete this.bindingSubscription
      delete this.destroyed
    })
  }

  destroy () {
    if (this.isDestroyed()) { return }
    this.binding.destroy()
  }

  isDestroyed () { return this.destroyed }

  getPosition () { return this.position }

  getValue () {
    return this.tableEditor.getValueAtScreenPosition(this.getPosition())
  }

  setPosition (position, resetSelection = true) {
    const oldPosition = this.position
    this.position = Point.fromObject(position)
    if (!this.position.isEqual(oldPosition)) {
      this.cursorMoved(oldPosition, resetSelection)
    }
  }

  getRange () {
    return new Range(this.position, {
      row: Math.min(
        this.tableEditor.getScreenRowCount(), this.position.row + 1
      ),
      column: Math.min(
        this.tableEditor.getScreenColumnCount(), this.position.column + 1
      )
    })
  }

  moveUp (delta = 1) {
    const oldPosition = this.position.copy()
    this.moveUpInRange(delta)
    this.cursorMoved(oldPosition)
  }

  moveUpInSelection (delta = 1) {
    if (!this.selection.spanMoreThanOneCell()) { return this.moveUp() }

    const oldPosition = this.position.copy()
    this.moveUpInRange(delta, this.selection.getRange())
    this.cursorMoved(oldPosition, false)
  }

  moveUpInRange (delta = 1, range = this.tableEditor.getTableRange()) {
    let newRow = this.position.row - delta
    if (newRow < range.start.row) { newRow = range.end.row - 1 }

    this.position.row = newRow
  }

  moveDown (delta = 1) {
    const oldPosition = this.position.copy()
    this.moveDownInRange(delta)
    this.cursorMoved(oldPosition)
  }

  moveDownInSelection (delta = 1) {
    if (!this.selection.spanMoreThanOneCell()) { return this.moveDown() }

    const oldPosition = this.position.copy()
    this.moveDownInRange(delta, this.selection.getRange())
    this.cursorMoved(oldPosition, false)
  }

  moveDownInRange (delta = 1, range = this.tableEditor.getTableRange()) {
    let newRow = this.position.row + delta
    if (newRow >= range.end.row) { newRow = range.start.row }

    this.position.row = newRow
  }

  moveLeft (delta = 1) {
    const oldPosition = this.position.copy()
    this.moveLeftInRange(delta)
    this.cursorMoved(oldPosition)
  }

  moveLeftInSelection (delta = 1) {
    if (!this.selection.spanMoreThanOneCell()) { return this.moveLeft() }

    const oldPosition = this.position.copy()
    this.moveLeftInRange(delta, this.selection.getRange())
    this.cursorMoved(oldPosition, false)
  }

  moveLeftInRange (delta = 1, range = this.tableEditor.getTableRange()) {
    let newColumn = this.position.column - delta

    if (newColumn < range.start.column) {
      newColumn = range.end.column - 1
      let newRow = this.position.row - 1
      if (newRow < range.start.row) { newRow = range.end.row - 1 }

      this.position.row = newRow
    }

    this.position.column = newColumn
  }

  moveRight (delta = 1) {
    const oldPosition = this.position.copy()
    this.moveRightInRange(delta)
    this.cursorMoved(oldPosition)
  }

  moveRightInSelection (delta = 1) {
    if (!this.selection.spanMoreThanOneCell()) { return this.moveRight() }

    const oldPosition = this.position.copy()
    this.moveRightInRange(delta, this.selection.getRange())
    this.cursorMoved(oldPosition, false)
  }

  moveRightInRange (delta = 1, range = this.tableEditor.getTableRange()) {
    let newColumn = this.position.column + delta
    if (newColumn >= range.end.column) {
      newColumn = range.start.column
      let newRow = this.position.row + 1
      if (newRow >= range.end.row) { newRow = range.start.row }

      this.position.row = newRow
    }

    this.position.column = newColumn
  }

  moveToTop () {
    this.moveUp(this.position.row)
  }

  moveToBottom () {
    this.moveDown(this.tableEditor.getScreenRowCount() - this.position.row - 1)
  }

  moveToLeft () {
    this.moveLeft(this.position.column)
  }

  moveToRight () {
    this.moveRight(this.tableEditor.getScreenColumnCount() - this.position.column - 1)
  }

  moveLineDown () {
    if (this.position.row === this.tableEditor.getScreenRowCount() - 1) {
      return
    }
    const oldPosition = this.position.copy()

    this.tableEditor.swapRows(this.position.row, this.position.row + 1)
    this.position.row += 1

    this.cursorMoved(oldPosition)
  }

  moveLineUp () {
    if (this.position.row === 0) { return }
    const oldPosition = this.position.copy()

    this.tableEditor.swapRows(this.position.row, this.position.row - 1)
    this.position.row -= 1

    this.cursorMoved(oldPosition)
  }

  moveColumnLeft () {
    if (this.position.column === 0) { return }
    const oldPosition = this.position.copy()

    this.tableEditor.swapColumns(this.position.column - 1, this.position.column)
    this.position.column -= 1

    this.cursorMoved(oldPosition)
  }

  moveColumnRight () {
    if (this.position.column === this.tableEditor.getScreenColumnCount() - 1) { return }
    const oldPosition = this.position.copy()

    this.tableEditor.swapColumns(this.position.column, this.position.column + 1)
    this.position.column += 1

    this.cursorMoved(oldPosition)
  }

  pageUp () {
    const oldPosition = this.position.copy()
    const newRow = this.position.row - atom.config.get('tablr.tableEditor.pageMoveRowAmount')
    this.position.row = Math.max(0, newRow)
    if (!this.position.isEqual(oldPosition)) { this.cursorMoved(oldPosition) }
  }

  pageDown () {
    const oldPosition = this.position.copy()
    const newRow = this.position.row + atom.config.get('tablr.tableEditor.pageMoveRowAmount')
    this.position.row = Math.min(this.tableEditor.getLastRowIndex(), newRow)
    if (!this.position.isEqual(oldPosition)) { this.cursorMoved(oldPosition) }
  }

  pageLeft () {
    const oldPosition = this.position.copy()
    const newColumn = this.position.column - atom.config.get('tablr.tableEditor.pageMoveColumnAmount')
    this.position.column = Math.max(0, newColumn)
    if (!this.position.isEqual(oldPosition)) { this.cursorMoved(oldPosition) }
  }

  pageRight () {
    const oldPosition = this.position.copy()
    const newColumn = this.position.column + atom.config.get('tablr.tableEditor.pageMoveColumnAmount')
    this.position.column = Math.min(this.tableEditor.getLastColumnIndex(), newColumn)
    if (!this.position.isEqual(oldPosition)) { this.cursorMoved(oldPosition) }
  }

  cursorMoved (oldPosition, resetSelection = true) {
    if (this.position.isEqual(oldPosition)) { return }

    if (resetSelection) { this.selection.resetRangeOnCursor() }
    const eventObject = {
      cursor: this,
      newPosition: this.position,
      oldPosition
    }
    this.emitter.emit('did-change-position', eventObject)
    this.tableEditor.emitter.emit('did-change-cursor-position', eventObject)
  }

  serialize () { return this.position.serialize() }
}
