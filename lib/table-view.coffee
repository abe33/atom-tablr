
class TableView extends HTMLElement
  initialize: (@table) ->

module.exports = document.registerElement('table-editor', prototype: TableView.prototype, extends: 'table')
