'use strict'

const vm = require('vm')
const Mixin = require('mixto')
const include = require('../decorators/include')
const capitalize = s => s[0].toUpperCase() + s.slice(1)

module.exports = class Pool {
  static includeInto (cls) { include(cls, this) }

  static pool (singular, plural) {
    const Singular = capitalize(singular)
    const Plural = capitalize(plural)

    const source = `(class ${Plural}Pool extends Mixin {
      init${Plural}Pool (${plural}Class, ${plural}Container) {
        this.${plural}Class = ${plural}Class
        this.${plural}Container = ${plural}Container
        if (this.used${Plural} == null) { this.used${Plural} = [] }
        return this.unused${Plural} != null
          ? this.unused${Plural}
          : (this.unused${Plural} = [])
      }

      request${Singular} (model) {
        let instance
        if (this.unused${Plural}.length) {
          instance = this.unused${Plural}.shift()
        } else {
          instance = new this.${plural}Class
          this.${plural}Container.appendChild(instance)
        }

        instance.tableElement = this
        instance.tableEditor = this.getModel()
        instance.setModel(model)
        this.used${Plural}.push(instance)

        return instance
      }

      release${Singular} (instance) {
        if (instance.isReleased()) { return }

        this.used${Plural}.splice(this.used${Plural}.indexOf(instance), 1)
        this.unused${Plural}.push(instance)
        instance.release(false)
      }

      total${Singular}Count () {
        return this.used${Plural}.length + this.unused${Plural}.length
      }

      clear${Plural} () {
        for (let instance of this.used${Plural}) { instance.release(false) }
        this.used${Plural} = []
        return this.unused${Plural} = []
      }
    })`

    const sandbox = {Mixin, atom, console}
    const context = vm.createContext(sandbox)

    const mixin = vm.runInContext(source, context, `${plural}-pool.vm`)
    mixin.includeInto(this)
  }
}
