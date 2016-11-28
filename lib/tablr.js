'use strict'

let _, url, CompositeDisposable, Range, Table, DisplayTable, TableEditor, Selection, TableElement, TableSelectionElement, CSVConfig, CSVEditor, CSVEditorElement

module.exports = {
  activate ({csvConfig}) {
    if (!CompositeDisposable) { ({ CompositeDisposable } = require('atom')) }
    if (!CSVConfig) { CSVConfig = require('./csv-config') }

    this.csvConfig = new CSVConfig(csvConfig)
    this.subscriptions = new CompositeDisposable()

    if (atom.inDevMode()) {
      this.subscriptions.add(atom.commands.add('atom-workspace', {
        'tablr:demo-large' () { return atom.workspace.open('tablr://large') },
        'tablr:demo-small' () { return atom.workspace.open('tablr://small') }
      }))
    }

    this.subscriptions.add(atom.commands.add('atom-workspace', {
      'tablr:clear-csv-storage': () => this.csvConfig.clear(),
      'tablr:clear-csv-choice': () => this.csvConfig.clearOption('choice'),
      'tablr:clear-csv-layout': () => this.csvConfig.clearOption('layout')
    }))

    this.subscriptions.add(atom.workspace.addOpener(uriToOpen => {
      const extensions = atom.config.get('tablr.supportedCsvExtensions') ||
                         ['csv', 'tsv', 'CSV', 'TSV']

      if (!new RegExp(`\\.(${extensions.join('|')})$`).test(uriToOpen)) {
        return
      }

      if (!_) { _ = require('underscore-plus') }
      if (!CSVEditor) { CSVEditor = require('./csv-editor') }

      const choice = this.csvConfig.get(uriToOpen, 'choice')
      const options = _.clone(this.csvConfig.get(uriToOpen, 'options') || {})

      if (choice === 'TextEditor') {
        return atom.workspace.openTextFile(uriToOpen)
      }

      return new CSVEditor({filePath: uriToOpen, options, choice})
    }))

    this.subscriptions.add(atom.workspace.addOpener(uriToOpen => {
      if (!url) { url = require('url') }

      const {protocol, host} = url.parse(uriToOpen)
      if (protocol !== 'tablr:') { return }

      switch (host) {
        case 'large': return this.getLargeTable()
        case 'small': return this.getSmallTable()
      }
    }))

    this.subscriptions.add(atom.contextMenu.add({
      'tablr-editor': [{
        label: 'Tablr',
        created (event) {
          const {pageX, pageY, target} = event
          if ((target.getScreenColumnIndexAtPixelPosition == null) || (target.getScreenRowIndexAtPixelPosition == null)) { return }

          const contextMenuColumn = target.getScreenColumnIndexAtPixelPosition(pageX)
          const contextMenuRow = target.getScreenRowIndexAtPixelPosition(pageY)

          this.submenu = []

          if (contextMenuRow != null && contextMenuRow >= 0) {
            target.contextMenuRow = contextMenuRow

            this.submenu.push({
              label: 'Fit Row Height To Content',
              command: 'tablr:fit-row-to-content'
            })
          }

          if (contextMenuColumn != null && contextMenuColumn >= 0) {
            target.contextMenuColumn = contextMenuColumn

            this.submenu.push({
              label: 'Fit Column Width To Content',
              command: 'tablr:fit-column-to-content'
            })
            this.submenu.push({type: 'separator'})
            this.submenu.push({
              label: 'Align left',
              command: 'tablr:align-left'
            })
            this.submenu.push({
              label: 'Align center',
              command: 'tablr:align-center'
            })
            this.submenu.push({
              label: 'Align right',
              command: 'tablr:align-right'
            })
          }

          setTimeout(() => {
            delete target.contextMenuColumn
            delete target.contextMenuRow
          }, 10)
        }
      }]
    }))
  },

  deactivate () {
    this.subscriptions.dispose()
  },

  provideTablrModelsServiceV1 () {
    if (!Range) { Range = require('./range') }
    if (!Table) { Table = require('./table') }
    if (!DisplayTable) { DisplayTable = require('./display-table') }
    if (!TableEditor) { TableEditor = require('./table-editor') }
    if (!CSVEditor) { CSVEditor = require('./csv-editor') }

    return {Table, DisplayTable, TableEditor, Range, CSVEditor}
  },

  deserializeCSVEditor (state) {
    if (!CSVEditor) { CSVEditor = require('./csv-editor') }
    return CSVEditor.deserialize(state)
  },

  deserializeTableEditor (state) {
    if (!TableEditor) { TableEditor = require('./table-editor') }
    return TableEditor.deserialize(state)
  },

  deserializeDisplayTable (state) {
    if (!DisplayTable) { DisplayTable = require('./display-table') }
    return DisplayTable.deserialize(state)
  },

  deserializeTable (state) {
    if (!Table) { Table = require('./table') }
    return Table.deserialize(state)
  },

  tablrViewProvider (model) {
    if (!TableEditor) { TableEditor = require('./table-editor') }
    if (!Selection) { Selection = require('./selection') }
    if (!CSVEditor) { CSVEditor = require('./csv-editor') }

    let element
    if (model instanceof TableEditor) {
      if (!TableElement) { TableElement = require('./table-element') }
      element = new TableElement()
    } else if (model instanceof Selection) {
      if (!TableSelectionElement) { TableSelectionElement = require('./table-selection-element') }
      element = new TableSelectionElement()
    } else if (model instanceof CSVEditor) {
      if (!CSVEditorElement) { CSVEditorElement = require('./csv-editor-element') }
      element = new CSVEditorElement()
    }

    if (element) {
      element.setModel(model)
      return element
    }
  },

  getSmallTable () {
    if (!TableEditor) { TableEditor = require('./table-editor') }

    const table = new TableEditor()

    table.lockModifiedStatus()
    table.addColumn('key', {width: 150, align: 'right'})
    table.addColumn('value', {width: 150, align: 'center', grammarScope: 'source.js'})
    table.addColumn('locked', {width: 150, align: 'left'})

    const rows = new Array(100).fill().map((v, i) => [
      `row${i}`,
      Math.random() * 100,
      i % 2 === 0 ? 'yes' : 'no'
    ])

    table.addRows(rows)

    table.clearUndoStack()
    table.initializeAfterSetup()
    table.unlockModifiedStatus()
    return table
  },

  getLargeTable () {
    if (!TableEditor) { TableEditor = require('./table-editor') }

    const table = new TableEditor()

    table.lockModifiedStatus()
    table.addColumn('key', {width: 150, align: 'right'})
    table.addColumn('value', {width: 150, align: 'center', grammarScope: 'source.js'})
    for (let i = 0; i <= 100; i++) {
      table.addColumn(undefined, {width: 150, align: 'left'})
    }

    const rows = new Array(1000).fill().map((v, i) => {
      return [`row${i}`].concat(new Array(101).fill().map((vv, j) =>
        j % 2 === 0
          ? (i % 2 === 0 ? 'yes' : 'no')
          : Math.random() * 100
      ))
    })

    table.addRows(rows)

    table.clearUndoStack()
    table.initializeAfterSetup()
    table.unlockModifiedStatus()

    return table
  },

  serialize () {
    return {csvConfig: this.csvConfig.serialize()}
  }
}
