'use strict'

const {CompositeDisposable} = require('atom')
const {EventsDelegation, SpacePenDSL} = require('atom-utils')
const element = require('./decorators/element')

class TableSelectionElement extends HTMLElement {
  static initClass () {
    EventsDelegation.includeInto(this)
    SpacePenDSL.Babel.includeInto(this)
    return element(this, 'tablr-editor-selection')
  }

  static content () {
    this.div({
      class: 'selection-box-handle',
      outlet: 'selectionBoxHandle'
    })
  }

  createdCallback () {
    this.buildContent()
    this.subscriptions = new CompositeDisposable()
  }

  getModel () { return this.selection }

  setModel (selection) {
    this.selection = selection
    this.tableEditor = selection.tableEditor

    this.subscriptions.add(this.selection.onDidDestroy(() => this.destroy()))
    this.subscriptions.add(this.selection.onDidChangeRange(() => this.update()))

    this.update()
  }

  destroy () {
    if (this.destroyed) { return }

    this.parentNode && this.parentNode.removeChild(this)
    this.subscriptions.dispose()
    this.selection = this.tableEditor = null
    this.destroyed = true
  }

  update () {
    if (this.selection.spanMoreThanOneCell()) {
      const {top, left, right, bottom} = this.selectionScrollRect()
      const height = bottom - top
      const width = right - left
      this.style.cssText = `
        top: ${top}px;
        left: ${left}px;
        height: ${height}px;
        width: ${width}px;
      `
    } else {
      this.style.cssText = 'display: none'
    }
  }

  selectionScrollRect () {
    const range = this.selection.getRange()

    return {
      left: this.tableEditor.getScreenColumnOffsetAt(range.start.column),
      top: this.tableEditor.getScreenRowOffsetAt(range.start.row),
      right: this.tableEditor.getScreenColumnOffsetAt(range.end.column - 1) + this.tableEditor.getScreenColumnWidthAt(range.end.column - 1),
      bottom: this.tableEditor.getScreenRowOffsetAt(range.end.row - 1) + this.tableEditor.getScreenRowHeightAt(range.end.row - 1)
    }
  }
}

module.exports = TableSelectionElement.initClass()
