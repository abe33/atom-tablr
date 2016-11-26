const Mixin = require('mixto')

module.exports = class Identifiable extends Mixin {
  static get lastID () { return this._lastID ? this._lastID : 0 }
  static set lastID (id) { this._lastID = id }

  initID () { this.id = ++this.constructor.lastID }
}
