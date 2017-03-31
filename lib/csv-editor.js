'use strict'

const _ = require('underscore-plus')
const fs = require('fs')
const csv = require('csv')
const path = require('path')
const stream = require('stream')
const { File, CompositeDisposable, Emitter } = require('atom')
const TableEditor = require('./table-editor')
const Table = require('./table')
let Tablr, iconv

const trimMapping = {
  left: 'ltrim',
  right: 'rtrim',
  both: 'trim'
}

class CSVEditor {
  static initClass () {
    this.tableEditorForPath = {}
    return this
  }

  static deserialize (state) {
    let csvEditor = new CSVEditor(state)
    csvEditor.applyChoice()
    return csvEditor
  }

  constructor (state = {}) {
    let filePath
    ({filePath, options: this.options, choice: this.choice, layout: this.layout, editor: this.editorState} = state)

    if (!Tablr) { Tablr = require('./tablr') }
    if (this.options == null) { this.options = {} }

    const optionDefaultFromConfig = (option, config = option) => {
      if (!this.options[option]) {
        this.options[option] = atom.config.get(`tablr.csvEditor.${config}`)
      }
    }

    optionDefaultFromConfig('delimiter', 'columnDelimiter')
    optionDefaultFromConfig('rowDelimiter')
    optionDefaultFromConfig('escape')
    optionDefaultFromConfig('comment')
    optionDefaultFromConfig('quote')
    optionDefaultFromConfig('fileEncoding', 'encodings')
    optionDefaultFromConfig('header')
    optionDefaultFromConfig('eof')
    optionDefaultFromConfig('quoted')
    optionDefaultFromConfig('skip_empty_lines', 'skipEmptyLines')

    if (this.options.rowDelimiter === 'auto') {
      delete this.options.rowDelimiter
    }

    if (!this.options.ltrim && !this.options.rtrim && !this.options.trim) {
      this.options[trimMapping[atom.config.get('tablr.csvEditor.trim')]] = true
    }

    this.emitter = new Emitter()
    this.setPath(filePath)
  }

  setPath (filePath) {
    if (filePath === this.getPath()) { return }

    if (filePath) {
      this.file = new File(filePath)
      this.previousPath = filePath
      this.subscribeToFile()
    } else {
      delete this.file
    }

    this.emitter.emit('did-change-path', this.getPath())
    this.emitter.emit('did-change-title', this.getTitle())
  }

  getTitle () {
    const sessionPath = this.getPath()
    if (sessionPath) {
      return path.basename(sessionPath)
    } else {
      return 'untitled'
    }
  }

  getLongTitle () {
    const sessionPath = this.getPath()

    if (sessionPath) {
      const fileName = path.basename(sessionPath)
      let directory = atom.project.relativize(path.dirname(sessionPath))
      directory = directory.length > 0
        ? directory
        : path.basename(path.dirname(sessionPath))

      return `${fileName} - ${directory}`
    } else {
      return 'untitled'
    }
  }

  getPath () { return this.file && this.file.getPath() }

  getURI () { return this.getPath() }

  isDestroyed () { return this.destroyed }

  isModified () { return this.editor && this.editor.isModified() }

  copy () {
    return new CSVEditor({
      filePath: this.getPath(),
      options: _.clone(this.options),
      choice: this.choice
    })
  }

  destroy () {
    if (this.destroyed) { return }

    if (this.editor) {
      this.saveLayout()
      this.editor.destroy()
    }

    this.fileSubscriptions && this.fileSubscriptions.dispose()
    this.editorSubscriptions && this.editorSubscriptions.dispose()
    this.destroyed = true
    this.emitter.emit('did-destroy', this)
    this.emitter.dispose()
  }

  save () { return this.saveAs(this.getPath()) }

  saveAs (path) {
    return new Promise((resolve, reject) => {
      const options = _.clone(this.options)
      if (options.header) { options.columns = this.editor.getColumns() }

      this.setPath(path)
      this.saveLayout()

      csv.stringify(this.editor.getTable().getRows(), options, (err, data) => {
        if (err) { return reject(err) }

        this.preventFileChangeEvents()
        this.file.writeFile(path, data).then(() => {
          resolve()
        })
        .catch(err => {
          this.allowFileChangeEvents()
          reject(err)
        })
      })
    })
  }

  saveConfig (choice) {
    this.choice = choice
    const filePath = this.getPath()
    Tablr.csvConfig.set(filePath, 'options', this.options)
    if (this.options.remember && (this.choice != null)) {
      Tablr.csvConfig.set(filePath, 'choice', this.choice)
    }
  }

  saveLayout () {
    this.layout = this.getCurrentLayout()

    Tablr.csvConfig.set(this.getPath(), 'layout', this.layout)
  }

  shouldPromptToSave (options) {
    return this.editor && this.editor.shouldPromptToSave(options)
  }

  terminatePendingState () {
    if (!this.hasTerminatedPendingState) { this.emitter.emit('did-terminate-pending-state') }
    this.hasTerminatedPendingState = true
  }

  onWillOpen (callback) {
    return this.emitter.on('will-open', callback)
  }

  onDidReadData (callback) {
    return this.emitter.on('did-read-data', callback)
  }

  onDidOpen (callback) {
    return this.emitter.on('did-open', callback)
  }

  onDidFailOpen (callback) {
    return this.emitter.on('did-fail-open', callback)
  }

  onWillFillTable (callback) {
    return this.emitter.on('will-fill-table', callback)
  }

  onFillTable (callback) {
    return this.emitter.on('fill-table', callback)
  }

  onDidFillTable (callback) {
    return this.emitter.on('did-fill-table', callback)
  }

  onDidDestroy (callback) {
    return this.emitter.on('did-destroy', callback)
  }

  onDidConflict (callback) {
    return this.emitter.on('did-conflict', callback)
  }

  onDidChange (callback) {
    return this.emitter.on('did-change', callback)
  }

  onDidChangeModified (callback) {
    return this.emitter.on('did-change-modified', callback)
  }

  onDidChangePath (callback) {
    return this.emitter.on('did-change-path', callback)
  }

  onDidChangeTitle (callback) {
    return this.emitter.on('did-change-title', callback)
  }

  onDidTerminatePendingState (callback) {
    return this.emitter.on('did-terminate-pending-state', callback)
  }

  applyChoice () {
    const choices = {
      TextEditor: () => this.openTextEditor(this.options),
      TableEditor: () => this.openTableEditor(this.options)
    }
    if (this.choiceApplied) { return }
    if (this.choice) {
      choices[this.choice]()
      this.choiceApplied = true
    }
  }

  openTextEditor (options = {}) {
    this.options = options
    const filePath = this.getPath()
    return atom.workspace.openTextFile(filePath).then(editor => {
      const pane = atom.workspace.paneForItem(this)
      this.emitter.emit('did-open', {editor, options: _.clone(this.options)})
      this.saveConfig('TextEditor')
      this.destroy()

      pane.activateItem(editor)
    })
  }

  openTableEditor (options = {}) {
    this.options = options
    this.emitter.emit('will-open', {options: _.clone(this.options)})

    return this.openCSV().then(editor => {
      this.editor = editor
      this.subscribeToEditor()

      this.emitter.emit('did-open', {editor: this.editor, options: _.clone(this.options)})
      this.emitter.emit('did-change-modified', this.editor.isModified())
      this.terminatePendingState()

      this.saveConfig('TableEditor')
      return this.editor
    })
    .catch(err => {
      this.emitter.emit('did-fail-open', {err, options: _.clone(this.options)})
    })
  }

  subscribeToEditor () {
    this.editorSubscriptions = new CompositeDisposable()
    this.editorSubscriptions.add(this.editor.onDidChangeModified(status => {
      this.emitter.emit('did-change-modified', status)
    }))
  }

  subscribeToFile () {
    this.fileSubscriptions && this.fileSubscriptions.dispose()

    this.fileSubscriptions = new CompositeDisposable()

    let changeFired = false
    const debounceChange = () => {
      setTimeout(() => {
        changeFired = false
        this.allowFileChangeEvents()
      }, 100)
    }

    this.fileSubscriptions.add(this.file.onDidChange(() => {
      if (changeFired) { return }
      changeFired = true

      if (this.nofileChangeEvent) { return }

      if (this.editor != null) {
        if (this.editor.isModified()) {
          this.emitter.emit('did-conflict', this)
          debounceChange()
        } else {
          const filePath = this.getPath()
          const options = _.clone(this.options)
          const layout = this.layout || (Tablr.csvConfig && Tablr.csvConfig.get(filePath, 'layout'))

          this.getTableEditor(options, layout).then(tableEditor => {
            CSVEditor.tableEditorForPath[filePath] = tableEditor
            this.editorSubscriptions.dispose()
            this.editor = tableEditor
            this.subscribeToEditor()
            this.emitter.emit('did-change', this)
            debounceChange()
          })
          .catch(() => {
            // The file content has changed for a format that cannot be parsed
            // We drop the editor and replace it with the csv form
            this.editorSubscriptions.dispose()
            this.editor.destroy()
            delete this.editor
            this.emitter.emit('did-change', this)
            debounceChange()
          }
          )
        }
      } else {
        this.emitter.emit('did-change', this)
        debounceChange()
      }
    }))

    // @fileSubscriptions.add @file.onDidDelete =>
    //   console.log 'deleted'

    this.fileSubscriptions.add(this.file.onDidRename(() => {
      const newPath = this.getPath()
      Tablr.csvConfig.move(this.previousPath, newPath)

      this.emitter.emit('did-change-path', newPath)
      this.emitter.emit('did-change-title', this.getTitle())
      this.previousPath = newPath
    }))
  }

    // @fileSubscriptions.add @file.onWillThrowWatchError (errorObject) =>
    //   console.log 'error', errorObject

  getCurrentLayout () {
    return {
      columns: this.editor.getScreenColumns().map(column => {
        const conf = {}
        if (column.width !== this.editor.getScreenColumnWidth()) {
          conf.width = column.width
        }

        if (column.align !== 'left') {
          conf.align = column.align
        }

        return conf
      }),
      rowHeights: this.editor.displayTable.rowHeights.slice()
    }
  }

  openCSV () {
    return new Promise((resolve, reject) => {
      const filePath = this.getPath()
      const previousEditor = CSVEditor.tableEditorForPath[filePath]
      if (previousEditor && previousEditor.table) {
        const {table, displayTable} = CSVEditor.tableEditorForPath[filePath]
        const tableEditor = new TableEditor({table, displayTable})

        resolve(tableEditor)
      } else if (this.editorState) {
        const tableEditor = atom.deserializers.deserialize(this.editorState)
        this.editorState = null
        resolve(tableEditor)
      } else {
        const options = _.clone(this.options)
        const layout = this.layout || (Tablr.csvConfig && Tablr.csvConfig.get(filePath, 'layout'))

        this.getTableEditor(options, layout).then(tableEditor => {
          CSVEditor.tableEditorForPath[filePath] = tableEditor
          resolve(tableEditor)
        })
        .catch(err => reject(err))
      }
    })
  }

  getTableEditor (options, layout) {
    return new Promise((resolve, reject) => {
      const output = []
      const input = this.createReadStream(options)
      let length = 0

      const onerror = err => reject(err)

      const read = () => {
        let record
        while ((record = input.read())) {
          output.push(record)
          length = Math.max(length, record.length)
        }

        this.emitter.emit('did-read-data', {input, lines: output.length})
      }

      const end = () => {
        const table = new Table()

        if (output.length === 0) {
          const tableEditor = new TableEditor({table})
          tableEditor.setSaveHandler(() => this.save())
          tableEditor.initializeAfterSetup()
          resolve(tableEditor)
        }

        table.lockModifiedStatus()

        if (options.header) {
          const iterable = output.shift()
          if (iterable) {
            iterable.forEach((column) => table.addColumn(column, false))
          }
        } else {
          for (let i = 0; i < length; i++) {
            table.addColumn(undefined, false)
          }
        }

        this.emitter.emit('will-fill-table', {table})
        return this.fillTable(table, output).then(() => {
          this.emitter.emit('did-fill-table', {table})
          const tableEditor = new TableEditor({table})

          if (layout != null) {
            for (let i = 0; i < length; i++) {
              const opts = layout.columns[i]
              if (opts) { tableEditor.setScreenColumnOptions(i, opts) }
            }
            tableEditor.displayTable.setRowHeights(layout.rowHeights)
          }

          tableEditor.setSaveHandler(() => this.save())
          tableEditor.initializeAfterSetup()
          tableEditor.unlockModifiedStatus()
          resolve(tableEditor)
        })
        .catch(onerror)
      }

      input.on('readable', read)
      input.on('end', end)
      input.on('error', onerror)
    })
  }

  fillTable (table, rows) {
    const batchSize = atom.config.get('tablr.csvEditor.tableCreationBatchSize')
    return new Promise((resolve, reject) => {
      if (rows.length <= batchSize) {
        table.addRows(rows, false)
        this.emitter.emit('fill-table', {table})
        resolve()
      } else {
        const fill = () => {
          const currentRows = rows.splice(0, batchSize)
          table.addRows(currentRows, false)
          this.emitter.emit('fill-table', {table})

          rows.length > 0
            ? requestAnimationFrame(() => fill(table, rows))
            : resolve()
        }

        fill()
      }
    })
  }

  previewCSV (options) {
    return new Promise((resolve, reject) => {
      const output = []
      const input = this.createReadStream(options)
      let limit = atom.config.get('tablr.csvEditor.maximumRowsInPreview')
      if (options.header) { limit += 1 }

      const stop = () => {
        input.stop()
        input.removeListener('readable', read)
        input.removeListener('end', end)
        // input.removeListener 'error', error
        resolve(output.slice(0, limit))
      }

      const read = () => {
        let record
        while ((record = input.read())) { output.push(record) }
        if (output.length > limit) { stop() }
      }

      const end = () => resolve(output.slice(0, limit))
      const error = err => reject(err)

      input.on('readable', read)
      input.on('end', end)
      input.on('error', error)
    })
  }

  createReadStream (options) {
    const encoding = options.fileEncoding || 'utf8'
    const filePath = this.file.getPath()
    this.file.setEncoding(encoding)
    let input

    if (encoding === 'utf8') {
      input = fs.createReadStream(filePath, {encoding})
    } else {
      if (!iconv) { iconv = require('iconv-lite') }
      input = fs.createReadStream(filePath).pipe(iconv.decodeStream(encoding))
    }

    const { size } = fs.lstatSync(filePath)
    const parser = csv.parse(options)
    let length = 0

    const counter = new stream.Transform({
      transform (chunk, encoding, callback) {
        length += chunk.length
        this.push(chunk)
        callback()
      }
    })

    input.pipe(counter).pipe(parser)

    parser.stop = () => {
      input.unpipe(counter)
      counter.unpipe(parser)
      parser.end()
    }

    parser.getProgress = () => ({length, total: size, ratio: length / size})

    return parser
  }

  preventFileChangeEvents () { this.nofileChangeEvent = true }

  allowFileChangeEvents () { this.nofileChangeEvent = false }

  serialize () {
    const out = {
      deserializer: 'CSVEditor',
      filePath: this.getPath(),
      options: this.options,
      choice: this.choice
    }
    if (this.isModified()) {
      out.editor = this.editor.serialize()
    } else if (this.editor) {
      out.layout = this.getCurrentLayout()
    }
    return out
  }
}

module.exports = CSVEditor.initClass()
