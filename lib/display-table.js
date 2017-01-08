'use strict'

const _ = require('underscore-plus')
const { Point, Range, Emitter, CompositeDisposable } = require('atom')
const Delegator = require('delegato')
const Table = require('./table')
const DisplayColumn = require('./display-column')
const rangeArray = (l, r) =>
  !isNaN(l) && !isNaN(r)
    ? new Array(Math.max(0, r - l)).fill().map((x, i) => l + i)
    : []

class DisplayTable {
  static initClass () {
    Delegator.includeInto(this)

    this.delegatesMethods(
      'changeColumnName', 'undo', 'redo', 'getRows', 'getColumns', 'getColumnCount', 'getColumnIndex', 'getRowCount', 'clearUndoStack', 'clearRedoStack', 'getValueAtPosition', 'swapColumns', 'columnRangeFrom', 'setValueAtPosition', 'setValuesAtPositions', 'setValuesInRange', 'rowRangeFrom', 'swapRows', 'getRow',
      {toProperty: 'table'}
    )

    this.prototype.rowOffsets = null
    this.prototype.columnOffsets = null

    return this
  }

  static deserialize (state) {
    if (state.table) {
      state.table = atom.deserializers.deserialize(state.table)
    }
    return new DisplayTable(state)
  }

  constructor (options) {
    options = options || {}

    ;({
      table: this.table,
      rowHeights: this.rowHeights,
      order: this.order,
      direction: this.direction
    } = options)

    if (!this.table) { this.table = new Table() }
    this.emitter = new Emitter()
    this.subscriptions = new CompositeDisposable()
    this.screenColumnsSubscriptions = new WeakMap()

    this.subscribeToConfig()
    this.subscribeToTable()

    this.screenColumns = this.table.getColumns().map(column => {
      let screenColumn = new DisplayColumn({name: column})
      this.subscribeToScreenColumn(screenColumn)
      return screenColumn
    })

    if (!this.rowHeights) {
      this.rowHeights = new Array(this.table.getRowCount())
    }
    this.computeScreenColumnOffsets()
    this.updateScreenRows()
  }

  destroy () {
    this.screenColumns.forEach(column => {
      this.unsubscribeFromScreenColumn(column)
    })
    this.rowOffsets = []
    this.rowHeights = []
    this.columnOffsets = []
    this.screenColumns = []
    this.screenRows = []
    this.screenToModelRowsMap = {}
    this.modelToScreenRowsMap = {}
    this.destroyed = true
    this.emitter.emit('did-destroy', this)
    this.emitter.dispose()
    this.emitter = null
    this.subscriptions.dispose()
    this.subscriptions = null
    this.table = null
  }

  onDidDestroy (callback) {
    return this.emitter.on('did-destroy', callback)
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

  onDidChangeColumnOption (callback) {
    return this.emitter.on('did-change-column-options', callback)
  }

  onDidChangeCellValue (callback) {
    return this.emitter.on('did-change-cell-value', callback)
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

  onDidChangeLayout (callback) {
    return this.emitter.on('did-change-layout', callback)
  }

  onDidChangeRowHeight (callback) {
    return this.emitter.on('did-change-row-height', callback)
  }

  subscribeToTable () {
    this.subscriptions.add(this.table.onDidAddColumn(({column, index}) => {
      this.addScreenColumn(index, {name: column})
    }))

    this.subscriptions.add(this.table.onDidRemoveColumn(({column, index}) => {
      this.removeScreenColumn(index, column)
    }))

    this.subscriptions.add(this.table.onDidRenameColumn(({newName, oldName, index}) => {
      this.screenColumns[index].setOption('name', newName)
      this.emitter.emit('did-rename-column', {
        screenColumn: this.screenColumns[index], oldName, newName, index
      })
    }))

    this.subscriptions.add(this.table.onDidSwapColumns(({columnA, columnB}) => {
      const screenColumnA = this.screenColumns[columnA]
      const screenColumnB = this.screenColumns[columnB]

      this.screenColumns[columnA] = screenColumnB
      this.screenColumns[columnB] = screenColumnA

      this.emitter.emit('did-rename-column', {
        columnA, screenColumnA, columnB, screenColumnB
      })
    }))

    this.subscriptions.add(this.table.onDidAddRow(({index}) => {
      this.rowHeights.splice(index, 0, undefined)
    }))

    this.subscriptions.add(this.table.onDidRemoveRow(({index}) => {
      this.rowHeights.splice(index, 1)
    }))

    this.subscriptions.add(this.table.onDidChange(event => {
      this.updateScreenRows()
      this.emitter.emit('did-change', event)
    }))

    this.subscriptions.add(this.table.onDidChangeCellValue(event => {
      let newEvent
      if (event.positions != null) {
        const {positions, oldValues, newValues} = event
        newEvent = {
          positions,
          oldValues,
          newValues,
          screenPositions: positions.map(p => this.screenPosition(p))
        }
      } else if (event.position != null) {
        const {position, oldValue, newValue} = event
        newEvent = {
          position,
          oldValue,
          newValue,
          screenPosition: this.screenPosition(position)
        }
      } else if (event.range != null) {
        const {range, oldValues, newValues} = event
        if (this.order != null) {
          let screenPositions = []
          range.each((row, column) => {
            screenPositions.push(this.screenPosition([row, column]))
          })
          newEvent = { range, oldValues, newValues, screenPositions }
        } else {
          newEvent = {
            range,
            oldValues,
            newValues,
            screenRange: range.copy()
          }
        }
      } else {
        newEvent = event
      }

      this.emitter.emit('did-change-cell-value', newEvent)
    }))

    this.subscriptions.add(this.table.onDidDestroy(event => this.destroy()))
  }

  subscribeToConfig () {
    this.observeConfig({
      'tablr.tableEditor.undefinedDisplay': configUndefinedDisplay => {
        this.configUndefinedDisplay = configUndefinedDisplay
      },
      'tablr.tableEditor.rowHeight': configRowHeight => {
        this.configRowHeight = configRowHeight
        if ((this.rowHeights != null) && (this.screenRows != null)) {
          this.computeRowOffsets()
        }
      },
      'tablr.tableEditor.minimumRowHeight': configMinimumRowHeight => {
        this.configMinimumRowHeight = configMinimumRowHeight
        if ((this.rowHeights != null) && (this.screenRows != null)) {
          this.computeRowOffsets()
        }
      },
      'tablr.tableEditor.columnWidth': configScreenColumnWidth => {
        this.configScreenColumnWidth = configScreenColumnWidth
        if (this.screenColumns != null) { this.computeScreenColumnOffsets() }
      },
      'tablr.tableEditor.minimumColumnWidth': configMinimumScreenColumnWidth => {
        this.configMinimumScreenColumnWidth = configMinimumScreenColumnWidth
        if (this.screenColumns != null) { this.computeScreenColumnOffsets() }
      }
    })
  }

  observeConfig (configs) {
    for (let config in configs) {
      this.subscriptions.add(atom.config.observe(config, configs[config]))
    }
  }

  isDestroyed () { return this.destroyed }

  serialize () {
    let out = {
      deserializer: 'DisplayTable',
      rowHeights: this.rowHeights,
      table: this.table.serialize()
    }

    if (this.order != null) {
      out = _.extend(out, {order: this.order, direction: this.direction})
    }

    return out
  }

  //     ######   #######  ##       ##     ## ##     ## ##    ##  ######
  //    ##    ## ##     ## ##       ##     ## ###   ### ###   ## ##    ##
  //    ##       ##     ## ##       ##     ## #### #### ####  ## ##
  //    ##       ##     ## ##       ##     ## ## ### ## ## ## ##  ######
  //    ##       ##     ## ##       ##     ## ##     ## ##  ####       ##
  //    ##    ## ##     ## ##       ##     ## ##     ## ##   ### ##    ##
  //     ######   #######  ########  #######  ##     ## ##    ##  ######

  getScreenColumns () { return this.screenColumns.slice() }

  getScreenColumnCount () { return this.screenColumns.length }

  getScreenColumn (index) { return this.screenColumns[index] }

  getScreenColumnIndex (column) { return this.screenColumns.indexOf(column) }

  getLastColumnIndex () { return this.screenColumns.length - 1 }

  getContentWidth () {
    const lastIndex = this.getLastColumnIndex()
    return lastIndex < 0
      ? 0
      : this.getScreenColumnOffsetAt(lastIndex) +
        this.getScreenColumnWidthAt(lastIndex)
  }

  getScreenColumnWidth () {
    return this.screenColumnWidth != null
      ? this.screenColumnWidth
      : this.configScreenColumnWidth
  }

  getMinimumScreenColumnWidth () {
    return this.minimumScreenColumnWidth != null
      ? this.minimumScreenColumnWidth
      : this.configMinimumScreenColumnWidth
  }

  setScreenColumnOptions (index, options) {
    const column = this.getScreenColumn(index)
    column && column.setOptions(options)
  }

  setScreenColumnWidth (minimumScreenColumnWidth) {
    this.minimumScreenColumnWidth = minimumScreenColumnWidth
    this.computeScreenColumnOffsets()
  }

  getScreenColumnWidthAt (index) {
    const screenColumn = this.screenColumns[index]
    return screenColumn && screenColumn.width != null
      ? screenColumn.width
      : this.getScreenColumnWidth()
  }

  setScreenColumnWidthAt (index, width) {
    const minWidth = this.getMinimumScreenColumnWidth()
    if (width < minWidth) { width = minWidth }

    const screenColumn = this.screenColumns[index]
    if (screenColumn) { screenColumn.width = width }
    this.emitter.emit('did-change-layout', this)
  }

  getScreenColumnAlignAt (index) {
    return this.screenColumns[index] && this.screenColumns[index].align
  }

  setScreenColumnAlignAt (index, align) {
    const screenColumn = this.screenColumns[index]
    if (screenColumn) { screenColumn.align = align }
    this.emitter.emit('did-change-layout', this)
  }

  getScreenColumnOffsetAt (column) { return this.screenColumnOffsets[column] }

  getScreenColumnIndexAtPixelPosition (position) {
    let found
    rangeArray(0, this.getScreenColumnCount()).some((i) => {
      const offset = this.getScreenColumnOffsetAt(i)
      if (position < offset) {
        found = i - 1
        return true
      }
    })

    return found != null ? found : this.getLastColumnIndex()
  }

  addColumn (name, options = {}, transaction = true) {
    this.addColumnAt(this.screenColumns.length, name, options, transaction)
  }

  addColumnAt (index, column, options = {}, transaction = true) {
    this.table.addColumnAt(index, column, transaction)
    this.setScreenColumnOptions(index, options)

    if (transaction) {
      const columnOptions = _.clone(options)

      this.table.ammendLastTransaction({
        undo: commit => commit.undo(),
        redo: commit => {
          commit.redo()
          this.getScreenColumn(index).setOptions(columnOptions)
        }
      })
    }
  }

  addScreenColumn (index, options) {
    const screenColumn = new DisplayColumn(options)
    this.subscribeToScreenColumn(screenColumn)
    this.screenColumns.splice(index, 0, screenColumn)
    this.computeScreenColumnOffsets()
    this.emitter.emit('did-add-column', {
      screenColumn, column: options.name, index
    })
  }

  removeColumn (column, transaction = true) {
    this.removeColumnAt(this.table.getColumnIndex(column), transaction)
  }

  removeColumnAt (index, transaction = true) {
    const screenColumn = this.screenColumns[index]
    this.table.removeColumnAt(index, transaction)

    if (transaction) {
      const columnOptions = _.clone(screenColumn.options)

      this.table.ammendLastTransaction({
        undo: commit => {
          commit.undo()
          this.getScreenColumn(index).setOptions(columnOptions)
        },
        redo: commit => commit.redo()
      })
    }
  }

  removeScreenColumn (index, column) {
    const screenColumn = this.screenColumns[index]
    this.unsubscribeFromScreenColumn(screenColumn)
    this.screenColumns.splice(index, 1)
    this.computeScreenColumnOffsets()
    this.emitter.emit('did-remove-column', {screenColumn, column, index})
  }

  removeScreenColumnsInRange (range, transaction = true) {
    range = this.columnRangeFrom(range)

    rangeArray(range.start, range.end).reverse().forEach(index => {
      this.removeColumnAt(index)
    })
  }

  computeScreenColumnOffsets () {
    this.screenColumnOffsets = rangeArray(0, this.screenColumns.length - 1).reduce((memo, i) => {
      return memo.concat(memo[i] + this.getScreenColumnWidthAt(i))
    }, [0])
  }

  subscribeToScreenColumn (screenColumn) {
    const subs = new CompositeDisposable()
    this.screenColumnsSubscriptions.set(screenColumn, subs)

    subs.add(screenColumn.onDidChangeName(({newName}) => {
      const columnIndex = this.getScreenColumnIndex(screenColumn)
      this.table.changeColumnNameAt(columnIndex, newName)
    }))

    subs.add(screenColumn.onDidChangeOption(event => {
      const newEvent = _.clone(event)
      newEvent.index = this.screenColumns.indexOf(event.column)
      this.emitter.emit('did-change-column-options', newEvent)

      if (event.option === 'width') { return this.computeScreenColumnOffsets() }
    }))
  }

  unsubscribeFromScreenColumn (screenColumn) {
    const subs = this.screenColumnsSubscriptions.get(screenColumn)
    this.screenColumnsSubscriptions.delete(screenColumn)
    subs && subs.dispose()
  }

  //    ########   #######  ##      ##  ######
  //    ##     ## ##     ## ##  ##  ## ##    ##
  //    ##     ## ##     ## ##  ##  ## ##
  //    ########  ##     ## ##  ##  ##  ######
  //    ##   ##   ##     ## ##  ##  ##       ##
  //    ##    ##  ##     ## ##  ##  ## ##    ##
  //    ##     ##  #######   ###  ###   ######

  screenRowToModelRow (row) { return this.screenToModelRowsMap[row] }

  modelRowToScreenRow (row) { return this.modelToScreenRowsMap[row] }

  getScreenRows () { return this.screenRows.slice() }

  getScreenRowCount () { return this.screenRows.length }

  getScreenRow (row) {
    return this.table.getRow(this.screenRowToModelRow(row))
  }

  getLastRowIndex () { return this.screenRows.length - 1 }

  getScreenRowHeightAt (row) {
    return this.getRowHeightAt(this.screenRowToModelRow(row))
  }

  setScreenRowHeightAt (row, height) {
    this.setRowHeightAt(this.screenRowToModelRow(row), height)
  }

  getScreenRowOffsetAt (row) { return this.rowOffsets[row] }

  getContentHeight () {
    const lastIndex = this.getLastRowIndex()
    return lastIndex < 0
      ? 0
      : this.getScreenRowOffsetAt(lastIndex) +
        this.getScreenRowHeightAt(lastIndex)
  }

  getRowHeight () {
    return this.rowHeight != null
      ? this.rowHeight
      : this.configRowHeight
  }

  getMinimumRowHeight () {
    return this.minimumRowHeight != null
      ? this.minimumRowHeight
      : this.configMinimumRowHeight
  }

  setRowHeight (rowHeight) {
    this.rowHeight = rowHeight
    this.computeRowOffsets()
  }

  setRowHeights (rowHeights = []) {
    this.rowHeights = rowHeights
    this.computeRowOffsets()
    this.emitter.emit('did-change-layout', this)
  }

  getRowHeightAt (index) {
    return this.rowHeights[index] != null
      ? this.rowHeights[index]
      : this.getRowHeight()
  }

  setRowHeightAt (index, height) {
    const minHeight = this.getMinimumRowHeight()
    if (height < minHeight) { height = minHeight }
    this.rowHeights[index] = height
    this.computeRowOffsets()
    this.emitter.emit('did-change-row-height', {height, row: index})
    this.emitter.emit('did-change-layout', this)
  }

  getRowOffsetAt (index) {
    return this.getScreenRowOffsetAt(this.modelRowToScreenRow(index))
  }

  getScreenRowIndexAtPixelPosition (position) {
    let found
    rangeArray(0, this.getScreenRowCount()).some((i) => {
      const offset = this.getScreenRowOffsetAt(i)
      if (position < offset) {
        found = i - 1
        return true
      }
    })

    return found != null ? found : this.getLastRowIndex()
  }

  getRowIndexAtPixelPosition (position) {
    return this.screenRowToModelRow(this.getScreenRowIndexAtPixelPosition(position))
  }

  addRow (row, options = {}, transaction = true) {
    this.addRowAt(this.table.getRowCount(), row, options, transaction)
  }

  addRowAt (index, row, options = {}, transaction = true) {
    this.table.addRowAt(index, row, false, transaction)
    if (options.height != null) { this.setRowHeightAt(index, options.height) }

    if (transaction) {
      const rowOptions = _.clone(options)
      this.table.ammendLastTransaction({
        undo: commit => commit.undo(),
        redo: commit => {
          commit.redo()
          if (rowOptions.height != null) {
            this.setRowHeightAt(index, rowOptions.height)
          }
        }
      })
    }

    const modelIndex = this.screenRowToModelRow(index)
    this.emitter.emit('did-add-row', {
      row, screenIndex: index, index: modelIndex
    })
  }

  addRows (rows, options = {}, transaction = true) {
    this.addRowsAt(this.table.getRowCount(), rows, options, transaction)
  }

  addRowsAt (index, rows, options = {}, transaction = true) {
    const modelIndex = this.screenRowToModelRow(index)
    rows = rows.slice()

    this.table.addRowsAt(index, rows, transaction)
    rows.forEach((row, i) => {
      if (options[i] && options[i].height != null) {
        this.setRowHeightAt(index + i, options[i].height)
      }
      this.emitter.emit('did-add-row', {
        row, screenIndex: index, index: modelIndex
      })
    })

    if (transaction) {
      const rowOptions = _.clone(options)
      this.table.ammendLastTransaction({
        undo: commit => commit.undo(),
        redo: commit => {
          commit.redo()
          rows.forEach((row, i) => {
            if (rowOptions[i] && rowOptions[i].height != null) {
              this.setRowHeightAt(index + i, rowOptions[i].height)
            }
          })
        }
      })
    }
  }

  removeRow (row, transaction = true) {
    this.removeRowAt(this.table.getRowIndex(row), transaction)
  }

  removeRowAt (index, transaction = true) {
    const rowHeight = this.rowHeights[index]
    this.table.removeRowAt(index, false, transaction)

    if (transaction) {
      this.table.ammendLastTransaction({
        undo: commit => {
          commit.undo()
          this.setRowHeightAt(index, rowHeight)
        },
        redo: commit => commit.redo()
      })
    }
  }

  removeScreenRowAt (row, transaction = true) {
    this.removeRowAt(this.screenRowToModelRow(row), transaction)
  }

  removeRowsInRange (range, transaction = true) {
    range = this.rowRangeFrom(range)

    const rowHeights = rangeArray(range.start, range.end).map(i =>
      this.rowHeights[i])

    this.table.removeRowsInRange(range, transaction)

    if (transaction) {
      this.table.ammendLastTransaction({
        undo: commit => {
          commit.undo()
          rangeArray(range.start, range.end, false).map(i =>
            this.setRowHeightAt(i, rowHeights[i]))
        },
        redo: commit => commit.redo()
      })
    }
  }

  removeRowsInScreenRange (range, transaction = true) {
    let end, i, index, rowHeights, rowIndices
    range = this.table.rowRangeFrom(range)

    if (this.order != null) {
      rowIndices = ((() => {
        let result = []
        for (i = range.start, { end } = range, asc = range.start <= end; asc ? i < end : i > end; asc ? i++ : i--) {
          var asc
          result.push(this.screenRowToModelRow(i))
        }
        return result
      })())
      rowHeights = ((() => {
        let result1 = []
        for (index of Array.from(rowIndices)) {
          result1.push(this.rowHeights[index])
        }
        return result1
      })())

      this.table.removeRowsAtIndices(rowIndices, transaction)
    } else {
      rowIndices = rangeArray(range.start, range.end)
      rowHeights = ((() => {
        let result2 = []
        for (index of Array.from(rowIndices)) {
          result2.push(this.rowHeights[index])
        }
        return result2
      })())

      this.table.removeRowsInRange(range, transaction)
    }

    if (transaction) {
      return this.table.ammendLastTransaction({
        undo: commit => {
          commit.undo()
          return (() => {
            let result3 = []
            for (i = 0; i < rowIndices.length; i++) {
              index = rowIndices[i]
              result3.push(this.setRowHeightAt(index, rowHeights[i]))
            }
            return result3
          })()
        },
        redo: commit => {
          return commit.redo()
        }
      })
    }
  }

  computeRowOffsets () {
    this.rowOffsets = rangeArray(0, this.table.getRowCount() - 1).reduce((m, i) => {
      return m.concat(m[i] + this.getScreenRowHeightAt(i))
    }, [0])
  }

  updateScreenRows () {
    let i, row
    let rows = this.table.getRows()
    this.screenRows = rows.concat()

    this.screenToModelRowsMap = []
    this.modelToScreenRowsMap = []

    if (this.order != null) {
      if (typeof this.order === 'function') {
        this.screenRows.sort(this.order)
        for (i = 0; i < rows.length; i++) {
          var index
          row = rows[i]
          this.modelToScreenRowsMap[i] = index = this.screenRows.indexOf(row)
          this.screenToModelRowsMap[index] = i
        }
      } else {
        let orderArray = this.screenRows.map((row, i) => {
          return {
            originalIndex: i,
            value: row[this.order]
          }
        })

        orderArray.sort(this.compareScreenRows(this.direction))

        for (i = 0; i < orderArray.length; i++) {
          let {originalIndex} = orderArray[i]
          this.screenRows[i] = rows[originalIndex]
          this.modelToScreenRowsMap[originalIndex] = i
          this.screenToModelRowsMap[i] = originalIndex
        }
      }
    } else {
      for (i = 0; i < rows.length; i++) {
        row = rows[i]
        this.modelToScreenRowsMap[i] = this.screenToModelRowsMap[i] = i
      }
    }

    return this.computeRowOffsets()
  }

  compareScreenRows (direction = 1) {
    const collator = this.getCollator()
    return (a, b) => collator.compare(a.value, b.value) * direction
  }

  compareModelRows (order, direction = 1) {
    const collator = this.getCollator()
    return (a, b) => collator.compare(a[order], b[order]) * direction
  }

  getCollator () {
    return this.collator
      ? this.collator
      : (this.collator = new Intl.Collator('en-US', {numeric: true}))
  }

  //     ######  ######## ##       ##        ######
  //    ##    ## ##       ##       ##       ##    ##
  //    ##       ##       ##       ##       ##
  //    ##       ######   ##       ##        ######
  //    ##       ##       ##       ##             ##
  //    ##    ## ##       ##       ##       ##    ##
  //     ######  ######## ######## ########  ######

  getValueAtScreenPosition (position) {
    return this.getValueAtPosition(this.modelPosition(position))
  }

  setValueAtScreenPosition (position, value, transaction = true) {
    this.setValueAtPosition(this.modelPosition(position), value, false, transaction)
  }

  setValuesAtScreenPositions (positions, values, transaction = true) {
    positions = positions.map(position => this.modelPosition(position))
    this.setValuesAtPositions(positions, values, transaction)
  }

  setValuesInScreenRange (range, values, transaction = true) {
    range = Range.fromObject(range)

    if (this.order != null) {
      const valuesRows = values.length
      const valuesColumns = values[0].length
      const positions = []
      const flattenValues = []

      for (let { row } = range.start, end = range.end.row, asc = range.start.row <= end; asc ? row < end : row > end; asc ? row++ : row--) {
        for (let { column } = range.start, end1 = range.end.column, asc1 = range.start.column <= end1; asc1 ? column < end1 : column > end1; asc1 ? column++ : column--) {
          let valuesRow = (row - range.start.row) % valuesRows
          let valuesColumn = (column - range.start.column) % valuesColumns
          let value = values[valuesRow][valuesColumn]

          flattenValues.push(value)
          positions.push(this.modelPosition([row, column]))
        }
      }

      this.setValuesAtPositions(positions, flattenValues, transaction)
    } else {
      this.setValuesInRange(range, values, transaction)
    }
  }

  getScreenPositionAtPixelPosition (x, y) {
    if (x == null || y == null) { return }

    const row = this.getScreenRowIndexAtPixelPosition(y)
    const column = this.getScreenColumnIndexAtPixelPosition(x)

    return new Point(row, column)
  }

  getPositionAtPixelPosition (x, y) {
    const position = this.getScreenPositionAtPixelPosition(x, y)
    position.row = this.screenRowToModelRow(position.row)
    return position
  }

  screenPosition (position) {
    const {row, column} = Point.fromObject(position)

    return new Point(this.modelRowToScreenRow(row), column)
  }

  modelPosition (position) {
    const {row, column} = Point.fromObject(position)

    return new Point(this.screenRowToModelRow(row), column)
  }

  getScreenCellPosition (position) {
    position = Point.fromObject(position)
    return {
      top: this.getScreenRowOffsetAt(position.row),
      left: this.getScreenColumnOffsetAt(position.column)
    }
  }

  getScreenCellRect (position) {
    const {top, left} = this.getScreenCellPosition(position)

    const width = this.getScreenColumnWidthAt(position.column)
    const height = this.getScreenRowHeightAt(position.row)

    return {top, left, width, height}
  }

  //     ######   #######  ########  ########
  //    ##    ## ##     ## ##     ##    ##
  //    ##       ##     ## ##     ##    ##
  //     ######  ##     ## ########     ##
  //          ## ##     ## ##   ##      ##
  //    ##    ## ##     ## ##    ##     ##
  //     ######   #######  ##     ##    ##

  sortBy (order, direction) {
    if (direction == null) { direction = 1 }
    this.direction = direction
    this.order = typeof order === 'string'
      ? this.table.getColumnIndex(order)
      : this.order = order

    this.updateScreenRows()
    this.emitter.emit('did-change', {
      oldScreenRange: {start: 0, end: this.getRowCount()},
      newScreenRange: {start: 0, end: this.getRowCount()}
    })
  }

  applySort () {
    if (this.order != null) {
      const { order } = this
      const orderFunction = typeof this.order === 'function'
        ? this.order
        : this.compareModelRows(this.order, this.direction)

      this.table.sortRows(orderFunction)
      this.table.ammendLastTransaction({
        undo: commit => {
          commit.undo()
          this.sortBy(order)
        },

        redo: commit => {
          commit.redo()
          this.resetSort()
        }
      })

      this.resetSort()
    }
  }

  toggleSortDirection () {
    this.direction *= -1
    this.updateScreenRows()
    this.emitter.emit('did-change', {
      oldScreenRange: {start: 0, end: this.getRowCount()},
      newScreenRange: {start: 0, end: this.getRowCount()}
    })
  }

  resetSort () {
    this.order = null
    this.updateScreenRows()
    this.emitter.emit('did-change', {
      oldScreenRange: {start: 0, end: this.getRowCount()},
      newScreenRange: {start: 0, end: this.getRowCount()}
    })
  }
}
module.exports = DisplayTable.initClass()
