'use strict'

const {Emitter} = require('atom')

module.exports = class CursorSelectionBinding {
  constructor ({cursor, selection}) {
    this.cursor = cursor
    this.selection = selection
    this.emitter = new Emitter()
  }

  onDidDestroy (callback) {
    return this.emitter.on('did-destroy', callback)
  }

  destroy () {
    this.emitter.emit('did-destroy', this)
    this.emitter.dispose()
  }
}
