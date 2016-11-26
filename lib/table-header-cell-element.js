'use strict'

const {CompositeDisposable} = require('atom')
const {SpacePenDSL} = require('atom-utils')
const columnName = require('./column-name')
const element = require('./decorators/element')

class TableHeaderCellElement extends HTMLElement {
  static initClass () {
    SpacePenDSL.Babel.includeInto(this)
    return element(this, 'tablr-header-cell')
  }

  static content () {
    this.span({outlet: 'label'})
    this.div({class: 'column-actions'}, () => {
      this.button({class: 'column-fit-action', outlet: 'fitButton'})
      this.button({class: 'column-apply-sort-action', outlet: 'sortButton'})
      this.button({class: 'column-edit-action', outlet: 'editButton'})
    })
    this.div({class: 'column-resize-handle'})
  }

  createdCallback () {
    this.buildContent()
    this.subscriptions = new CompositeDisposable()
    this.subscriptions.add(atom.tooltips.add(this.editButton, {
      title: 'Edit column name'
    }))
    this.subscriptions.add(atom.tooltips.add(this.fitButton, {
      title: 'Adjust width to content'
    }))
    this.subscriptions.add(atom.tooltips.add(this.sortButton, {
      title: 'Apply sort on table'
    }))
  }

  setModel ({column, index}) {
    this.released = false

    const classes = this.getHeaderCellClasses(column, index)
    const align = this.tableEditor.getScreenColumnAlignAt(index)
    this.label.textContent = column.name != null
      ? column.name
      : columnName(index)
    this.className = classes.join(' ')
    this.dataset.column = index
    this.style.cssText = `
      width: ${this.tableEditor.getScreenColumnWidthAt(index)}px;
      left: ${this.tableEditor.getScreenColumnOffsetAt(index)}px;
      text-align: ${align != null ? align : 'left'};
    `
  }

  isReleased () { return this.released }

  release (dispatchEvent = true) {
    if (this.released) { return }
    this.style.cssText = 'display: none'
    this.released = true
  }

  getHeaderCellClasses (column, index) {
    const classes = []
    this.tableElement.isCursorColumn(index) && classes.push('active-column')
    this.tableElement.isSelectedColumn(index) && classes.push('selected')

    if (this.tableEditor.order === index) {
      classes.push('order')

      this.tableEditor.direction === 1
        ? classes.push('ascending')
        : classes.push('descending')
    }

    return classes
  }
}

module.exports = TableHeaderCellElement.initClass()
