'use strict'

const element = require('./decorators/element')

class TableCellElement extends HTMLElement {
  static initClass () {
    return element(this, 'tablr-cell')
  }

  setModel (model) {
    this.model = model
    this.released = false
    const {cell, column, row} = this.model

    this.className = this.getCellClasses(cell, column, row).join(' ')
    this.dataset.row = row
    this.dataset.column = column
    this.style.cssText = `
      width: ${this.tableEditor.getScreenColumnWidthAt(column)}px;
      left: ${this.tableEditor.getScreenColumnOffsetAt(column)}px;
      height: ${this.tableEditor.getScreenRowHeightAt(row)}px;
      top: ${this.tableEditor.getScreenRowOffsetAt(row)}px;
      text-align: ${this.tableEditor.getScreenColumnAlignAt(column)};
    `
    if (cell.column.cellRender != null) {
      this.innerHTML = cell.column.cellRender(cell, [row, column])
    } else {
      this.textContent = cell.value != null ? cell.value : this.tableElement.getUndefinedDisplay()
    }

    this.lastRow = row
    this.lastColumn = column
    this.lastValue = cell.value
  }

  isReleased () { return this.released }

  release (dispatchEvent = true) {
    if (this.released) { return }
    this.style.cssText = 'display: none'
    delete this.dataset.rowId
    delete this.dataset.columnId
    this.released = true
  }

  getCellClasses (cell, column, row) {
    const classes = ['tablr-cell']
    this.tableElement.isCursorCell([row, column]) && classes.push('active')
    this.tableElement.isSelectedCell([row, column]) && classes.push('selected')
    return classes
  }

  isSameCell (cell, column, row) {
    return cell.value === this.lastValue &&
           column === this.lastColumn &&
           row === this.lastRow
  }
}

module.exports = TableCellElement.initClass()
