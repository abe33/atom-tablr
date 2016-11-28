'use strict'

const {Emitter} = require('atom')
const Identifiable = require('./mixins/identifiable')
const widthConfig = 'tablr.tableEditor.columnWidth'

class DisplayColumn {
  static initClass () {
    Identifiable.includeInto(this)
    return this
  }

  get name () { return this.options.name }
  set name (newName) {
    const oldName = this.name
    this.setOption('name', newName)
    this.emitter.emit('did-change-name', {oldName, newName, column: this})
  }

  get width () { return this.options.width || atom.config.get(widthConfig) }
  set width (newWidth) { this.setOption('width', newWidth) }

  get align () { return this.options.align || 'left' }
  set align (newAlign) { this.setOption('align', newAlign) }

  get cellRender () { return this.options.cellRender }
  set cellRender (newCellRender) { this.setOption('cellRender', newCellRender) }

  get grammarScope () {
    return this.options.grammarScope || 'text.plain.null-grammar'
  }
  set grammarScope (newGrammarScope) {
    this.setOption('grammarScope', newGrammarScope)
  }

  constructor (options = {}) {
    this.options = options
    this.initID()

    this.emitter = new Emitter()
  }

  onDidChangeName (callback) {
    return this.emitter.on('did-change-name', callback)
  }

  onDidChangeOption (callback) {
    return this.emitter.on('did-change-option', callback)
  }

  setOptions (options = {}) {
    return (() => {
      let result = []
      for (let name in options) {
        let value = options[name]
        if (name !== 'name') {
          result.push(this[name] = value)
        }
      }
      return result
    })()
  }

  setOption (name, newValue, batch = false) {
    let oldValue = this[name]
    this.options[name] = newValue

    if (!batch) {
      return this.emitter.emit('did-change-option', {
        option: name,
        column: this,
        oldValue,
        newValue
      })
    }
  }
}

module.exports = DisplayColumn.initClass()
