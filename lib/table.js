'use strict'

const {Point, Emitter} = require('atom')
const Identifiable = require('./mixins/identifiable')
const Transactions = require('./mixins/transactions')
const Range = require('./range')

const getAtPosition = (a, p) => a[p.row] && a[p.row][p.column]
const setAtPosition = (a, p, v) => a[p.row] && (a[p.row][p.column] = v)

class Table {
  static initClass () {
    Identifiable.includeInto(this)
    Transactions.includeInto(this)

    this.MAX_HISTORY_SIZE = 100
    return this
  }

  static deserialize (state) {
    const table = new Table(state)
    table.initializeAfterSetup()
    return table
  }

  constructor (state = {}) {
    let modified
    ({id: this.id, columns: this.columns, rows: this.rows, modified} = state)
    if (modified) { this.cachedContents = state.cachedContents || '' }
    if (this.id == null) { this.initID() }
    if (this.columns == null) { this.columns = [] }
    if (this.rows == null) { this.rows = [] }
    this.emitter = new Emitter()
    this.refcount = 0
  }

  destroy () {
    if (this.destroyed) { return }
    this.emitter.emit('did-destroy', this)
    this.emitter.dispose()
    this.columns = []
    this.rows = []
    this.destroyed = true
  }

  hasMultipleEditors () { return this.refcount > 0 }

  isModified () { return this.cachedContents !== this.getCacheContent() }

  isDestroyed () { return this.destroyed }

  isRetained () { return this.refcount > 0 }

  retain () { this.refcount++ }

  release () {
    this.refcount--
    if (!this.isRetained()) { this.destroy() }
  }

  save () {
    if (!this.lastModified) { return }

    this.emitter.emit('will-save', this)

    if (this.saveHandler != null) {
      let saved = this.saveHandler(this)
      if (saved instanceof Promise) {
        saved.then(() => {
          this.updateCachedContents()
          this.emitter.emit('did-save', this)
          this.emitModifiedStatusChange()
        })
        saved.catch(reason => console.error(reason))
      } else {
        this.emitModifiedStatusChange()

        if (saved) {
          this.updateCachedContents()
          this.emitter.emit('did-save', this)
        }
      }
    } else {
      this.updateCachedContents()
      this.emitter.emit('did-save', this)
      this.emitModifiedStatusChange()
    }
  }

  serialize () {
    const out = {
      columns: this.columns.map(c => c || null),
      rows: this.rows,
      id: this.id,
      deserializer: 'Table'
    }

    if (this.lastModified) {
      out.modified = true
      out.cachedContents = this.cachedContents
    }

    return out
  }

  setSaveHandler (saveHandler) {
    this.saveHandler = saveHandler
  }

  updateCachedContents () {
    this.cachedContents = this.getCacheContent()
  }

  getCacheContent () {
    return JSON.stringify([this.columns].concat(this.rows))
  }

  initializeAfterSetup () {
    this.clearUndoStack()
    if (this.cachedContents == null) { this.updateCachedContents() }
    this.lastModified = false
  }

  lockModifiedStatus () {
    this.modifiedLock = true
  }

  unlockModifiedStatus () {
    this.modifiedLock = false
    this.emitModifiedStatusChange()
  }

  emitModifiedStatusChange () {
    if (this.modifiedLock) { return }

    let modified = this.isModified()
    if (this.lastModified === modified) { return }

    this.emitter.emit('did-change-modified', modified)
    this.lastModified = modified
  }

  //    ######## ##     ## ######## ##    ## ########  ######
  //    ##       ##     ## ##       ###   ##    ##    ##    ##
  //    ##       ##     ## ##       ####  ##    ##    ##
  //    ######   ##     ## ######   ## ## ##    ##     ######
  //    ##        ##   ##  ##       ##  ####    ##          ##
  //    ##         ## ##   ##       ##   ###    ##    ##    ##
  //    ########    ###    ######## ##    ##    ##     ######

  onWillSave (callback) {
    return this.emitter.on('did-save', callback)
  }

  onDidSave (callback) {
    return this.emitter.on('did-save', callback)
  }

  onDidChangeModified (callback) {
    return this.emitter.on('did-change-modified', callback)
  }

  onDidAddColumn (callback) {
    return this.emitter.on('did-add-column', callback)
  }

  onDidRemoveColumn (callback) {
    return this.emitter.on('did-remove-column', callback)
  }

  onDidRenameColumn (callback) {
    return this.emitter.on('did-rename-column', callback)
  }

  onDidSwapColumns (callback) {
    return this.emitter.on('did-swap-columns', callback)
  }

  onDidAddRow (callback) {
    return this.emitter.on('did-add-row', callback)
  }

  onDidRemoveRow (callback) {
    return this.emitter.on('did-remove-row', callback)
  }

  onDidChange (callback) {
    return this.emitter.on('did-change', callback)
  }

  onDidChangeCellValue (callback) {
    return this.emitter.on('did-change-cell-value', callback)
  }

  onDidDestroy (callback) {
    return this.emitter.on('did-destroy', callback)
  }

  //     ######   #######  ##       ##     ## ##     ## ##    ##  ######
  //    ##    ## ##     ## ##       ##     ## ###   ### ###   ## ##    ##
  //    ##       ##     ## ##       ##     ## #### #### ####  ## ##
  //    ##       ##     ## ##       ##     ## ## ### ## ## ## ##  ######
  //    ##       ##     ## ##       ##     ## ##     ## ##  ####       ##
  //    ##    ## ##     ## ##       ##     ## ##     ## ##   ### ##    ##
  //     ######   #######  ########  #######  ##     ## ##    ##  ######

  getColumns () { return this.columns.slice() }

  getColumn (index) { return this.columns[index] }

  getColumnIndex (column) { return this.columns.indexOf(column) }

  getColumnValues (index) { return this.rows.map(row => row[index]) }

  getColumnNames () { return this.columns.concat() }

  getColumnCount () { return this.columns.length }

  addColumn (name, transaction = true, event = true) {
    return this.addColumnAt(this.columns.length, name, transaction, event)
  }

  addColumnAt (index, column, transaction = true, event = true) {
    if (this.isDestroyed()) { throw new Error("Can't add column to a destroyed table") }
    if (index < 0) { throw new Error(`Can't add column ${column} at index ${index}`) }

    this.extendExistingRows(column, index)

    if (index >= this.columns.length) {
      index = this.columns.length
      this.columns.push(column)
    } else {
      this.columns.splice(index, 0, column)
    }

    this.emitModifiedStatusChange()
    if (event) { this.emitter.emit('did-add-column', {column, index}) }

    if (transaction) {
      this.transaction({
        undo () { this.removeColumnAt(index, false) },
        redo () { this.addColumnAt(index, column, false) }
      })
    }

    return column
  }

  removeColumn (column, transaction = true, event = true) {
    if (column == null) { throw new Error("Can't remove an undefined column") }

    return this.removeColumnAt(this.columns.indexOf(column), transaction, event)
  }

  removeColumnAt (index, transaction = true, event = true) {
    if (index === -1 || index >= this.columns.length) {
      throw new Error(`Can't remove column at index ${index}`)
    }

    if (transaction) { var values = this.getColumnValues(index) }

    let column = this.columns[index]
    this.columns.splice(index, 1)
    for (let row of this.rows) { row.splice(index, 1) }

    this.emitModifiedStatusChange()
    if (event) { this.emitter.emit('did-remove-column', {column, index}) }

    if (transaction) {
      this.transaction({
        undo () {
          this.addColumnAt(index, column, false)
          this.rows.forEach((row, i) => { row[index] = values[i] })
        },
        redo () { this.removeColumnAt(index, false) }
      })
    }

    return column
  }

  columnRangeFrom (range) {
    if (range == null) { throw new Error('Null range') }

    if (Array.isArray(range)) { range = {start: range[0], end: range[1]} }

    if ((range.start == null) || (range.end == null)) {
      throw new Error(`Invalid range ${range}`)
    }

    if (range.start < 0) { range.start = 0 }
    if (range.end > this.getColumnCount()) { range.end = this.getColumnCount() }

    return range
  }

  changeColumnName (column, newName, transaction = true, event = true) {
    const index = this.columns.indexOf(column)
    this.changeColumnNameAt(index, newName, transaction, event)
  }

  changeColumnNameAt (index, newName, transaction = true, event = true) {
    const oldName = this.columns[index]
    this.columns[index] = newName
    this.emitModifiedStatusChange()

    if (event) {
      this.emitter.emit('did-rename-column', {oldName, newName, index})
    }

    if (transaction) {
      this.transaction({
        undo () {
          this.columns[index] = oldName
          this.emitModifiedStatusChange()
        },
        redo () {
          this.columns[index] = newName
          this.emitModifiedStatusChange()
        }
      })
    }
  }

  swapColumns (columnA, columnB, transaction = true) {
    const nameA = this.columns[columnA]
    const nameB = this.columns[columnB]

    const columnAData = this.getColumnValues(columnA)
    const columnBData = this.getColumnValues(columnB)

    this.columns[columnA] = nameB
    this.columns[columnB] = nameA

    this.rows.forEach((row, i) => {
      row.splice(columnA, 1, columnBData[i])
      row.splice(columnB, 1, columnAData[i])
    })

    if (transaction) {
      this.transaction({
        undo () { this.swapColumns(columnA, columnB, false) },
        redo () { this.swapColumns(columnA, columnB, false) }
      })
    }

    this.emitModifiedStatusChange()
    this.emitter.emit('did-swap-columns', {columnA, columnB})
    this.emitter.emit('did-change', {
      oldRange: {start: 0, end: this.getRowCount()},
      newRange: {start: 0, end: this.getRowCount()}
    })
  }

  //    ########   #######  ##      ##  ######
  //    ##     ## ##     ## ##  ##  ## ##    ##
  //    ##     ## ##     ## ##  ##  ## ##
  //    ########  ##     ## ##  ##  ##  ######
  //    ##   ##   ##     ## ##  ##  ##       ##
  //    ##    ##  ##     ## ##  ##  ## ##    ##
  //    ##     ##  #######   ###  ###   ######

  getRows () { return this.rows.slice() }

  getRow (index) { return this.rows[index] }

  getRowIndex (row) { return this.rows.indexOf(row) }

  getRowCount () { return this.rows.length }

  getRowsInRange (range) {
    range = this.rowRangeFrom(range)
    return this.rows.slice(range.start, range.end)
  }

  getFirstRow () { return this.rows[0] }

  getLastRow () { return this.rows[this.rows.length - 1] }

  addRow (values, batch = false, transaction = true) {
    return this.addRowAt(this.rows.length, values, batch, transaction)
  }

  addRowAt (index, values = {}, batch = false, transaction = true) {
    if (this.isDestroyed()) { throw new Error("Can't add row to a destroyed table") }
    if (index < 0) { throw new Error(`Can't add row ${values} at index ${index}`) }

    if (this.columns.length === 0) {
      throw new Error("Can't add rows to a table without column")
    }

    const row = Array.isArray(values)
      ? values.concat()
      : this.columns.map(column => values[column])

    index >= this.rows.length
      ? this.rows.push(row)
      : this.rows.splice(index, 0, row)

    this.emitter.emit('did-add-row', {row, index})

    if (!batch) {
      this.emitModifiedStatusChange()
      this.emitter.emit('did-change', {
        oldRange: {start: index, end: index},
        newRange: {start: index, end: index + 1}
      })

      if (transaction) {
        this.transaction({
          undo () { this.removeRowAt(index, false, false) },
          redo () { this.addRowAt(index, values, false, false) }
        })
      }
    }

    return row
  }

  addRows (rows, transaction = true) {
    return this.addRowsAt(this.rows.length, rows, transaction)
  }

  addRowsAt (index, rows, transaction = true) {
    if (this.isDestroyed()) {
      throw new Error("Can't add rows to a destroyed table")
    }

    const createdRows = rows.map((row, i) => this.addRowAt(index + i, row, true))

    this.emitModifiedStatusChange()
    this.emitter.emit('did-change', {
      oldRange: {start: index, end: index},
      newRange: {start: index, end: index + rows.length}
    })

    if (transaction) {
      const range = {start: index, end: index + rows.length}
      this.transaction({
        undo () { this.removeRowsInRange(range, false) },
        redo () { this.addRowsAt(index, rows, false) }
      })
    }

    return createdRows
  }

  removeRow (row, batch = false, transaction = true) {
    if (row == null) { throw new Error("Can't remove an undefined row") }

    return this.removeRowAt(this.rows.indexOf(row), batch, transaction)
  }

  removeRowAt (index, batch = false, transaction = true) {
    if (index === -1 || index >= this.rows.length) {
      throw new Error(`Can't remove row at index ${index}`)
    }

    const row = this.rows[index]
    this.rows.splice(index, 1)

    this.emitter.emit('did-remove-row', {row, index})
    if (!batch) {
      this.emitModifiedStatusChange()
      this.emitter.emit('did-change', {
        oldRange: {start: index, end: index + 1},
        newRange: {start: index, end: index}
      })

      if (transaction) {
        let values = row.slice()
        this.transaction({
          undo () { this.addRowAt(index, values, false, false) },
          redo () { this.removeRowAt(index, false, false) }
        })
      }
    }

    return row
  }

  removeRowsInRange (range, transaction = true) {
    range = this.rowRangeFrom(range)

    const removedRows = this.rows.splice(range.start, range.end - range.start)
    if (transaction) { var rowsValues = removedRows.map(row => row.slice()) }

    removedRows.forEach(row => {
      this.emitter.emit('did-remove-row', {row, index: range.start})
    })

    this.emitModifiedStatusChange()
    this.emitter.emit('did-change', {
      oldRange: range,
      newRange: {start: range.start, end: range.start}
    })

    if (transaction) {
      this.transaction({
        undo () { this.addRowsAt(range.start, rowsValues, false) },
        redo () { this.removeRowsInRange(range, false) }
      })
    }

    return removedRows
  }

  removeRowsAtIndices (indices, transaction = true) {
    indices = indices.slice().sort()
    const removedRows = indices.map((index) => this.rows[index])
    const rowsValues = transaction
      ? removedRows.map(row => row.slice())
      : []

    removedRows.forEach(row => row && this.removeRow(row, true, false))

    if (transaction) {
      this.transaction({
        undo () {
          indices.forEach((index, i) => {
            this.addRowAt(index, rowsValues[i], true, false)
          })
          this.emitter.emit('did-change', {rowIndices: indices.slice()})
        },
        redo () {
          this.removeRowsAtIndices(indices, false)
        }
      })
    }

    this.emitter.emit('did-change', {rowIndices: indices.slice()})

    return removedRows
  }

  swapRows (rowA, rowB, transaction = true) {
    const rowAData = this.rows[rowA]
    const rowBData = this.rows[rowB]

    this.rows[rowA] = rowBData
    this.rows[rowB] = rowAData

    if (transaction) {
      this.transaction({
        undo () { this.swapRows(rowA, rowB, false) },
        redo () { this.swapRows(rowA, rowB, false) }
      })
    }

    this.emitModifiedStatusChange()
    this.emitter.emit('did-change', {rowIndices: [rowA, rowB]})
  }

  sortRows (sortFunction, transaction = true) {
    const originalRows = this.rows.slice()
    const sortedRows = this.rows.slice().sort(sortFunction)

    this.rows = sortedRows.slice()

    const emitEvents = () => {
      this.emitModifiedStatusChange()
      this.emitter.emit('did-change', {
        oldRange: {start: 0, end: originalRows.length},
        newRange: {start: 0, end: originalRows.length}
      })
    }

    if (transaction) {
      this.transaction({
        undo () {
          this.rows = originalRows
          emitEvents()
        },
        redo () {
          this.rows = sortedRows
          emitEvents()
        }
      })
    }

    emitEvents()
  }

  extendExistingRows (column, index) {
    return this.rows.map((row) => row.splice(index, 0, undefined))
  }

  rowRangeFrom (range) {
    if (range == null) { throw new Error('Null range') }

    if (Array.isArray(range)) { range = {start: range[0], end: range[1]} }

    if ((range.start == null) || (range.end == null)) {
      throw new Error(`Invalid range ${range}`)
    }

    if (range.start < 0) { range.start = 0 }
    if (range.end > this.getRowCount()) { range.end = this.getRowCount() }

    return range
  }

  //     ######  ######## ##       ##        ######
  //    ##    ## ##       ##       ##       ##    ##
  //    ##       ##       ##       ##       ##
  //    ##       ######   ##       ##        ######
  //    ##       ##       ##       ##             ##
  //    ##    ## ##       ##       ##       ##    ##
  //     ######  ######## ######## ########  ######

  getCells () { return this.rows.reduce((cells, row) => cells.concat(row), []) }

  getCellCount () { return this.rows.length * this.columns.length }

  getValueAtPosition (position) {
    if (!position) {
      throw new Error('Table::getValueAtPosition called without a position')
    }

    position = Point.fromObject(position)
    return getAtPosition(this.rows, position)
  }

  setValueAtPosition (position, value, batch = false, transaction = true) {
    if (!position) {
      throw new Error('Table::setValueAtPosition called without a position')
    }
    if (position.row < 0 || position.row >= this.getRowCount() || position.column < 0 || position.column >= this.getColumnCount()) {
      throw new Error(`Table::setValueAtPosition called without an invalid position ${position}`)
    }

    position = Point.fromObject(position)
    const oldValue = getAtPosition(this.rows, position)
    setAtPosition(this.rows, position, value)

    if (!batch) {
      this.emitModifiedStatusChange()
      this.emitter.emit('did-change-cell-value', {
        position,
        oldValue,
        newValue: value
      })

      if (transaction) {
        this.transaction({
          undo () { this.setValueAtPosition(position, oldValue, batch, false) },
          redo () { this.setValueAtPosition(position, value, batch, false) }
        })
      }
    }
  }

  setValuesAtPositions (positions, values, transaction = true) {
    const oldValues = positions.map((position, i) => {
      position = Point.fromObject(position)
      const oldValue = getAtPosition(this.rows, position)
      setAtPosition(this.rows, position, values[i % values.length])
      return oldValue
    })

    this.emitModifiedStatusChange()
    this.emitter.emit('did-change-cell-value', {
      positions,
      oldValues,
      newValues: values
    })

    if (transaction) {
      positions = positions.slice()
      values = values.slice()
      this.transaction({
        undo () { this.setValuesAtPositions(positions, oldValues, false) },
        redo () { this.setValuesAtPositions(positions, values, false) }
      })
    }
  }

  setValuesInRange (range, values, transaction = true) {
    range = Range.fromObject(range)

    const valuesRows = values.length
    const valuesColumns = values[0].length

    const oldValues = range.map((row, column) => {
      const valuesRow = (row - range.start.row) % valuesRows
      const valuesColumn = (column - range.start.column) % valuesColumns

      const oldValue = getAtPosition(this.rows, {row, column})
      setAtPosition(this.rows, {row, column}, values[valuesRow][valuesColumn])
      return oldValue
    })

    this.emitModifiedStatusChange()
    this.emitter.emit('did-change-cell-value', {
      range,
      oldValues,
      newValues: values
    })

    if (transaction) {
      values = values.map(a => a.slice())
      this.transaction({
        undo () { this.setValuesInRange(range, oldValues, false) },
        redo () { this.setValuesInRange(range, values, false) }
      })
    }
  }
}

module.exports = Table.initClass()
