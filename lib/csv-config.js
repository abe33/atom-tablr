'use strict'

let _

module.exports = class CSVConfig {
  constructor (config = {}) {
    this.config = config
  }

  get (path, config) {
    return config
      ? this.config[path] && this.config[path][config]
      : this.config[path]
  }

  set (path, config, value) {
    if (this.config[path] == null) { this.config[path] = {} }
    this.config[path][config] = value
  }

  move (oldPath, newPath) {
    this.config[newPath] = this.config[oldPath]
    delete this.config[oldPath]
  }

  clear () { this.config = {} }

  clearOption (option) {
    for (let path in this.config) {
      let config = this.config[path]
      delete config[option]
    }
  }

  serialize () {
    if (!_) { _ = require('underscore-plus') }
    return _.clone(this.config)
  }
}
