'use strict'

const Mixin = require('mixto')

module.exports = class Identifiable extends Mixin {
  initID () {
    if (!this.constructor.lastID) { this.constructor.lastID = 0 }
    this.id = ++this.constructor.lastID
  }
}
