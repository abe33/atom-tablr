'use strict'

const {Emitter} = require('atom')
const Range = require('./range')
const CursorSelectionBinding = require('./cursor-selection-binding')

module.exports = class Selection {
  constructor ({range, cursor, tableEditor}) {
    this.cursor = cursor
    this.range = range || this.cursor.getRange()
    this.tableEditor = tableEditor
    this.binding = new CursorSelectionBinding({
      cursor: this.cursor, selection: this
    })
    this.cursor.bind(this.binding)
    this.emitter = new Emitter()

    this.bindingSubscription = this.binding.onDidDestroy(() => {
      this.emitter.emit('did-destroy', this)
      this.emitter.dispose()
      this.bindingSubscription.dispose()
      this.binding = null
      this.cursor = null
      this.bindingSubscription = null
      this.destroyed = true
    })
  }

  onDidDestroy (callback) {
    return this.emitter.on('did-destroy', callback)
  }

  onDidChangeRange (callback) {
    return this.emitter.on('did-change-range', callback)
  }

  destroy () {
    if (this.isDestroyed()) { return }

    this.binding.destroy()
  }

  isDestroyed () { return this.destroyed }

  getCursor () { return this.cursor }

  setCursor (cursor) {
    this.cursor = cursor
  }

  getRange () { return this.range }

  setRange (range) {
    let oldRange = this.range
    this.range = Range.fromObject(range)
    if (!this.range.containsPoint(this.getCursor().getPosition())) {
      this.getCursor().setPosition(this.range.start, false)
    }

    this.rangeChanged(oldRange)
  }

  isEmpty () { return this.range.isEmpty() }

  bounds () { return this.range.bounds() }

  getValue () {
    if (this.isEmpty()) { return [] }

    return this.range.map((row, column) =>
      this.tableEditor.getValueAtScreenPosition([row, column])
    )
  }

  getFlattenValue () {
    return this.getValue().reduce((m, a) => m.concat(a), [])
  }

  rowsSpan () { return this.range.end.row - this.range.start.row }

  rowsRange () {
    return [this.range.start.row, this.range.end.row]
  }

  columnsSpan () { return this.range.end.column - this.range.start.column }

  columnsRange () {
    return [this.range.start.column, this.range.end.column]
  }

  delete () {
    this.tableEditor.setValuesInScreenRange(this.range, [[undefined]])
  }

  fill (text) {
    this.tableEditor.setValuesInScreenRange(this.range, [[text]])
  }

  fillValues (values) {
    const clipboardRows = values.length
    const clipboardColumns = values[0].length

    if (clipboardRows > this.rowsSpan()) {
      this.range.end.row = this.range.start.row + clipboardRows
    }

    if (clipboardColumns > this.columnsSpan()) {
      this.range.end.column = this.range.start.column + clipboardColumns
    }

    this.tableEditor.setValuesInScreenRange(this.range, values)
  }

  copy (maintainClipboard = false, fullLine = false) {
    if (this.isEmpty()) { return }

    const values = this.getValue()
    const selectionText = values.map(a => a.join('\t')).join('\n')

    if (maintainClipboard) {
      let {text: clipboardText, metadata} = atom.clipboard.readWithMetadata()
      if (!metadata) { metadata = {} }
      if (metadata.values == null) { metadata.values = [] }
      if (metadata.selections == null) {
        metadata.selections = [{
          text: clipboardText,
          fullLine: metadata.fullLine,
          indentBasis: 0
        }]
      }

      metadata.values.push(values)

      if (atom.config.get('tablr.copyPaste.treatEachCellAsASelectionWhenPastingToABuffer')) {
        this.getFlattenValue().forEach(value =>
          metadata.selections.push({
            text: value,
            fullLine,
            indentBasis: 0
          })
        )
      } else {
        metadata.selections.push({
          text: selectionText,
          fullLine,
          indentBasis: 0
        })
      }

      atom.clipboard.write([clipboardText, selectionText].join('\n'), metadata)
    } else if (atom.config.get('tablr.copyPaste.treatEachCellAsASelectionWhenPastingToABuffer')) {
      atom.clipboard.write(selectionText, {
        values: [values],
        indentBasis: 0,
        fullLine,
        selections: this.getFlattenValue().map(value =>
          ({
            text: value,
            fullLine,
            indentBasis: 0
          }))
      })
    } else {
      atom.clipboard.write(selectionText, {
        values: [values],
        indentBasis: 0,
        fullLine
      })
    }
  }

  getFirstSelectedRow () { return this.range.start.row }

  getLastSelectedRow () { return this.range.end.row - 1 }

  getFirstSelectedColumn () { return this.range.start.column }

  getLastSelectedColumn () { return this.range.end.column - 1 }

  selectAll () {
    this.range.start.row = 0
    this.range.start.column = 0

    this.range.end.row = this.tableEditor.getScreenRowCount()
    this.range.end.column = this.tableEditor.getScreenColumnCount()
  }

  selectNone () {
    this.range = this.cursor.getRange()
  }

  expandUp (delta = 1) {
    const oldRange = this.range.copy()
    if (this.expandedDown()) {
      const newRow = this.range.end.row - delta
      if (newRow <= this.getFirstSelectedRow()) {
        this.range.end.row = this.getFirstSelectedRow() + 1
        this.range.start.row = Math.max(0, newRow)
      } else {
        this.range.end.row = newRow
      }
    } else {
      this.range.start.row = Math.max(0, this.range.start.row - delta)
    }

    if (!this.range.isEqual(oldRange)) { return this.rangeChanged(oldRange) }
  }

  expandDown (delta = 1) {
    const oldRange = this.range.copy()
    const rowCount = this.tableEditor.getScreenRowCount()
    if (this.expandedUp()) {
      const newRow = this.range.start.row + delta
      if (newRow > this.range.end.row) {
        this.range.start.row = this.getLastSelectedRow()
        this.range.end.row = Math.min(rowCount, newRow)
      } else {
        this.range.start.row = newRow
      }
    } else {
      this.range.end.row = Math.min(this.tableEditor.getScreenRowCount(), this.range.end.row + delta)
    }

    if (!this.range.isEqual(oldRange)) { return this.rangeChanged(oldRange) }
  }

  expandLeft (delta = 1) {
    const oldRange = this.range.copy()
    if (this.expandedRight()) {
      const newColumn = this.range.end.column - delta
      if (newColumn <= this.getFirstSelectedColumn()) {
        this.range.end.column = this.getFirstSelectedColumn() + 1
        this.range.start.column = Math.max(0, newColumn)
      } else {
        this.range.end.column = newColumn
      }
    } else {
      this.range.start.column = Math.max(0, this.range.start.column - delta)
    }

    if (!this.range.isEqual(oldRange)) { return this.rangeChanged(oldRange) }
  }

  expandRight (delta = 1) {
    const oldRange = this.range.copy()
    const columnCount = this.tableEditor.getScreenColumnCount()
    if (this.expandedLeft()) {
      const newColumn = this.range.start.column + delta
      if (newColumn > this.range.end.column) {
        this.range.start.column = this.getLastSelectedColumn()
        this.range.end.column = Math.min(columnCount, newColumn)
      } else {
        this.range.start.column = newColumn
      }
    } else {
      this.range.end.column = Math.min(columnCount, this.range.end.column + delta)
    }

    if (!this.range.isEqual(oldRange)) { return this.rangeChanged(oldRange) }
  }

  expandToTop () {
    const oldRange = this.range.copy()

    if (this.expandedDown()) {
      this.range.end.row = this.range.start.row + 1
      this.range.start.row = 0
    } else {
      this.range.start.row = 0
    }

    if (!this.range.isEqual(oldRange)) { return this.rangeChanged(oldRange) }
  }

  expandToBottom () {
    const oldRange = this.range.copy()

    if (this.expandedUp()) {
      this.range.start.row = this.range.end.row - 1
      this.range.end.row = this.tableEditor.getScreenRowCount()
    } else {
      this.range.end.row = this.tableEditor.getScreenRowCount()
    }

    if (!this.range.isEqual(oldRange)) { return this.rangeChanged(oldRange) }
  }

  expandToLeft () {
    const oldRange = this.range.copy()

    if (this.expandedRight()) {
      this.range.end.column = this.range.start.column + 1
      this.range.start.column = 0
    } else {
      this.range.start.column = 0
    }

    if (!this.range.isEqual(oldRange)) { return this.rangeChanged(oldRange) }
  }

  expandToRight () {
    const oldRange = this.range.copy()

    if (this.expandedLeft()) {
      this.range.start.column = this.range.end.column - 1
      this.range.end.column = this.tableEditor.getScreenColumnCount()
    } else {
      this.range.end.column = this.tableEditor.getScreenColumnCount()
    }

    if (!this.range.isEqual(oldRange)) { return this.rangeChanged(oldRange) }
  }

  expandedUp () {
    const position = this.getCursor().getPosition()
    return position.row === this.getLastSelectedRow() &&
           position.row !== this.getFirstSelectedRow()
  }

  expandedDown () {
    const position = this.getCursor().getPosition()
    return position.row === this.getFirstSelectedRow() &&
           position.row !== this.getLastSelectedRow()
  }

  expandedRight () {
    const position = this.getCursor().getPosition()
    return position.column === this.getFirstSelectedColumn() &&
           position.column !== this.getLastSelectedColumn()
  }

  expandedLeft () {
    const position = this.getCursor().getPosition()
    return position.column === this.getLastSelectedColumn() &&
           position.column !== this.getFirstSelectedColumn()
  }

  spanMoreThanOneCell () { return this.range.spanMoreThanOneCell() }

  resetRangeOnCursor () {
    const oldRange = this.range
    this.range = this.cursor.getRange()
    if (!this.range.isEqual(oldRange)) { this.rangeChanged(oldRange) }
  }

  rangeChanged (oldRange) {
    const eventObject = {
      selection: this,
      newRange: this.range,
      oldRange
    }

    this.emitter.emit('did-change-range', eventObject)
    this.tableEditor.emitter.emit('did-change-selection-range', eventObject)
  }

  serialize () { return this.range.serialize() }
}
