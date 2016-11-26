'use strict'

const { SpacePenDSL } = require('atom-utils')
const element = require('./decorators/element')

let byteUnits = ['B', 'kB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB']

class CSVProgressElement extends HTMLElement {
  static initClass () {
    SpacePenDSL.Babel.includeInto(this)
    return element(this, 'atom-csv-progress')
  }

  static content () {
    this.div({class: 'wrapper'}, () => {
      this.label({class: 'bytes', outlet: 'bytesLabel'}, '---')
      this.label({class: 'lines', outlet: 'linesLabel'}, '---')
      this.div({class: 'block'}, () => {
        this.tag('progress', {max: '100', outlet: 'progress'})
      })
    })
  }

  createdCallback () {
    this.buildContent()
  }

  updateReadData (input, lines) {
    const {total, length, ratio} = input.getProgress()
    const byteScale = this.getByteScale(total)
    const byteDivider = Math.max(1, Math.pow(1000, byteScale))
    const unit = this.getUnit(byteScale)

    this.linesLabel.textContent = `${lines} ${lines === 1 ? 'line' : 'lines'}`
    this.bytesLabel.textContent = `${(length / byteDivider).toFixed(1)}/${(total / byteDivider).toFixed(1)}${unit}`
    this.progress.setAttribute('value', Math.floor(ratio * 100))
  }

  getByteScale (size) {
    let i = 0

    while (size > 1000) {
      size = size / 1000
      i++
    }

    return i
  }

  getUnit (scale) { return byteUnits[scale] }

  updateFillTable (lines, ratio) {
    this.linesLabel.textContent = `${lines} ${lines === 1 ? 'row' : 'rows'} added`
    this.bytesLabel.textContent = ''
    this.progress.setAttribute('value', Math.floor(ratio * 100))
  }
}

module.exports = CSVProgressElement.initClass()
