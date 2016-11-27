'use strict'

const {SpacePenDSL} = require('atom-utils')
const element = require('./decorators/element')

class TableGutterCellElement extends HTMLElement {
  static initClass () {
    SpacePenDSL.Babel.includeInto(this)
    return element(this, 'tablr-gutter-cell')
  }

  static content () {
    this.div({class: 'row-resize-handle'})
    this.span({outlet: 'label'})
  }

  createdCallback () { this.buildContent() }

  setModel ({row}) {
    this.released = false
    const classes = this.getGutterCellClasses(row)
    this.label.textContent = row + 1
    this.className = classes.join(' ')
    this.style.cssText = `
      height: ${this.tableEditor.getScreenRowHeightAt(row)}px;
      top: ${this.tableEditor.getScreenRowOffsetAt(row)}px;
    `
  }

  isReleased () { return this.released }

  release (dispatchEvent = true) {
    if (this.released) { return }
    this.style.cssText = 'display: none'
    this.released = true
  }

  getGutterCellClasses (row) {
    const classes = []
    this.tableElement.isCursorRow(row) && classes.push('active-row')
    this.tableElement.isSelectedRow(row) && classes.push('selected')
    return classes
  }
}

module.exports = TableGutterCellElement.initClass()
