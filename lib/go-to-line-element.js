'use strict'

const {SpacePenDSL} = require('atom-utils')
const element = require('./decorators/element')

class GoToLineElement extends HTMLElement {
  static initClass () {
    SpacePenDSL.Babel.includeInto(this)
    this.registerCommands()
    return element(this, 'tablr-go-to-line')
  }

  static registerCommands () {
    atom.commands.add('tablr-go-to-line', {
      'core:cancel' () { this.destroy() },
      'core:confirm' () { this.confirm() }
    })
  }

  static content () {
    this.tag('atom-text-editor', {mini: true, outlet: 'miniEditor'})
    this.div({class: 'message', outlet: 'message'}, 'Enter a cell row:column to go to. The column can be either specified with its name or its position.')
  }

  createdCallback () { this.buildContent() }

  attachedCallback () { this.miniEditor.focus() }

  attach () {
    this.panel = atom.workspace.addModalPanel({
      item: this,
      visible: true
    })
  }

  confirm () {
    const text = this.miniEditor.getModel().getText().trim()

    if (text.length > 0) {
      const result = text.split(':').map((s) => /^\d+$/.test(s) ? Number(s) : s)

      this.tableElement.goToLine(result)
    }

    this.destroy()
  }

  destroy () {
    this.panel && this.panel.destroy()
    this.tableElement.focus()
  }

  setModel (tableElement) {
    this.tableElement = tableElement
  }
}

module.exports = GoToLineElement.initClass()
