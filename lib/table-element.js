'use strict'

const Delegator = require('delegato')
const {Point, CompositeDisposable, Disposable} = require('atom')
const {EventsDelegation, SpacePenDSL} = require('atom-utils')
const PropertyAccessors = require('property-accessors')
const element = require('./decorators/element')
const columnName = require('./column-name')
const TableEditor = require('./table-editor')
const TableCellElement = require('./table-cell-element')
const TableHeaderCellElement = require('./table-header-cell-element')
const TableGutterCellElement = require('./table-gutter-cell-element')
const GoToLineElement = require('./go-to-line-element')
const Range = require('./range')
const Pool = require('./mixins/pool')
const elementResizeDetector = require('element-resize-detector')({strategy: 'scroll'})

const PIXEL = 'px'

const range = (l, r) =>
  !isNaN(l) && !isNaN(r) ? new Array(r - l).fill().map((x, i) => l + i) : []

const stopPropagationAndDefault = f => function (e) {
  e.stopPropagation()
  e.preventDefault()
  return f && f.call(this, e)
}

const stopPropagation = f => function (e) {
  e.stopPropagation()
  return f && f.call(this, e)
}

const leftClick = f => function (e) {
  if (e.which === 1) { return f && f.call(this, e) }
}

const stopEventPropagation = function (commandListeners) {
  const newCommandListeners = {}
  Object.keys(commandListeners).forEach(commandName => {
    const commandListener = commandListeners[commandName]

    newCommandListeners[commandName] = function (event) {
      event.stopPropagation()
      return commandListener.call(this.getModel(), event)
    }
  })
  return newCommandListeners
}

const stopEventPropagationAndGroupUndo = function (commandListeners) {
  const newCommandListeners = {}
  Object.keys(commandListeners).forEach(commandName => {
    const commandListener = commandListeners[commandName]

    newCommandListeners[commandName] = function (event) {
      event.stopPropagation()
      const model = this.getModel()
      model.transact(atom.config.get('editor.undoGroupingInterval'), () =>
        commandListener.call(model, event)
      )
    }
  })
  return newCommandListeners
}

class TableElement extends HTMLElement {
  static initClass () {
    PropertyAccessors.includeInto(this)
    EventsDelegation.includeInto(this)
    SpacePenDSL.Babel.includeInto(this)
    Pool.includeInto(this)
    Delegator.includeInto(this)

    this.pool('cell', 'cells')
    this.pool('headerCell', 'headerCells')
    this.pool('gutterCell', 'gutterCells')

    if (!atom.inSpecMode()) { this.registerCommands() }

    return element(this, 'tablr-editor')
  }

  static content () {
    this.div({class: 'tablr-header', outlet: 'head'}, () => {
      this.div({class: 'tablr-header-content'}, () => {
        this.div({class: 'tablr-header-filler', outlet: 'tableHeaderFiller'})
        this.div({class: 'tablr-header-row', outlet: 'tableHeaderRow'}, () => {
          this.div({class: 'tablr-header-wrapper', outlet: 'tableHeaderCells'})
        })
        this.div({class: 'column-resize-ruler', outlet: 'columnRuler'})
      })
    })

    this.div({class: 'tablr-body', outlet: 'body'}, () => {
      this.div({class: 'tablr-content'}, () => {
        this.div({class: 'tablr-rows', outlet: 'tableRows'}, () => {
          this.div({class: 'tablr-rows-wrapper', outlet: 'tableCells'})
        })
        this.div({class: 'tablr-gutter'}, () => {
          this.div({class: 'tablr-gutter-wrapper', outlet: 'tableGutter'}, () => {
            this.div({class: 'tablr-gutter-filler', outlet: 'tableGutterFiller'})
          })
        })

        this.div({class: 'row-resize-ruler', outlet: 'rowRuler'})
      })
    })

    this.input({class: 'hidden-input', outlet: 'hiddenInput'})
    this.tag('content', {select: 'atom-text-editor'})
  }

  //     ######  ##     ## ########
  //    ##    ## ###   ### ##     ##
  //    ##       #### #### ##     ##
  //    ##       ## ### ## ##     ##
  //    ##       ##     ## ##     ##
  //    ##    ## ##     ## ##     ##
  //     ######  ##     ## ########

  static registerCommands () {
    atom.commands.add('tablr-editor', {
      'core:save': stopPropagationAndDefault(function () { this.save() }),
      'core:confirm' () { this.startCellEdit() },
      'core:cancel' () { this.resetSelections() },
      'core:copy' () { this.copySelectedCells() },
      'core:cut' () { this.cutSelectedCells() },
      'core:paste' () { this.pasteClipboard() },
      'core:undo' () { this.tableEditor.undo() },
      'core:redo' () { this.tableEditor.redo() },
      'core:backspace' () { this.delete() },
      'core:move-left' () { this.moveLeft() },
      'core:move-right' () { this.moveRight() },
      'core:move-up' () { this.moveUp() },
      'core:move-down' () { this.moveDown() },
      'core:move-to-top' () { this.moveToTop() },
      'core:move-to-bottom' () { this.moveToBottom() },
      'tablr:move-to-end-of-line' () { this.moveToRight() },
      'tablr:move-to-beginning-of-line' () { this.moveToLeft() },
      'core:page-up' () { this.pageUp() },
      'core:page-down' () { this.pageDown() },
      'tablr:page-left' () { this.pageLeft() },
      'tablr:page-right' () { this.pageRight() },
      'core:select-right' () { this.expandSelectionRight() },
      'core:select-left' () { this.expandSelectionLeft() },
      'core:select-up' () { this.expandSelectionUp() },
      'core:select-down' () { this.expandSelectionDown() },
      'tablr:move-left-in-selection' () { this.moveLeftInSelection() },
      'tablr:move-right-in-selection' () { this.moveRightInSelection() },
      'tablr:move-up-in-selection' () { this.moveUpInSelection() },
      'tablr:move-down-in-selection' () { this.moveDownInSelection() },
      'tablr:select-to-end-of-line' () { this.expandSelectionToEndOfLine() },
      'tablr:select-to-beginning-of-line' () { this.expandSelectionToBeginningOfLine() },
      'tablr:select-to-end-of-table' () { this.expandSelectionToEndOfTable() },
      'tablr:select-to-beginning-of-table' () { this.expandSelectionToBeginningOfTable() },
      'tablr:insert-row-before' () { this.insertRowBefore() },
      'tablr:insert-row-after' () { this.insertRowAfter() },
      'tablr:delete-row' () { this.deleteSelectedRows() },
      'tablr:insert-column-before' () { this.insertColumnBefore() },
      'tablr:insert-column-after' () { this.insertColumnAfter() },
      'tablr:delete-column' () { this.deleteSelectedColumns() },
      'tablr:align-left' () { this.alignLeft() },
      'tablr:align-center' () { this.alignCenter() },
      'tablr:align-right' () { this.alignRight() },
      'tablr:add-selection-below' () { this.addCursorBelowLastSelection() },
      'tablr:add-selection-above' () { this.addCursorAboveLastSelection() },
      'tablr:add-selection-left' () { this.addCursorLeftToLastSelection() },
      'tablr:add-selection-right' () { this.addCursorRightToLastSelection() },
      'tablr:expand-column' () { this.expandColumn() },
      'tablr:shrink-column' () { this.shrinkColumn() },
      'tablr:expand-row' () { this.expandRow() },
      'tablr:shrink-row' () { this.shrinkRow() },
      'tablr:go-to-line' () { this.openGoToLineModal() },
      'tablr:move-line-down' () { this.moveLineDown() },
      'tablr:move-line-up' () { this.moveLineUp() },
      'tablr:move-column-left' () { this.moveColumnLeft() },
      'tablr:move-column-right' () { this.moveColumnRight() },
      'tablr:apply-sort' () { this.applySort() },
      'tablr:fit-column-to-content' () {
        const column = this.contextMenuColumn != null ? this.contextMenuColumn : this.tableEditor.getCursorPosition().column
        this.fitColumnToContent(column)
      },
      'tablr:fit-row-to-content' () {
        const row = this.contextMenuRow != null ? this.contextMenuRow : this.tableEditor.getCursorPosition().row
        this.fitRowToContent(row)
      }
    })

    atom.commands.add('tablr-editor atom-text-editor[mini]', stopEventPropagation({
      'core:move-up' () { this.moveUp() },
      'core:move-down' () { this.moveDown() },
      'core:move-to-top' () { this.moveToTop() },
      'core:move-to-bottom' () { this.moveToBottom() },
      'core:page-up' () { this.pageUp() },
      'core:page-down' () { this.pageDown() },
      'core:select-to-top' () { this.selectToTop() },
      'core:select-to-bottom' () { this.selectToBottom() },
      'core:select-page-up' () { this.selectPageUp() },
      'core:select-page-down' () { this.selectPageDown() },
      'editor:add-selection-below' () { this.addSelectionBelow() },
      'editor:add-selection-above' () { this.addSelectionAbove() },
      'editor:split-selections-into-lines' () { this.splitSelectionsIntoLines() },
      'editor:toggle-soft-tabs' () { this.toggleSoftTabs() },
      'editor:toggle-soft-wrap' () { this.toggleSoftWrapped() },
      'editor:fold-all' () { this.foldAll() },
      'editor:unfold-all' () { this.unfoldAll() },
      'editor:fold-current-row' () { this.foldCurrentRow() },
      'editor:unfold-current-row' () { this.unfoldCurrentRow() },
      'editor:fold-selection' () { this.foldSelectedLines() },
      'editor:fold-at-indent-level-1' () { this.foldAllAtIndentLevel(0) },
      'editor:fold-at-indent-level-2' () { this.foldAllAtIndentLevel(1) },
      'editor:fold-at-indent-level-3' () { this.foldAllAtIndentLevel(2) },
      'editor:fold-at-indent-level-4' () { this.foldAllAtIndentLevel(3) },
      'editor:fold-at-indent-level-5' () { this.foldAllAtIndentLevel(4) },
      'editor:fold-at-indent-level-6' () { this.foldAllAtIndentLevel(5) },
      'editor:fold-at-indent-level-7' () { this.foldAllAtIndentLevel(6) },
      'editor:fold-at-indent-level-8' () { this.foldAllAtIndentLevel(7) },
      'editor:fold-at-indent-level-9' () { this.foldAllAtIndentLevel(8) },
      'editor:log-cursor-scope' () { this.logCursorScope() },
      'editor:copy-path' () { this.copyPathToClipboard() },
      'editor:toggle-indent-guide' () {
        atom.config.set('editor.showIndentGuide', !atom.config.get('editor.showIndentGuide'))
      },
      'editor:toggle-line-numbers' () {
        atom.config.set('editor.showLineNumbers', !atom.config.get('editor.showLineNumbers'))
      },
      'editor:scroll-to-cursor' () { this.scrollToCursorPosition() }
    }))

    atom.commands.add('tablr-editor atom-text-editor[mini]', stopEventPropagationAndGroupUndo({
      'editor:indent' () { this.indent() },
      'editor:auto-indent' () { this.autoIndentSelectedRows() },
      'editor:indent-selected-rows' () { this.indentSelectedRows() },
      'editor:outdent-selected-rows' () { this.outdentSelectedRows() },
      'editor:newline' () { this.insertNewline() },
      'editor:newline-below' () { this.insertNewlineBelow() },
      'editor:newline-above' () { this.insertNewlineAbove() },
      'editor:toggle-line-comments' () { this.toggleLineCommentsInSelection() },
      'editor:checkout-head-revision' () { this.checkoutHeadRevision() },
      'editor:move-line-up' () { this.moveLineUp() },
      'editor:move-line-down' () { this.moveLineDown() },
      'editor:duplicate-lines' () { this.duplicateLines() },
      'editor:join-lines' () { this.joinLines() }
    }))
  }

  createdCallback () {
    this.buildContent()

    this.cells = {}
    this.headerCells = {}
    this.gutterCells = {}

    this.readOnly = this.hasAttribute('read-only')

    this.subscriptions = new CompositeDisposable()

    this.subscribeToContent()
    this.subscribeToConfig()

    this.initCellsPool(TableCellElement, this.tableCells)
    this.initHeaderCellsPool(TableHeaderCellElement, this.tableHeaderCells)
    this.initGutterCellsPool(TableGutterCellElement, this.tableGutter)
  }

  attributeChangedCallback (attrName, oldVal, newVal) {
    switch (attrName) {
      case 'read-only': this.readOnly = (newVal != null)
    }
  }

  subscribeToContent () {
    this.subscriptions.add(this.subscribeTo(this.hiddenInput, {
      'textInput': e => {
        if (!this.isEditing()) {
          if (this.tableEditor.getScreenColumnCount() === 0) {
            this.insertColumnAfter()
          }
          if (this.tableEditor.getScreenRowCount() === 0) {
            this.insertRowAfter()
          }
          this.startCellEdit(e.data)
        }
      }
    }))

    this.subscriptions.add(this.subscribeTo(this, {
      'mousedown': stopPropagationAndDefault(e => this.focus()),
      'click': stopPropagationAndDefault()
    }))

    this.subscriptions.add(this.subscribeTo(this.head, {
      'mousedown': stopPropagationAndDefault(e => {
        if (e.button !== 0) { return }

        const columnIndex = this.getScreenColumnIndexAtPixelPosition(e.pageX, e.pageY)
        if (columnIndex === this.tableEditor.order) {
          if (this.tableEditor.direction === -1) {
            this.tableEditor.resetSort()
          } else {
            this.tableEditor.toggleSortDirection()
          }
        } else {
          this.tableEditor.sortBy(columnIndex)
        }
      })
    }))

    this.subscriptions.add(this.subscribeTo(this.getRowsContainer(), {
      'scroll': e => {
        this.requestUpdate()
        this.cancelEllipsisDisplay()
      }
    }))

    this.subscriptions.add(this.subscribeTo(this.head, 'tablr-header-cell .column-edit-action', {
      'mousedown': stopPropagationAndDefault(e => {}),
      'click': stopPropagationAndDefault(e => this.startColumnEdit(e))
    }))

    this.subscriptions.add(this.subscribeTo(this.head, 'tablr-header-cell .column-fit-action', {
      'mousedown': stopPropagationAndDefault(e => {}),
      'click': stopPropagationAndDefault(e => {
        const headerCell = e.target.parentNode.parentNode
        this.fitColumnToContent(Number(headerCell.dataset.column))
      })
    }))

    this.subscriptions.add(this.subscribeTo(this.head, 'tablr-header-cell .column-apply-sort-action', {
      'mousedown': stopPropagationAndDefault(e => {}),
      'click': stopPropagationAndDefault(e => this.applySort())
    }))

    this.subscriptions.add(this.subscribeTo(this.head, 'tablr-header-cell .column-resize-handle', {
      'mousedown': stopPropagationAndDefault(e => this.startColumnResizeDrag(e)),
      'click': stopPropagationAndDefault()
    }))

    this.subscriptions.add(this.subscribeTo(this.body, {
      'dblclick': e => this.startCellEdit(),
      'mousedown': stopPropagationAndDefault((e) => {
        if (this.isEditing()) { this.stopEdit() }

        if (e.button !== 0) { return }

        const {metaKey, ctrlKey, shiftKey, pageX, pageY} = e

        const position = this.cellPositionAtScreenPosition(pageX, pageY)
        if (position) {
          if (metaKey || (ctrlKey && process.platform !== 'darwin')) {
            this.tableEditor.addCursorAtScreenPosition(position)
            this.checkEllipsisDisplay()
          } else if (shiftKey) {
            const cursor = this.tableEditor.getLastCursor().getPosition()

            const startRow = Math.min(cursor.row, position.row)
            const endRow = Math.max(cursor.row, position.row)
            const startColumn = Math.min(cursor.column, position.column)
            const endColumn = Math.max(cursor.column, position.column)

            this.tableEditor.getLastSelection().setRange([
              [startRow, startColumn],
              [endRow + 1, endColumn + 1]
            ])
          } else {
            this.tableEditor.setCursorAtScreenPosition(position)
            this.checkEllipsisDisplay()
          }
        }

        this.startDrag(e)
        this.focus()
      }),
      'click': stopPropagationAndDefault()
    }))

    this.subscriptions.add(this.subscribeTo(this.body, '.tablr-gutter', {
      'mousedown': stopPropagationAndDefault(leftClick(e => {
        this.startGutterDrag(e)
      })),
      'click': stopPropagationAndDefault()
    }))

    this.subscriptions.add(this.subscribeTo(this.body, '.tablr-gutter .row-resize-handle', {
      'mousedown': stopPropagationAndDefault(e => this.startRowResizeDrag(e)),
      'click': stopPropagationAndDefault()
    }))

    this.subscriptions.add(this.subscribeTo(this.body, '.selection-box-handle', {
      'mousedown': stopPropagationAndDefault(e => this.startDrag(e)),
      'click': stopPropagationAndDefault()
    }))
  }

  subscribeToConfig () {
    this.observeConfig({
      'tablr.tableEditor.undefinedDisplay': configUndefinedDisplay => {
        this.configUndefinedDisplay = configUndefinedDisplay
        if (this.attached) { this.requestUpdate() }
      },
      'tablr.tableEditor.pageMoveRowAmount': configPageMoveRowAmount => {
        this.configPageMoveRowAmount = configPageMoveRowAmount
        if (this.attached) { this.requestUpdate() }
      },
      'tablr.tableEditor.rowOverdraw': configRowOverdraw => {
        this.configRowOverdraw = configRowOverdraw
        if (this.attached) { this.requestUpdate() }
      },
      'tablr.tableEditor.columnOverdraw': configColumnOverdraw => {
        this.configColumnOverdraw = configColumnOverdraw
        if (this.attached) { this.requestUpdate() }
      },
      'tablr.tableEditor.scrollPastEnd': scrollPastEnd => {
        this.scrollPastEnd = scrollPastEnd
        if (this.attached) { this.requestUpdate() }
      }
    })
  }

  observeConfig (configs) {
    for (let config in configs) {
      const callback = configs[config]
      this.subscriptions.add(atom.config.observe(config, callback))
    }
  }

  getUndefinedDisplay () {
    return this.undefinedDisplay || this.configUndefinedDisplay
  }

  //        ###    ######## ########    ###     ######  ##     ##
  //       ## ##      ##       ##      ## ##   ##    ## ##     ##
  //      ##   ##     ##       ##     ##   ##  ##       ##     ##
  //     ##     ##    ##       ##    ##     ## ##       #########
  //     #########    ##       ##    ######### ##       ##     ##
  //     ##     ##    ##       ##    ##     ## ##    ## ##     ##
  //     ##     ##    ##       ##    ##     ##  ######  ##     ##

  attach (target) {
    target.appendChild(this)
  }

  attachedCallback () {
    if (this.getModel() == null) { this.buildModel() }

    if (atom.views.pollDocument) {
      this.subscriptions.add(atom.views.pollDocument(() => { this.pollDOM() }))
    } else {
      this.intersectionObserver = new IntersectionObserver((entries) => {
        const {intersectionRect} = entries[entries.length - 1]
        if (intersectionRect.width > 0 || intersectionRect.height > 0) {
          this.pollDOM()
        }
      })

      this.intersectionObserver.observe(this)

      const measureDimensions = () => {
        this.pollDOM()
      }
      elementResizeDetector.listenTo(this, measureDimensions)
      this.subscriptions.add(new Disposable(() => { elementResizeDetector.removeListener(this, measureDimensions) }))

      window.addEventListener('resize', measureDimensions)
      this.subscriptions.add(new Disposable(() => { window.removeEventListener('resize', measureDimensions) }))
    }

    this.measureHeightAndWidth()
    this.requestUpdate()
    this.attached = true
  }

  detachedCallback () {
    this.attached = false
  }

  destroy () {
    this.tableEditor.destroy()
  }

  isDestroyed () { return this.destroyed }

  remove () {
    this.parentNode && this.parentNode.removeChild(this)
  }

  pollDOM () {
    if (this.domPollingPaused || this.frameRequested) { return }

    if (this.width !== this.clientWidth || this.height !== this.clientHeight) {
      this.measureHeightAndWidth()
      this.requestUpdate()
    }
  }

  measureHeightAndWidth () {
    this.height = this.clientHeight
    this.width = this.clientWidth
  }

  getGutter () { return this.querySelector('.tablr-gutter') }

  //    ##     ##  #######  ########  ######## ##
  //    ###   ### ##     ## ##     ## ##       ##
  //    #### #### ##     ## ##     ## ##       ##
  //    ## ### ## ##     ## ##     ## ######   ##
  //    ##     ## ##     ## ##     ## ##       ##
  //    ##     ## ##     ## ##     ## ##       ##
  //    ##     ##  #######  ########  ######## ########

  getModel () { return this.tableEditor }

  buildModel () {
    const model = new TableEditor()
    model.addColumn('untitled')
    model.addRow()
    this.setModel(model)
  }

  setModel (table) {
    if (this.isDestroyed()) {
      throw new Error("Can't set the model of a destroyed TableElement")
    }
    if (!table) { return }

    if (this.tableEditor) { this.unsetModel() }

    const subs = new CompositeDisposable()
    this.tableEditor = table
    this.modelSubscriptions = subs
    subs.add(this.tableEditor.onDidAddColumn(e => {
      this.wholeTableIsDirty = true
      this.requestUpdate()
    }))
    subs.add(this.tableEditor.onDidRemoveColumn(e => {
      this.wholeTableIsDirty = true
      this.requestUpdate()
    }))
    subs.add(this.tableEditor.onDidChangeColumnOption(({option, column}) => {
      if (option === 'width') {
        this.wholeTableIsDirty = true
      } else {
        this.markDirtyRange(this.tableEditor.getColumnRange(this.tableEditor.getScreenColumnIndex(column)))
      }
      this.requestUpdate()
    }))
    subs.add(this.tableEditor.onDidChange(() => {
      this.wholeTableIsDirty = true
      this.requestUpdate()
    }))
    subs.add(this.tableEditor.onDidChangeRowHeight(() => {
      this.wholeTableIsDirty = true
      this.requestUpdate()
    }))
    subs.add(this.tableEditor.onDidAddCursor(() => this.requestUpdate()))
    subs.add(this.tableEditor.onDidRemoveCursor(() => this.requestUpdate()))
    subs.add(this.tableEditor.onDidChangeCursorPosition(({newPosition, oldPosition}) => {
      this.markDirtyCell(oldPosition)
      this.markDirtyCell(newPosition)
      this.requestUpdate()
    }))
    subs.add(this.tableEditor.onDidAddSelection(({selection}) => {
      this.addSelection(selection)
      this.markDirtyRange(selection.getRange())
      this.requestUpdate()
    }))
    subs.add(this.tableEditor.onDidRemoveSelection(({selection}) => {
      this.markDirtyRange(selection.getRange())
      this.requestUpdate()
    }))
    subs.add(this.tableEditor.onDidChangeSelectionRange(({oldRange, newRange}) => {
      this.markDirtyRange(oldRange)
      this.markDirtyRange(newRange)
      this.requestUpdate()
    }))
    subs.add(this.tableEditor.onDidChangeCellValue(e => {
      if (e.screenPosition != null) {
        this.markDirtyCell(e.screenPosition)
      } else if (e.screenPositions != null) {
        this.markDirtyCells(e.screenPositions)
      } else if (e.screenRange != null) {
        this.markDirtyRange(e.screenRange)
      }

      this.requestUpdate()
    }))
    subs.add(this.tableEditor.onDidDestroy(() => {
      this.unsetModel()
      this.subscriptions.dispose()
      this.destroyed = true
      this.subscriptions = null
      this.clearCells()
      this.clearGutterCells()
      this.clearHeaderCells()
      this.remove()
    }))

    this.tableEditor.getSelections().forEach(selection => {
      this.addSelection(selection)
    })

    this.requestUpdate()
  }

  unsetModel () {
    this.modelSubscriptions.dispose()
    this.modelSubscriptions = null
    this.tableEditor = null
  }

  //    ########   #######  ##      ##  ######
  //    ##     ## ##     ## ##  ##  ## ##    ##
  //    ##     ## ##     ## ##  ##  ## ##
  //    ########  ##     ## ##  ##  ##  ######
  //    ##   ##   ##     ## ##  ##  ##       ##
  //    ##    ##  ##     ## ##  ##  ## ##    ##
  //    ##     ##  #######   ###  ###   ######

  isCursorRow (row) {
    return this.tableEditor.getCursors().some(cursor =>
      cursor.getPosition().row === row
    )
  }

  isSelectedRow (row) {
    return this.tableEditor.getSelections().some(selection =>
      selection.getRange().containsRow(row)
    )
  }

  getRowsContainer () { return this.tableRows }

  getRowsOffsetContainer () { return this.getRowsWrapper() }

  getRowsScrollContainer () { return this.getRowsContainer() }

  getRowsWrapper () { return this.tableCells }

  getRowResizeRuler () { return this.rowRuler }

  insertRowBefore () {
    if (!this.readOnly) { this.tableEditor.insertRowBefore() }
  }

  insertRowAfter () {
    if (!this.readOnly) { this.tableEditor.insertRowAfter() }
  }

  deleteRowAtCursor () {
    if (!this.readOnly) { this.tableEditor.deleteRowAtCursor() }
  }

  deleteSelectedRows () {
    if (!this.readOnly) { this.tableEditor.deleteSelectedRows() }
  }

  getFirstVisibleRow () {
    return this.tableEditor.getScreenRowIndexAtPixelPosition(
      this.getRowsScrollContainer().scrollTop
    )
  }

  getLastVisibleRow () {
    const scrollViewHeight = this.getRowsScrollContainer().clientHeight

    return this.tableEditor.getScreenRowIndexAtPixelPosition(
      this.getRowsScrollContainer().scrollTop + scrollViewHeight
    )
  }

  getRowOverdraw () {
    return this.rowOverdraw != null ? this.rowOverdraw : this.configRowOverdraw
  }

  setRowOverdraw (rowOverdraw) {
    this.rowOverdraw = rowOverdraw
    this.requestUpdate()
  }

  getScreenRowIndexAtPixelPosition (y) {
    y -= this.getRowsOffsetContainer().getBoundingClientRect().top

    return this.tableEditor.getScreenRowIndexAtPixelPosition(y)
  }

  rowScreenPosition (row) {
    const top = this.tableEditor.getScreenRowOffsetAt(row)
    const content = this.getRowsScrollContainer()
    const contentOffset = content.getBoundingClientRect()

    return top + contentOffset.top
  }

  makeRowVisible (row) {
    const container = this.getRowsScrollContainer()
    const scrollViewHeight = container.offsetHeight
    const currentScrollTop = container.scrollTop

    const rowHeight = this.tableEditor.getScreenRowHeightAt(row)
    const rowOffset = this.tableEditor.getScreenRowOffsetAt(row)

    const scrollTopAsFirstVisibleRow = rowOffset
    const scrollTopAsLastVisibleRow = rowOffset - (scrollViewHeight - rowHeight)

    if (scrollTopAsFirstVisibleRow >= currentScrollTop &&
        scrollTopAsFirstVisibleRow + rowHeight <= currentScrollTop + scrollViewHeight) {
      return
    }

    if (rowOffset > currentScrollTop) {
      container.scrollTop = scrollTopAsLastVisibleRow
    } else {
      container.scrollTop = scrollTopAsFirstVisibleRow
    }
  }

  measureRowHeight (row) {
    this.ensureMeasuringCell()

    let height = 0
    for (let value of this.tableEditor.table.getRow(row)) {
      this.measuringCell.textContent = value
      height = Math.max(height, this.measuringCell.offsetHeight)
    }

    return height
  }

  fitRowToContent (row) {
    const height = this.measureRowHeight(this.tableEditor.screenRowToModelRow(row))

    this.tableEditor.setScreenRowHeightAt(row, height)
  }

  //     ######   #######  ##       ##     ## ##     ## ##    ##  ######
  //    ##    ## ##     ## ##       ##     ## ###   ### ###   ## ##    ##
  //    ##       ##     ## ##       ##     ## #### #### ####  ## ##
  //    ##       ##     ## ##       ##     ## ## ### ## ## ## ##  ######
  //    ##       ##     ## ##       ##     ## ##     ## ##  ####       ##
  //    ##    ## ##     ## ##       ##     ## ##     ## ##   ### ##    ##
  //     ######   #######  ########  #######  ##     ## ##    ##  ######

  getColumnAlign (col) { return this.tableEditor.getScreenColumn(col).align }

  getColumnsAligns () {
    return this.tableEditor.getScreenColumns().map(column => column.align)
  }

  setAbsoluteColumnsWidths (absoluteColumnsWidths) {
    this.absoluteColumnsWidths = absoluteColumnsWidths
    this.requestUpdate()
  }

  setColumnsWidths (columnsWidths) {
    columnsWidths.forEach((w, i) => {
      this.tableEditor.getScreenColumn(i).width = w
    })
    this.requestUpdate()
  }

  getColumnsContainer () { return this.tableHeaderRow }

  getColumnsOffsetContainer () { return this.tableCells }

  getColumnsScrollContainer () { return this.getRowsContainer() }

  getColumnsWrapper () { return this.tableHeaderCells }

  getColumnResizeRuler () { return this.columnRuler }

  insertColumnBefore () {
    if (!this.readOnly) { this.tableEditor.insertColumnBefore() }
  }

  insertColumnAfter () {
    if (!this.readOnly) { this.tableEditor.insertColumnAfter() }
  }

  deleteColumnAtCursor () {
    if (!this.readOnly) { this.tableEditor.deleteColumnAtCursor() }
  }

  deleteSelectedColumns () {
    if (!this.readOnly) { this.tableEditor.deleteSelectedColumns() }
  }

  getFirstVisibleColumn () {
    return this.tableEditor.getScreenColumnIndexAtPixelPosition(
      this.getColumnsScrollContainer().scrollLeft
    )
  }

  getLastVisibleColumn () {
    const scrollViewWidth = this.getColumnsScrollContainer().clientWidth

    return this.tableEditor.getScreenColumnIndexAtPixelPosition(
      this.getColumnsScrollContainer().scrollLeft + scrollViewWidth
    )
  }

  getColumnOverdraw () {
    return this.columnOverdraw != null
      ? this.columnOverdraw
      : this.configColumnOverdraw
  }

  setColumnOverdraw (columnOverdraw) {
    this.columnOverdraw = columnOverdraw
    this.requestUpdate()
  }

  isCursorColumn (column) {
    return this.tableEditor.getCursors().some(cursor =>
      cursor.getPosition().column === column
    )
  }

  isSelectedColumn (column) {
    return this.tableEditor.getSelections().some(selection =>
      selection.getRange().containsColumn(column)
    )
  }

  getScreenColumnIndexAtPixelPosition (x) {
    x -= this.getColumnsOffsetContainer().getBoundingClientRect().left

    return this.tableEditor.getScreenColumnIndexAtPixelPosition(x)
  }

  makeColumnVisible (column) {
    const container = this.getColumnsScrollContainer()
    const columnWidth = this.tableEditor.getScreenColumnWidthAt(column)

    const scrollViewWidth = container.offsetWidth
    const currentScrollLeft = container.scrollLeft

    const columnOffset = this.tableEditor.getScreenColumnOffsetAt(column)

    const scrollLeftAsFirstVisibleColumn = columnOffset
    const scrollLeftAsLastVisibleColumn = columnOffset - (scrollViewWidth - columnWidth)

    if (scrollLeftAsFirstVisibleColumn >= currentScrollLeft &&
        scrollLeftAsFirstVisibleColumn + columnWidth <= currentScrollLeft + scrollViewWidth) {
      return
    }

    if (columnOffset > currentScrollLeft) {
      container.scrollLeft = scrollLeftAsLastVisibleColumn
    } else {
      container.scrollLeft = scrollLeftAsFirstVisibleColumn
    }
  }

  measureColumnWidth (column) {
    this.ensureMeasuringCell()

    let width = 0
    for (let value of this.tableEditor.table.getColumnValues(column)) {
      this.measuringCell.textContent = value
      width = Math.max(width, this.measuringCell.offsetWidth)
    }

    return width
  }

  fitColumnToContent (column) {
    const width = this.measureColumnWidth(column)

    return this.tableEditor.setScreenColumnWidthAt(column, width)
  }

  //     ######  ######## ##       ##        ######
  //    ##    ## ##       ##       ##       ##    ##
  //    ##       ##       ##       ##       ##
  //    ##       ######   ##       ##        ######
  //    ##       ##       ##       ##             ##
  //    ##    ## ##       ##       ##       ##    ##
  //     ######  ######## ######## ########  ######

  cellScreenRect (position) {
    let {top, left, width, height} = this.tableEditor.getScreenCellRect(position)

    const bodyOffset = this.getRowsOffsetContainer().getBoundingClientRect()
    const tableOffset = this.getBoundingClientRect()

    top += bodyOffset.top - tableOffset.top
    left += bodyOffset.left - tableOffset.left

    return {top, left, width, height}
  }

  cellPositionAtScreenPosition (x, y) {
    if ((x == null) || (y == null)) { return }

    const bodyOffset = this.getRowsOffsetContainer().getBoundingClientRect()

    y -= bodyOffset.top
    x -= bodyOffset.left

    const row = this.tableEditor.getScreenRowIndexAtPixelPosition(y)
    const column = this.tableEditor.getScreenColumnIndexAtPixelPosition(x)

    return {row, column}
  }

  makeCellVisible (position) {
    position = Point.fromObject(position)
    this.makeRowVisible(position.row)
    this.makeColumnVisible(position.column)
  }

  isCursorCell (position) {
    return this.tableEditor.getCursors().some(cursor =>
      cursor.getPosition().isEqual(position)
    )
  }

  isSelectedCell (position) {
    return this.tableEditor.getSelections().some(selection =>
      selection.getRange().containsPoint(position)
    )
  }

  ensureMeasuringCell () {
    if (this.measuringCell == null) {
      this.measuringCell = document.createElement('div')
      this.measuringCell.className = 'measuring-cell'
      this.appendChild(this.measuringCell)
    }
  }

  //     ######   #######  ##    ## ######## ########   #######  ##
  //    ##    ## ##     ## ###   ##    ##    ##     ## ##     ## ##
  //    ##       ##     ## ####  ##    ##    ##     ## ##     ## ##
  //    ##       ##     ## ## ## ##    ##    ########  ##     ## ##
  //    ##       ##     ## ##  ####    ##    ##   ##   ##     ## ##
  //    ##    ## ##     ## ##   ###    ##    ##    ##  ##     ## ##
  //     ######   #######  ##    ##    ##    ##     ##  #######  ########

  save () { return this.tableEditor.save() }

  copySelectedCells () { this.tableEditor.copySelectedCells() }

  cutSelectedCells () {
    if (this.readOnly) {
      this.tableEditor.copySelectedCells()
    } else {
      this.tableEditor.cutSelectedCells()
    }
  }

  pasteClipboard () {
    if (!this.readOnly) { this.tableEditor.pasteClipboard() }
  }

  delete () { this.tableEditor.delete() }

  focus () { if (!this.hasFocus()) { this.hiddenInput.focus() } }

  hasFocus () { return document.activeElement === this.hiddenInput }

  moveLeft () {
    this.tableEditor.moveLeft()
    this.afterCursorMove()
  }

  moveRight () {
    this.tableEditor.moveRight()
    this.afterCursorMove()
  }

  moveUp () {
    this.tableEditor.moveUp()
    this.afterCursorMove()
  }

  moveDown () {
    this.tableEditor.moveDown()
    this.afterCursorMove()
  }

  moveLeftInSelection () {
    this.tableEditor.moveLeftInSelection()
    this.afterCursorMove()
  }

  moveRightInSelection () {
    const cursor = this.tableEditor.getLastCursor()
    const lastCell = [
      this.tableEditor.getLastRowIndex(),
      this.tableEditor.getLastColumnIndex()
    ]

    if (cursor.getPosition().isEqual(lastCell) && !cursor.selection.spanMoreThanOneCell()) {
      this.insertRowAfter()
      this.tableEditor.setCursorAtScreenPosition([
        this.tableEditor.getLastRowIndex(),
        0
      ])
    } else {
      this.tableEditor.moveRightInSelection()
    }

    this.afterCursorMove()
  }

  moveUpInSelection () {
    this.tableEditor.moveUpInSelection()
    this.afterCursorMove()
  }

  moveDownInSelection () {
    this.tableEditor.moveDownInSelection()
    this.afterCursorMove()
  }

  moveToTop () {
    this.tableEditor.moveToTop()
    this.afterCursorMove()
  }

  moveToBottom () {
    this.tableEditor.moveToBottom()
    this.afterCursorMove()
  }

  moveToRight () {
    this.tableEditor.moveToRight()
    this.afterCursorMove()
  }

  moveToLeft () {
    this.tableEditor.moveToLeft()
    this.afterCursorMove()
  }

  pageUp () {
    this.tableEditor.pageUp()
    this.afterCursorMove()
  }

  pageDown () {
    this.tableEditor.pageDown()
    this.afterCursorMove()
  }

  pageLeft () {
    this.tableEditor.pageLeft()
    this.afterCursorMove()
  }

  pageRight () {
    this.tableEditor.pageRight()
    this.afterCursorMove()
  }

  addCursorBelowLastSelection () {
    this.tableEditor.addCursorBelowLastSelection()
    this.afterCursorMove()
  }

  addCursorAboveLastSelection () {
    this.tableEditor.addCursorAboveLastSelection()
    this.afterCursorMove()
  }

  addCursorLeftToLastSelection () {
    this.tableEditor.addCursorLeftToLastSelection()
    this.afterCursorMove()
  }

  addCursorRightToLastSelection () {
    this.tableEditor.addCursorRightToLastSelection()
    this.afterCursorMove()
  }

  moveLineDown () {
    this.tableEditor.moveLineDown()
    this.afterCursorMove()
  }

  moveLineUp () {
    this.tableEditor.moveLineUp()
    this.afterCursorMove()
  }

  moveColumnLeft () {
    this.tableEditor.moveColumnLeft()
    this.afterCursorMove()
  }

  moveColumnRight () {
    this.tableEditor.moveColumnRight()
    this.afterCursorMove()
  }

  afterCursorMove () {
    this.makeCellVisible(this.tableEditor.getCursorPosition())
    this.checkEllipsisDisplay()
  }

  checkEllipsisDisplay () {
    this.cancelEllipsisDisplay()
    const cell = this.getScreenCellAtPosition(this.tableEditor.getCursorPosition())
    if (cell && this.contentOverflow(cell)) {
      this.scheduleEllipsisDisplay()
    }
  }

  cancelEllipsisDisplay () {
    if (this.ellipsisTimeout) { clearTimeout(this.ellipsisTimeout) }
    if (this.ellipsisDisplay) {
      this.ellipsisDisplay.parentNode && this.ellipsisDisplay.parentNode.removeChild(this.ellipsisDisplay)
      delete this.ellipsisDisplay
    }
  }

  scheduleEllipsisDisplay () {
    this.ellipsisTimeout = setTimeout(() => this.displayEllipsis(), 500)
  }

  contentOverflow (cell) {
    return cell.scrollHeight > cell.clientHeight || cell.scrollWidth > cell.clientWidth
  }

  displayEllipsis () {
    delete this.ellipsisTimeout

    if (this.isDestroyed() || (this.tableEditor == null)) { return }

    const cellPosition = this.tableEditor.getCursorPosition()
    const cellElement = this.getScreenCellAtPosition(cellPosition)
    if (cellElement == null) { return }

    const cellRect = this.cellScreenRect(cellPosition)
    const bounds = this.getBoundingClientRect()

    this.ellipsisDisplay = document.createElement('div')
    this.ellipsisDisplay.className = 'ellipsis-display'
    this.ellipsisDisplay.textContent = cellElement.textContent
    this.ellipsisDisplay.style.cssText = `
      top: ${Math.round(cellRect.top + bounds.top)}px;
      left: ${Math.round(cellRect.left + bounds.left)}px;
      min-width: ${cellRect.width}px;
      min-height: ${cellRect.height}px;
    `

    this.appendChild(this.ellipsisDisplay)
  }

  alignLeft () {
    if (this.contextMenuColumn != null) {
      this.tableEditor.getScreenColumn(this.contextMenuColumn).align = 'left'
    } else {
      this.tableEditor.getScreenColumn(this.tableEditor.getCursorPosition().column).align = 'left'
    }
  }

  alignCenter () {
    if (this.contextMenuColumn != null) {
      this.tableEditor.getScreenColumn(this.contextMenuColumn).align = 'center'
    } else {
      this.tableEditor.getScreenColumn(this.tableEditor.getCursorPosition().column).align = 'center'
    }
  }

  alignRight () {
    if (this.contextMenuColumn != null) {
      this.tableEditor.getScreenColumn(this.contextMenuColumn).align = 'right'
    } else {
      this.tableEditor.getScreenColumn(this.tableEditor.getCursorPosition().column).align = 'right'
    }
  }

  expandColumn () {
    const amount = atom.config.get('tablr.tableEditor.columnWidthIncrement')

    const columns = []
    this.tableEditor.getCursors().forEach(cursor => {
      const { column } = cursor.getPosition()
      if (columns.includes(column)) { return }

      this.tableEditor.setScreenColumnWidthAt(column, this.tableEditor.getScreenColumnWidthAt(column) + amount)
      columns.push(column)
    })

    this.checkEllipsisDisplay()
  }

  shrinkColumn () {
    const amount = atom.config.get('tablr.tableEditor.columnWidthIncrement')

    const columns = []
    this.tableEditor.getCursors().forEach(cursor => {
      const { column } = cursor.getPosition()
      if (columns.includes(column)) { return }

      this.tableEditor.setScreenColumnWidthAt(column, this.tableEditor.getScreenColumnWidthAt(column) - amount)
      columns.push(column)
    })

    this.checkEllipsisDisplay()
  }

  expandRow () {
    const amount = atom.config.get('tablr.tableEditor.rowHeightIncrement')

    const rows = []
    this.tableEditor.getCursors().forEach(cursor => {
      const { row } = cursor.getPosition()
      if (rows.includes(row)) { return }

      this.tableEditor.setScreenRowHeightAt(row, this.tableEditor.getScreenRowHeightAt(row) + amount)
      rows.push(row)
    })

    this.checkEllipsisDisplay()
  }

  shrinkRow () {
    const amount = atom.config.get('tablr.tableEditor.rowHeightIncrement')

    const rows = []
    this.tableEditor.getCursors().forEach(cursor => {
      const { row } = cursor.getPosition()
      if (rows.includes(row)) { return }

      this.tableEditor.setScreenRowHeightAt(row, this.tableEditor.getScreenRowHeightAt(row) - amount)
      rows.push(row)
    })

    this.checkEllipsisDisplay()
  }

  goToLine ([row, column]) {
    if (row && column) {
      if (typeof column === 'string') {
        column = this.tableEditor.getColumnIndex(column) + 1
      }

      this.tableEditor.setCursorAtScreenPosition([row - 1, column - 1])
    } else if (row != null) {
      this.tableEditor.setCursorAtScreenPosition([row - 1, 0])
    }

    this.makeCellVisible(this.tableEditor.getCursorPosition())
  }

  openGoToLineModal () {
    const goToLineElement = new GoToLineElement()
    goToLineElement.setModel(this)
    goToLineElement.attach()
    return goToLineElement
  }

  applySort () { this.tableEditor.applySort() }

  //    ######## ########  #### ########
  //    ##       ##     ##  ##     ##
  //    ##       ##     ##  ##     ##
  //    ######   ##     ##  ##     ##
  //    ##       ##     ##  ##     ##
  //    ##       ##     ##  ##     ##
  //    ######## ########  ####    ##

  isEditing () { return this.editing }

  startCellEdit (initialData) {
    if (this.readOnly) { return }

    this.createTextEditor()

    this.subscribeToCellTextEditor(this.editor)

    this.editing = true

    const cursor = this.tableEditor.getLastCursor()
    const position = cursor.getPosition()
    const activeCellRect = this.cellScreenRect(position)
    const bounds = this.getBoundingClientRect()

    const leftPos = Math.max(activeCellRect.left + bounds.left, bounds.left)
    const topPos = Math.max(activeCellRect.top + bounds.top, bounds.top)
    const availableWidth = (bounds.left + this.clientWidth) - leftPos
    const availableHeight = (bounds.top + this.clientHeight) - topPos
    const preferredWidth = Math.min(activeCellRect.width, availableWidth)
    const preferredHeight = Math.min(activeCellRect.height, availableHeight)

    this.editorElement.style.top = this.toUnit(topPos)
    this.editorElement.style.left = this.toUnit(leftPos)
    this.editorElement.style.minWidth = this.toUnit(preferredWidth)
    this.editorElement.style.maxWidth = this.toUnit(availableWidth)
    this.editorElement.style.minHeight = this.toUnit(preferredHeight)
    this.editorElement.style.maxHeight = this.toUnit(availableHeight)
    this.editorElement.style.display = 'block'

    const column = this.tableEditor.getScreenColumn(position.column)
    this.editor.setGrammar(atom.grammars.grammarForScopeName(column.grammarScope))

    this.editorElement.dataset.column = column.name || columnName(position.column)
    this.editorElement.dataset.row = position.row + 1

    this.editorElement.focus()

    const cursorValue = cursor.getValue()
    this.editor.setText(String(cursorValue || this.getUndefinedDisplay()))

    this.editor.getBuffer().history.clearUndoStack()
    this.editor.getBuffer().history.clearRedoStack()

    if (initialData) { this.editor.setText(initialData) }
  }

  confirmCellEdit () {
    this.stopEdit()
    const positions = this.tableEditor.getCursors().map(c => c.getPosition())

    const newValue = this.editor.getText()
    if (newValue !== this.tableEditor.getLastCursor().getValue()) {
      this.tableEditor.setValuesAtScreenPositions(positions, [newValue])
    }
  }

  startColumnEdit ({target, pageX, pageY}) {
    if (this.readOnly) { return }

    this.createTextEditor()

    this.subscribeToColumnTextEditor(this.editor)

    this.editing = true

    const headerCell = target.parentNode.parentNode
    const columnIndex = Number(headerCell.dataset.column)

    this.columnUnderEdit = this.tableEditor.getScreenColumn(columnIndex)
    if (this.columnUnderEdit) {
      this.columnUnderEditIndex = columnIndex
      const columnRect = headerCell.getBoundingClientRect()

      this.editor.setGrammar(atom.grammars.grammarForScopeName('text.plain.null-grammar'))

      this.editorElement.style.top = this.toUnit(columnRect.top)
      this.editorElement.style.left = this.toUnit(columnRect.left)
      this.editorElement.style.minWidth = this.toUnit(columnRect.width)
      this.editorElement.style.minHeight = this.toUnit(columnRect.height)
      this.editorElement.style.display = 'block'

      this.editorElement.removeAttribute('data-row')
      this.editorElement.removeAttribute('data-column')

      this.editorElement.focus()
      this.editor.setText(this.columnUnderEdit.name != null ? this.columnUnderEdit.name : columnName(columnIndex))

      this.editor.getBuffer().history.clearUndoStack()
      this.editor.getBuffer().history.clearRedoStack()
    }
  }

  confirmColumnEdit () {
    this.stopEdit()
    const newValue = this.editor.getText()

    if (newValue === '' || newValue === columnName(this.columnUnderEditIndex)) {
      this.columnUnderEdit.name = undefined
    } else if (newValue !== this.columnUnderEdit.name) {
      this.columnUnderEdit.name = newValue
    }

    delete this.columnUnderEdit
    delete this.columnUnderEditIndex
  }

  stopEdit () {
    this.editing = false
    if (this.editorElement && this.editorElement.parentNode) {
      this.editorElement.parentNode.removeChild(this.editorElement)
    }
    this.textEditorSubscriptions && this.textEditorSubscriptions.dispose()
    delete this.textEditorSubscriptions
    this.focus()
  }

  createTextEditor () {
    if (!this.editor) {
      this.editor = atom.workspace.buildTextEditor({mini: true})
    }
    if (!this.editorElement) {
      this.editorElement = atom.views.getView(this.editor)
    }
    this.appendChild(this.editorElement)
  }

  subscribeToCellTextEditor (editor) {
    this.textEditorSubscriptions = new CompositeDisposable()
    this.textEditorSubscriptions.add(atom.commands.add('tablr-editor atom-text-editor[mini]', {
      'tablr:move-right-in-selection': stopPropagationAndDefault(e => {
        this.confirmCellEdit()
        this.moveRightInSelection()
      }),
      'tablr:move-left-in-selection': stopPropagationAndDefault(e => {
        this.confirmCellEdit()
        this.moveLeftInSelection()
      }),
      'core:cancel': stopPropagation(e => {
        this.stopEdit()
        return false
      }),
      'core:confirm': stopPropagation(e => {
        this.confirmCellEdit()
        return false
      })
    }))

    this.textEditorSubscriptions.add(this.subscribeTo(this.editorElement, {
      'click': stopPropagationAndDefault(e => this.editorElement.focus())
    }))
  }

  subscribeToColumnTextEditor (editorView) {
    this.textEditorSubscriptions = new CompositeDisposable()
    this.textEditorSubscriptions.add(atom.commands.add('tablr-editor atom-text-editor[mini]', {
      'tablr:move-right-in-selection': stopPropagationAndDefault(e => {
        this.confirmColumnEdit()
        this.moveRightInSelection()
      }),
      'tablr:move-left-in-selection': stopPropagationAndDefault(e => {
        this.confirmColumnEdit()
        this.moveLeftInSelection()
      }),
      'core:cancel': stopPropagation(e => {
        this.stopEdit()
        return false
      }),
      'core:confirm': stopPropagation(e => {
        this.confirmColumnEdit()
        return false
      })
    }))

    this.textEditorSubscriptions.add(this.subscribeTo(this.editorElement, {
      'click': stopPropagationAndDefault(e => this.editorElement.focus())
    }))
  }

  //     ######  ######## ##       ########  ######  ########
  //    ##    ## ##       ##       ##       ##    ##    ##
  //    ##       ##       ##       ##       ##          ##
  //     ######  ######   ##       ######   ##          ##
  //          ## ##       ##       ##       ##          ##
  //    ##    ## ##       ##       ##       ##    ##    ##
  //     ######  ######## ######## ########  ######     ##

  addSelection (selection) {
    const selectionElement = atom.views.getView(selection)

    this.tableCells.appendChild(selectionElement)
  }

  resetSelections () {
    this.tableEditor.setSelectedRange(this.tableEditor.getLastSelection().getRange())
  }

  expandSelectionRight () {
    this.tableEditor.expandRight()
    this.makeColumnVisible(this.tableEditor.getLastSelection().getRange().end.column - 1)
    this.requestUpdate()
  }

  expandSelectionLeft () {
    this.tableEditor.expandLeft()
    this.makeColumnVisible(this.tableEditor.getLastSelection().getRange().start.column)
    this.requestUpdate()
  }

  expandSelectionUp () {
    this.tableEditor.expandUp()
    this.makeRowVisible(this.tableEditor.getLastSelection().getRange().start.row)
    this.requestUpdate()
  }

  expandSelectionDown () {
    this.tableEditor.expandDown()
    this.makeRowVisible(this.tableEditor.getLastSelection().getRange().end.row - 1)
    this.requestUpdate()
  }

  expandSelectionToEndOfLine () {
    this.tableEditor.expandToRight()
    this.makeColumnVisible(this.tableEditor.getLastSelection().getRange().end.column - 1)
    this.requestUpdate()
  }

  expandSelectionToBeginningOfLine () {
    this.tableEditor.expandToLeft()
    this.makeColumnVisible(this.tableEditor.getLastSelection().getRange().start.column)
    this.requestUpdate()
  }

  expandSelectionToEndOfTable () {
    this.tableEditor.expandToBottom()
    this.makeRowVisible(this.tableEditor.getLastSelection().getRange().end.row - 1)
    this.requestUpdate()
  }

  expandSelectionToBeginningOfTable () {
    this.tableEditor.expandToTop()
    this.makeRowVisible(this.tableEditor.getLastSelection().getRange().start.row)
    this.requestUpdate()
  }

  //    ########    ####    ########
  //    ##     ##  ##  ##   ##     ##
  //    ##     ##   ####    ##     ##
  //    ##     ##  ####     ##     ##
  //    ##     ## ##  ## ## ##     ##
  //    ##     ## ##   ##   ##     ##
  //    ########   ####  ## ########

  startDragScrollInterval (method, ...args) {
    this.dragScrollInterval = setInterval(() => method.apply(this, args), 50)
  }

  clearDragScrollInterval () {
    clearInterval(this.dragScrollInterval)
  }

  startDrag (e) {
    if (this.dragging) { return }

    this.dragging = true

    let selection
    if (e.target.matches('.selection-box-handle')) {
      selection = e.target.parentNode.getModel()
    }

    this.initializeDragEvents(this.body, {
      'mousemove': stopPropagationAndDefault(e => this.drag(e, selection)),
      'mouseup': stopPropagationAndDefault(e => this.endDrag(e, selection))
    })
  }

  drag (e, selection) {
    this.clearDragScrollInterval()

    let cursorPosition
    if (this.dragging) {
      if (selection != null) {
        cursorPosition = selection.getCursor().getPosition()
      } else {
        selection = this.tableEditor.getLastSelection()
        cursorPosition = selection.getCursor().getPosition()
      }

      const {pageX, pageY} = e
      const newRange = new Range()
      let {row, column} = this.cellPositionAtScreenPosition(pageX, pageY)

      row = Math.max(0, row)
      column = Math.max(0, column)

      if (row < cursorPosition.row) {
        newRange.start.row = row
        newRange.end.row = cursorPosition.row + 1
      } else if (row > cursorPosition.row) {
        newRange.end.row = row + 1
        newRange.start.row = cursorPosition.row
      } else {
        newRange.end.row = cursorPosition.row + 1
        newRange.start.row = cursorPosition.row
      }

      if (column < cursorPosition.column) {
        newRange.start.column = column
        newRange.end.column = cursorPosition.column + 1
      } else if (column > cursorPosition.column) {
        newRange.end.column = column + 1
        newRange.start.column = cursorPosition.column
      } else {
        newRange.end.column = cursorPosition.column + 1
        newRange.start.column = cursorPosition.column
      }

      selection.setRange(newRange)

      this.scrollDuringDrag(row, column)
      this.requestUpdate()

      this.startDragScrollInterval(this.drag, e, selection)
    }
  }

  endDrag (e, selection) {
    if (!this.dragging) { return }

    this.drag(e, selection)
    this.clearDragScrollInterval()
    this.tableEditor.mergeSelections()
    this.dragging = false
    this.dragSubscription.dispose()
  }

  startGutterDrag (e) {
    if (this.dragging) { return }

    const {metaKey, ctrlKey, pageY} = e

    const row = this.getScreenRowIndexAtPixelPosition(pageY)
    if (row == null) { return }

    this.dragging = true

    if (metaKey || (ctrlKey && process.platform !== 'darwin')) {
      this.tableEditor.addSelectionAtScreenRange(this.tableEditor.getRowRange(row))
    } else {
      this.tableEditor.setSelectedRow(row)
    }

    const selection = this.tableEditor.getLastSelection()

    this.initializeDragEvents(this.body, {
      'mousemove': stopPropagationAndDefault(e => {
        this.gutterDrag(e, {startRow: row, selection})
      }),
      'mouseup': stopPropagationAndDefault(e => {
        this.endGutterDrag(e, {startRow: row, selection})
      })
    })
  }

  gutterDrag (e, o) {
    const {pageY} = e
    const {startRow, selection} = o
    if (this.dragging) {
      this.clearDragScrollInterval()
      const row = this.getScreenRowIndexAtPixelPosition(pageY)

      if (row > startRow) {
        selection.setRange(this.tableEditor.getRowsRange([startRow, row]))
      } else if (row < startRow) {
        selection.setRange(this.tableEditor.getRowsRange([row, startRow]))
      } else {
        selection.setRange(this.tableEditor.getRowRange(row))
      }

      this.scrollDuringDrag(row)
      this.requestUpdate()
      this.startDragScrollInterval(this.gutterDrag, e, o)
    }
  }

  endGutterDrag (e, o) {
    if (!this.dragging) { return }

    this.dragSubscription.dispose()
    this.gutterDrag(e, o)
    this.clearDragScrollInterval()
    this.dragging = false
  }

  startRowResizeDrag (e) {
    if (this.dragging) { return }

    this.dragging = true

    const row = this.getScreenRowIndexAtPixelPosition(e.pageY)

    const handle = e.target
    const handleHeight = handle.offsetHeight
    const handleOffset = handle.getBoundingClientRect()
    const dragOffset = handleOffset.top - e.pageY

    const initial = {row, handle, handleHeight, dragOffset}

    const rulerTop = this.tableEditor.getScreenRowOffsetAt(row) + this.tableEditor.getScreenRowHeightAt(row)

    const ruler = this.getRowResizeRuler()
    ruler.classList.add('visible')
    ruler.style.top = this.toUnit(rulerTop)

    return this.initializeDragEvents(this.body, {
      'mousemove': stopPropagationAndDefault(e => {
        this.rowResizeDrag(e, initial)
      }),
      'mouseup': stopPropagationAndDefault(e => {
        this.endRowResizeDrag(e, initial)
      })
    }
    )
  }

  rowResizeDrag ({pageY}, {row, handleHeight, dragOffset}) {
    if (this.dragging) {
      const ruler = this.getRowResizeRuler()
      const rowY = this.tableEditor.getScreenRowOffsetAt(row) - this.getRowsScrollContainer().scrollTop
      const rulerTop = Math.max(
        rowY + this.tableEditor.getMinimumRowHeight(),
        pageY - this.body.getBoundingClientRect().top + dragOffset
      )
      ruler.style.top = this.toUnit(rulerTop)
    }
  }

  endRowResizeDrag ({pageY}, {row, handleHeight, dragOffset}) {
    if (!this.dragging) { return }

    const rowY = this.rowScreenPosition(row) - this.getRowsScrollContainer().scrollTop
    const newRowHeight = (pageY - rowY) + dragOffset + handleHeight
    this.tableEditor.setScreenRowHeightAt(row, Math.max(this.tableEditor.getMinimumRowHeight(), newRowHeight))
    this.getRowResizeRuler().classList.remove('visible')

    this.dragSubscription.dispose()
    this.dragging = false
  }

  startColumnResizeDrag ({pageX, target}) {
    if (this.dragging) { return }

    this.dragging = true

    const handleWidth = target.offsetWidth
    const handleOffset = target.getBoundingClientRect()
    const dragOffset = handleOffset.left - pageX

    const cellElement = target.parentNode
    const position = parseInt(cellElement.dataset.column, 10)

    const initial = {handle: target, position, handleWidth, dragOffset, startX: pageX}

    this.initializeDragEvents(this, {
      'mousemove': stopPropagationAndDefault(e => {
        this.columnResizeDrag(e, initial)
      }),
      'mouseup': stopPropagationAndDefault(e => {
        this.endColumnResizeDrag(e, initial)
      })
    })

    const ruler = this.getColumnResizeRuler()
    ruler.classList.add('visible')
    ruler.style.left = this.toUnit(pageX - this.head.getBoundingClientRect().left)
    ruler.style.height = this.toUnit(this.offsetHeight)
  }

  columnResizeDrag ({pageX}, {position, dragOffset, handleWidth}) {
    const ruler = this.getColumnResizeRuler()

    const headOffset = this.head.getBoundingClientRect().left
    const headWrapperOffset = this.getColumnsOffsetContainer().getBoundingClientRect().left
    const columnX = this.tableEditor.getScreenColumnOffsetAt(position) - this.getColumnsScrollContainer().scrollLeft
    const rulerLeft = Math.max(
      (headWrapperOffset - headOffset) + columnX + this.tableEditor.getMinimumScreenColumnWidth(),
      ((pageX - headOffset) + dragOffset) - ruler.offsetWidth
    )

    ruler.style.left = this.toUnit(rulerLeft)
  }

  endColumnResizeDrag ({pageX}, {startX, position}) {
    if (!this.dragging) { return }

    const moveX = pageX - startX

    const column = this.tableEditor.getScreenColumn(position)
    const width = this.tableEditor.getScreenColumnWidthAt(position)
    column.width = Math.max(this.tableEditor.getMinimumScreenColumnWidth(), width + moveX)

    this.getColumnResizeRuler().classList.remove('visible')
    this.dragSubscription.dispose()
    this.dragging = false
  }

  scrollDuringDrag (row, column) {
    const container = this.getRowsScrollContainer()

    const {scrollTop} = container
    const rowOffset = this.tableEditor.getScreenRowOffsetAt(row)
    const rowHeight = this.tableEditor.getScreenRowHeightAt(row)

    if (row >= this.getLastVisibleRow() - 1 && rowOffset + rowHeight >= (scrollTop + this.height) - (this.height / 5)) {
      container.scrollTop += atom.config.get('tablr.tableEditor.scrollSpeedDuringDrag')
    } else if (row <= this.getFirstVisibleRow() + 1) {
      container.scrollTop -= atom.config.get('tablr.tableEditor.scrollSpeedDuringDrag')
    }

    if (column != null) {
      const {scrollLeft} = container
      const columnOffset = this.tableEditor.getScreenColumnOffsetAt(column)
      const columnWidth = this.tableEditor.getScreenColumnWidthAt(column)

      if (column >= this.getLastVisibleColumn() - 1 && columnOffset + columnWidth >= (scrollLeft + this.width) - (this.width / 5)) {
        container.scrollLeft += atom.config.get('tablr.tableEditor.scrollSpeedDuringDrag')
      } else if (column <= this.getFirstVisibleColumn() + 1) {
        container.scrollLeft -= atom.config.get('tablr.tableEditor.scrollSpeedDuringDrag')
      }
    }
  }

  initializeDragEvents (object, events) {
    this.dragSubscription = new CompositeDisposable()
    for (let event in events) {
      const callback = events[event]
      this.dragSubscription.add(this.addDisposableEventListener(object, event, callback))
    }
  }

  //    ##     ## ########  ########     ###    ######## ########
  //    ##     ## ##     ## ##     ##   ## ##      ##    ##
  //    ##     ## ##     ## ##     ##  ##   ##     ##    ##
  //    ##     ## ########  ##     ## ##     ##    ##    ######
  //    ##     ## ##        ##     ## #########    ##    ##
  //    ##     ## ##        ##     ## ##     ##    ##    ##
  //     #######  ##        ########  ##     ##    ##    ########

  setScrollTop (scroll) {
    if (scroll != null) {
      this.getRowsContainer().scrollTop = scroll
      this.requestUpdate(false)
    }

    this.getRowsContainer().scrollTop
  }

  setScrollLeft (scroll) {
    if (scroll != null) {
      this.getRowsContainer().scrollLeft
      this.requestUpdate(false)
    }

    this.getRowsContainer().scrollLeft
  }

  requestUpdate (hasChanged = true) {
    this.hasChanged = hasChanged
    if (this.destroyed || this.updateRequested) { return }

    this.updateRequested = true
    requestAnimationFrame(() => {
      this.update()
      this.updateRequested = false
    })
  }

  markDirtyCell (position) {
    if (this.dirtyPositions == null) { this.dirtyPositions = [] }
    if (this.dirtyPositions[position.row] == null) { this.dirtyPositions[position.row] = [] }
    this.dirtyPositions[position.row][position.column] = true
    if (this.dirtyColumns == null) { this.dirtyColumns = [] }
    this.dirtyColumns[position.column] = true
  }

  markDirtyCells (positions) {
    return positions.map((position) => this.markDirtyCell(position))
  }

  markDirtyRange (range) {
    return range.each((row, column) => this.markDirtyCell({row, column}))
  }

  update () {
    if (this.tableEditor == null) { return }
    const firstVisibleRow = this.getFirstVisibleRow()
    const lastVisibleRow = this.getLastVisibleRow()
    const firstVisibleColumn = this.getFirstVisibleColumn()
    const lastVisibleColumn = this.getLastVisibleColumn()

    if (firstVisibleRow >= this.firstRenderedRow &&
       lastVisibleRow <= this.lastRenderedRow &&
       firstVisibleColumn >= this.firstRenderedColumn &&
       lastVisibleColumn <= this.lastRenderedColumn &&
       !this.hasChanged) {
      return
    }

    const rowOverdraw = this.getRowOverdraw()
    const firstRow = Math.max(0, firstVisibleRow - rowOverdraw)
    const lastRow = Math.min(this.tableEditor.getScreenRowCount(), lastVisibleRow + rowOverdraw)
    const visibleRows = range(firstRow, lastRow)
    const oldVisibleRows = range(this.firstRenderedRow, this.lastRenderedRow)

    const columns = this.tableEditor.getScreenColumns()
    const columnOverdraw = this.getColumnOverdraw()
    const firstColumn = Math.max(0, firstVisibleColumn - columnOverdraw)
    const lastColumn = Math.min(columns.length, lastVisibleColumn + columnOverdraw)
    const visibleColumns = range(firstColumn, lastColumn)
    const oldVisibleColumns = range(this.firstRenderedColumn, this.lastRenderedColumn)

    let intactFirstRow = this.firstRenderedRow
    let intactLastRow = this.lastRenderedRow
    let intactFirstColumn = this.firstRenderedColumn
    let intactLastColumn = this.lastRenderedColumn

    this.updateWidthAndHeight()
    this.updateScroll()
    if (this.wholeTableIsDirty) { this.updateSelections() }

    const endUpdate = () => {
      this.firstRenderedRow = firstRow
      this.lastRenderedRow = lastRow
      this.firstRenderedColumn = firstColumn
      this.lastRenderedColumn = lastColumn
      this.hasChanged = false
      this.dirtyPositions = null
      this.dirtyColumns = null
      this.wholeTableIsDirty = false
    }

    // We never rendered anything
    if (this.firstRenderedRow == null) {
      visibleColumns.forEach(column => {
        this.appendHeaderCell(columns[column], column)
        visibleRows.forEach(row => this.appendCell(row, column))
      })

      visibleRows.forEach(row => this.appendGutterCell(row))

      endUpdate()
    // Whole table redraw, when the table suddenly jump from one edge to the
    // other and the old and new visible range doesn't intersect.
    } else if (lastRow < this.firstRenderedRow ||
               firstRow >= this.lastRenderedRow ||
               lastColumn < this.firstRenderedColumn ||
               firstColumn >= this.lastRenderedColumn) {
      for (let key in this.cells) {
        const cell = this.cells[key]
        this.releaseCell(cell)
      }
      for (let row in this.gutterCells) {
        const cell = this.gutterCells[row]
        this.releaseGutterCell(cell)
      }
      for (let column in this.headerCells) {
        const cell = this.headerCells[column]
        this.releaseHeaderCell(cell)
      }

      this.cells = {}
      this.headerCells = {}
      this.gutterCells = {}

      visibleColumns.forEach(column => {
        this.appendHeaderCell(columns[column], column)
        visibleRows.forEach(row => this.appendCell(row, column))
      })

      visibleRows.forEach(row => this.appendGutterCell(row))

      endUpdate()

    // Classical scroll routine
    } else if (firstRow !== this.firstRenderedRow ||
               lastRow !== this.lastRenderedRow ||
               firstColumn !== this.firstRenderedColumn ||
               lastColumn !== this.lastRenderedColumn) {
      if (firstRow > this.firstRenderedRow) {
        intactFirstRow = firstRow

        for (let row = this.firstRenderedRow; row < firstRow; row++) {
          this.disposeGutterCell(row)
          oldVisibleColumns.forEach(column => this.disposeCell(row, column))
        }
      }
      if (lastRow < this.lastRenderedRow) {
        intactLastRow = lastRow
        for (let row = lastRow; row < this.lastRenderedRow; row++) {
          this.disposeGutterCell(row)
          oldVisibleColumns.forEach(column => this.disposeCell(row, column))
        }
      }
      if (firstColumn > this.firstRenderedColumn) {
        intactFirstColumn = firstColumn
        for (let column = this.firstRenderedColumn; column < firstColumn; column++) {
          this.disposeHeaderCell(column)
          oldVisibleRows.forEach(row => this.disposeCell(row, column))
        }
      }
      if (lastColumn < this.lastRenderedColumn) {
        intactLastColumn = lastColumn
        for (let column = lastColumn; column < this.lastRenderedColumn; column++) {
          this.disposeHeaderCell(column)
          oldVisibleRows.forEach(row => this.disposeCell(row, column))
        }
      }

      if (firstRow < this.firstRenderedRow) {
        for (let row = firstRow; row < this.firstRenderedRow; row++) {
          this.appendGutterCell(row)
          visibleColumns.forEach(column => this.appendCell(row, column))
        }
      }
      if (lastRow > this.lastRenderedRow) {
        for (let row = this.lastRenderedRow; row < lastRow; row++) {
          this.appendGutterCell(row)
          visibleColumns.forEach(column => this.appendCell(row, column))
        }
      }
      if (firstColumn < this.firstRenderedColumn) {
        for (let column = firstColumn; column < this.firstRenderedColumn; column++) {
          this.appendHeaderCell(columns[column], column)
          visibleRows.forEach(row => this.appendCell(row, column))
        }
      }
      if (lastColumn > this.lastRenderedColumn) {
        for (let column = this.lastRenderedColumn; column < lastColumn; column++) {
          this.appendHeaderCell(columns[column], column)
          visibleRows.forEach(row => this.appendCell(row, column))
        }
      }
    }

    if (this.dirtyPositions || this.wholeTableIsDirty) {
      for (let row = intactFirstRow; row < intactLastRow; row++) {
        if (this.wholeTableIsDirty || this.dirtyPositions[row]) {
          this.gutterCells[row] && this.gutterCells[row].setModel({row})
        }

        for (let column = intactFirstColumn; column < intactLastColumn; column++) {
          if (this.wholeTableIsDirty || (this.dirtyPositions[row] && this.dirtyPositions[row][column])) {
            const key = row + '-' + column
            this.cells[key] && this.cells[key].setModel(this.getCellObjectAtPosition([row, column]))
          }
        }
      }

      for (let column = intactFirstColumn; column < intactLastColumn; column++) {
        if (this.wholeTableIsDirty || this.dirtyColumns[column]) {
          this.headerCells[column] && this.headerCells[column].setModel({
            column: columns[column],
            index: column
          })
        }
      }
    }

    endUpdate()
  }

  updateWidthAndHeight () {
    let width = this.tableEditor.getContentWidth()
    let height = this.tableEditor.getContentHeight()

    if (this.scrollPastEnd) {
      const columnWidth = this.tableEditor.getScreenColumnWidth()
      const rowHeight = this.tableEditor.getRowHeight()
      width += Math.max(columnWidth, this.tableRows.offsetWidth - columnWidth)
      height += Math.max(rowHeight * 3, this.tableRows.offsetHeight - (rowHeight * 3))
    }

    this.tableCells.style.cssText = `
      height: ${height}px;
      width: ${width}px;
    `
    this.tableGutter.style.cssText = `height: ${height}px;`
    this.tableHeaderCells.style.cssText = `width: ${width}px;`

    this.tableGutterFiller.textContent = this.tableHeaderFiller.textContent = this.tableEditor.getScreenRowCount()
  }

  updateScroll () {
    this.getColumnsContainer().scrollLeft = this.getColumnsScrollContainer().scrollLeft
    this.getGutter().scrollTop = this.getRowsContainer().scrollTop
  }

  updateSelections () {
    this.tableEditor.getSelections().forEach(selection => atom.views.getView(selection).update())
  }

  getScreenCellAtPosition (position) {
    position = Point.fromObject(position)
    return this.cells[position.row + '-' + position.column]
  }

  appendCell (row, column) {
    const key = row + '-' + column
    this.cells[key] != null
      ? this.cells[key]
      : this.cells[key] = this.requestCell(this.getCellObjectAtPosition([row, column]))
  }

  getCellObjectAtPosition (position) {
    const {row, column} = Point.fromObject(position)

    return {
      cell: {
        value: this.tableEditor.getValueAtScreenPosition([row, column]),
        column: this.tableEditor.getScreenColumn(column)
      },
      column,
      row
    }
  }

  disposeCell (row, column) {
    const key = row + '-' + column
    const cell = this.cells[key]
    if (cell == null) { return }
    this.releaseCell(cell)
    delete this.cells[key]
  }

  appendHeaderCell (column, index) {
    this.headerCells[index] != null
      ? this.headerCells[index]
      : this.headerCells[index] = this.requestHeaderCell({column, index})
  }

  disposeHeaderCell (column) {
    const cell = this.headerCells[column]
    if (!cell) { return }
    this.releaseHeaderCell(cell)
    delete this.headerCells[column]
  }

  appendGutterCell (row) {
    this.gutterCells[row] != null ? this.gutterCells[row] : this.gutterCells[row] = this.requestGutterCell({row})
  }

  disposeGutterCell (row) {
    const cell = this.gutterCells[row]
    if (!cell) { return }
    this.releaseGutterCell(cell)
    delete this.gutterCells[row]
  }

  floatToPercent (w) { return this.toUnit(Math.round(w * 10000) / 100, '%') }

  floatToPixel (w) { return this.toUnit(w) }

  toUnit (value, unit = PIXEL) { return `${value}${unit}` }
}

module.exports = TableElement.initClass()
