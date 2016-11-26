'use strict'

module.exports = function include (target, source) {
  Object.getOwnPropertyNames(source).forEach((k) => {
    if (['length', 'name', 'arguments', 'caller', 'prototype', 'includeInto'].indexOf(k) >= 0) { return }

    let descriptor = Object.getOwnPropertyDescriptor(source, k)
    Object.defineProperty(target, k, descriptor)
  })

  Object.getOwnPropertyNames(source.prototype).forEach((k) => {
    if (k === 'constructor') { return }

    let descriptor = Object.getOwnPropertyDescriptor(source.prototype, k)
    Object.defineProperty(target.prototype, k, descriptor)
  })
}
