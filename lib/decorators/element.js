'use strict'

const {registerOrUpdateElement} = require('atom-utils')

module.exports = function element (cls, elementName) {
  return registerOrUpdateElement(elementName, {class: cls})
}
