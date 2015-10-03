Delegator = require 'delegato'
{Point, TextEditor} = require 'atom'
{CompositeDisposable, Disposable} = require 'event-kit'
{EventsDelegation, SpacePenDSL} = require 'atom-utils'
PropertyAccessors = require 'property-accessors'

columnName = require './column-name'
Table = require './table'
TableEditor = require './table-editor'
TableCellElement = require './table-cell-element'
TableHeaderCellElement = require './table-header-cell-element'
TableGutterCellElement = require './table-gutter-cell-element'
GoToLineElement = require './go-to-line-element'
Range = require './range'
Pool = require './mixins/pool'
PIXEL = 'px'

stopPropagationAndDefault = (f) -> (e) ->
  e.stopPropagation()
  e.preventDefault()
  f?(e)

module.exports =
class TableElement extends HTMLElement
  PropertyAccessors.includeInto(this)
  EventsDelegation.includeInto(this)
  SpacePenDSL.includeInto(this)
  Pool.includeInto(this)
  Delegator.includeInto(this)

  @useShadowRoot()

  @content: ->
    @div class: 'tablr-header', outlet: 'head', =>
      @div class: 'tablr-header-content', =>
        @div class: 'tablr-header-filler', outlet: 'tableHeaderFiller'
        @div class: 'tablr-header-row', outlet: 'tableHeaderRow', =>
          @div class: 'tablr-header-wrapper', outlet: 'tableHeaderCells'
        @div class: 'column-resize-ruler', outlet: 'columnRuler'

    @div class: 'tablr-body', outlet: 'body', =>
      @div class: 'tablr-content', =>
        @div class: 'tablr-rows', outlet: 'tableRows', =>
          @div class: 'tablr-rows-wrapper', outlet: 'tableCells'
        @div class: 'tablr-gutter', =>
          @div class: 'tablr-gutter-wrapper', outlet: 'tableGutter', =>
            @div class: 'tablr-gutter-filler', outlet: 'tableGutterFiller'

        @div class: 'row-resize-ruler', outlet: 'rowRuler'

    @input class: 'hidden-input', outlet: 'hiddenInput'
    @tag 'content', select: 'atom-text-editor'

  @pool 'cell', 'cells'
  @pool 'headerCell', 'headerCells'
  @pool 'gutterCell', 'gutterCells'

  createdCallback: ->
    @cells = {}
    @headerCells = {}
    @gutterCells = {}

    @readOnly = @hasAttribute('read-only')

    @subscriptions = new CompositeDisposable

    @subscribeToContent()
    @subscribeToConfig()

    @initCellsPool(TableCellElement, @tableCells)
    @initHeaderCellsPool(TableHeaderCellElement, @tableHeaderCells)
    @initGutterCellsPool(TableGutterCellElement, @tableGutter)

  attributeChangedCallback: (attrName, oldVal, newVal) ->
    switch attrName
      when 'read-only' then @readOnly = newVal?

  subscribeToContent: ->
    @subscriptions.add @subscribeTo @hiddenInput,
      'textInput': (e) =>
        unless @isEditing()
          @startCellEdit(e.data)

    @subscriptions.add @subscribeTo this,
      'mousedown': stopPropagationAndDefault (e) => @focus()
      'click': stopPropagationAndDefault()

    @subscriptions.add @subscribeTo @head,
      'mousedown': stopPropagationAndDefault (e) =>
        return if e.button isnt 0

        columnIndex = @getScreenColumnIndexAtPixelPosition(e.pageX, e.pageY)
        if columnIndex is @tableEditor.order
          if @tableEditor.direction is -1
            @tableEditor.resetSort()
          else
            @tableEditor.toggleSortDirection()
        else
          @tableEditor.sortBy(columnIndex)

    @subscriptions.add @subscribeTo @getRowsContainer(),
      'scroll': (e) =>
        @requestUpdate()
        @cancelEllipsisDisplay()

    @subscriptions.add @subscribeTo @head, 'atom-table-header-cell .column-edit-action',
      'mousedown': stopPropagationAndDefault (e) =>
      'click': stopPropagationAndDefault (e) => @startColumnEdit(e)

    @subscriptions.add @subscribeTo @head, 'atom-table-header-cell .column-resize-handle',
      'mousedown': stopPropagationAndDefault (e) => @startColumnResizeDrag(e)
      'click': stopPropagationAndDefault()

    @subscriptions.add @subscribeTo @body,
      'dblclick': (e) => @startCellEdit()
      'mousedown': stopPropagationAndDefault (e) =>
        @stopEdit() if @isEditing()

        return if e.button isnt 0

        {metaKey, ctrlKey, shiftKey, pageX, pageY} = e

        if position = @cellPositionAtScreenPosition(e.pageX, e.pageY)
          if metaKey or (ctrlKey and process.platform isnt 'darwin')
            @tableEditor.addCursorAtScreenPosition(position)
            @checkEllipsisDisplay()
          else if shiftKey
            cursor = @tableEditor.getLastCursor().getPosition()

            startRow = Math.min(cursor.row, position.row)
            endRow = Math.max(cursor.row, position.row)
            startColumn = Math.min(cursor.column, position.column)
            endColumn = Math.max(cursor.column, position.column)

            @tableEditor.getLastSelection().setRange([
              [startRow, startColumn]
              [endRow + 1, endColumn + 1]
            ])
          else
            @tableEditor.setCursorAtScreenPosition position
            @checkEllipsisDisplay()

        @startDrag(e)
        @focus()
      'click': stopPropagationAndDefault()

    @subscriptions.add @subscribeTo @body, '.tablr-gutter',
      'mousedown': stopPropagationAndDefault (e) => @startGutterDrag(e)
      'click': stopPropagationAndDefault()

    @subscriptions.add @subscribeTo @body, '.tablr-gutter .row-resize-handle',
      'mousedown': stopPropagationAndDefault (e) => @startRowResizeDrag(e)
      'click': stopPropagationAndDefault()

    @subscriptions.add @subscribeTo @body, '.selection-box-handle',
      'mousedown': stopPropagationAndDefault (e) => @startDrag(e)
      'click': stopPropagationAndDefault()

  subscribeToConfig: ->
    @observeConfig
      'tablr.undefinedDisplay': (@configUndefinedDisplay) =>
        @requestUpdate() if @attached
      'tablr.pageMoveRowAmount': (@configPageMoveRowAmount) =>
        @requestUpdate() if @attached
      'tablr.rowOverdraw': (@configRowOverdraw) =>
        @requestUpdate() if @attached
      'tablr.columnOverdraw': (@configColumnOverdraw) =>
        @requestUpdate() if @attached
      'tablr.scrollPastEnd': (@scrollPastEnd) =>
        @requestUpdate() if @attached

  observeConfig: (configs) ->
    for config, callback of configs
      @subscriptions.add atom.config.observe config, callback

  getUndefinedDisplay: -> @undefinedDisplay ? @configUndefinedDisplay

  #        ###    ######## ########    ###     ######  ##     ##
  #       ## ##      ##       ##      ## ##   ##    ## ##     ##
  #      ##   ##     ##       ##     ##   ##  ##       ##     ##
  #     ##     ##    ##       ##    ##     ## ##       #########
  #     #########    ##       ##    ######### ##       ##     ##
  #     ##     ##    ##       ##    ##     ## ##    ## ##     ##
  #     ##     ##    ##       ##    ##     ##  ######  ##     ##

  attach: (target) ->
    target.appendChild(this)

  attachedCallback: ->
    @buildModel() unless @getModel()?
    @subscriptions.add atom.views.pollDocument => @pollDOM()
    @measureHeightAndWidth()
    @requestUpdate()
    @attached = true

  detachedCallback: ->
    @attached = false

  destroy: ->
    @tableEditor.destroy()

  isDestroyed: -> @destroyed

  remove: ->
    @parentNode?.removeChild(this)

  pollDOM: ->
    return if @domPollingPaused or @frameRequested

    if @width isnt @clientWidth or @height isnt @clientHeight
      @measureHeightAndWidth()
      @requestUpdate()

  measureHeightAndWidth: ->
    @height = @clientHeight
    @width = @clientWidth

  getGutter: -> @shadowRoot.querySelector('.tablr-gutter')

  #    ##     ##  #######  ########  ######## ##
  #    ###   ### ##     ## ##     ## ##       ##
  #    #### #### ##     ## ##     ## ##       ##
  #    ## ### ## ##     ## ##     ## ######   ##
  #    ##     ## ##     ## ##     ## ##       ##
  #    ##     ## ##     ## ##     ## ##       ##
  #    ##     ##  #######  ########  ######## ########

  getModel: -> @tableEditor

  buildModel: ->
    model = new TableEditor
    model.addColumn('untitled')
    model.addRow()
    @setModel(model)

  setModel: (table) ->
    if @isDestroyed()
      throw new Error "Can't set the model of a destroyed TableElement"
    return unless table?

    @unsetModel() if @tableEditor?

    @tableEditor = table
    @modelSubscriptions = subs = new CompositeDisposable()
    subs.add @tableEditor.onDidAddColumn (e) =>
      @wholeTableIsDirty = true
      @requestUpdate()
    subs.add @tableEditor.onDidRemoveColumn (e) =>
      @wholeTableIsDirty = true
      @requestUpdate()
    subs.add @tableEditor.onDidChangeColumnOption ({option, column}) =>
      if option is 'width'
        @wholeTableIsDirty = true
      else
        @markDirtyRange(@tableEditor.getColumnRange(@tableEditor.getScreenColumnIndex(column)))
      @requestUpdate()
    subs.add @tableEditor.onDidChange =>
      @wholeTableIsDirty = true
      @requestUpdate()
    subs.add @tableEditor.onDidChangeRowHeight =>
      @wholeTableIsDirty = true
      @requestUpdate()
    subs.add @tableEditor.onDidAddCursor => @requestUpdate()
    subs.add @tableEditor.onDidRemoveCursor => @requestUpdate()
    subs.add @tableEditor.onDidChangeCursorPosition ({newPosition, oldPosition}) =>
      @markDirtyCell(oldPosition)
      @markDirtyCell(newPosition)
      @requestUpdate()
    subs.add @tableEditor.onDidAddSelection ({selection}) =>
      @addSelection(selection)
      @markDirtyRange(selection.getRange())
      @requestUpdate()
    subs.add @tableEditor.onDidRemoveSelection ({selection}) =>
      @markDirtyRange(selection.getRange())
      @requestUpdate()
    subs.add @tableEditor.onDidChangeSelectionRange ({oldRange, newRange}) =>
      @markDirtyRange(oldRange)
      @markDirtyRange(newRange)
      @requestUpdate()
    subs.add @tableEditor.onDidChangeCellValue (e) =>
      if e.screenPosition?
        @markDirtyCell(e.screenPosition)
      else if e.screenPositions?
        @markDirtyCells(e.screenPositions)
      else if e.screenRange?
        @markDirtyRange(e.screenRange)

      @requestUpdate()
    subs.add @tableEditor.onDidDestroy =>
      @unsetModel()
      @subscriptions.dispose()
      @destroyed = true
      @subscriptions = null
      @clearCells()
      @clearGutterCells()
      @clearHeaderCells()
      @remove()

    @addSelection(selection) for selection in @tableEditor.getSelections()

    @requestUpdate()

  unsetModel: ->
    @modelSubscriptions.dispose()
    @modelSubscriptions = null
    @tableEditor = null

  #    ########   #######  ##      ##  ######
  #    ##     ## ##     ## ##  ##  ## ##    ##
  #    ##     ## ##     ## ##  ##  ## ##
  #    ########  ##     ## ##  ##  ##  ######
  #    ##   ##   ##     ## ##  ##  ##       ##
  #    ##    ##  ##     ## ##  ##  ## ##    ##
  #    ##     ##  #######   ###  ###   ######

  isCursorRow: (row) ->
    @tableEditor.getCursors().some (cursor) -> cursor.getPosition().row is row

  isSelectedRow: (row) ->
    @tableEditor.getSelections().some (selection) ->
      selection.getRange().containsRow(row)

  getRowsContainer: -> @tableRows

  getRowsOffsetContainer: -> @getRowsWrapper()

  getRowsScrollContainer: -> @getRowsContainer()

  getRowsWrapper: -> @tableCells

  getRowResizeRuler: -> @rowRuler

  insertRowBefore: -> @tableEditor.insertRowBefore() unless @readOnly

  insertRowAfter: -> @tableEditor.insertRowAfter() unless @readOnly

  deleteRowAtCursor: -> @tableEditor.deleteRowAtCursor() unless @readOnly

  getFirstVisibleRow: ->
    @tableEditor.getScreenRowIndexAtPixelPosition(@getRowsScrollContainer().scrollTop)

  getLastVisibleRow: ->
    scrollViewHeight = @getRowsScrollContainer().clientHeight

    @tableEditor.getScreenRowIndexAtPixelPosition(@getRowsScrollContainer().scrollTop + scrollViewHeight)

  getRowOverdraw: -> @rowOverdraw ? @configRowOverdraw

  setRowOverdraw: (@rowOverdraw) -> @requestUpdate()

  getScreenRowIndexAtPixelPosition: (y) ->
    y -= @getRowsOffsetContainer().getBoundingClientRect().top

    @tableEditor.getScreenRowIndexAtPixelPosition(y)

  rowScreenPosition: (row) ->
    top = @tableEditor.getScreenRowOffsetAt(row)

    content = @getRowsScrollContainer()
    contentOffset = content.getBoundingClientRect()

    top + contentOffset.top

  makeRowVisible: (row) ->
    container = @getRowsScrollContainer()
    scrollViewHeight = container.offsetHeight
    currentScrollTop = container.scrollTop

    rowHeight = @tableEditor.getScreenRowHeightAt(row)
    rowOffset = @tableEditor.getScreenRowOffsetAt(row)

    scrollTopAsFirstVisibleRow = rowOffset
    scrollTopAsLastVisibleRow = rowOffset - (scrollViewHeight - rowHeight)

    return if scrollTopAsFirstVisibleRow >= currentScrollTop and
              scrollTopAsFirstVisibleRow + rowHeight <= currentScrollTop + scrollViewHeight

    if rowOffset > currentScrollTop
      container.scrollTop = scrollTopAsLastVisibleRow
    else
      container.scrollTop = scrollTopAsFirstVisibleRow

  #     ######   #######  ##       ##     ## ##     ## ##    ##  ######
  #    ##    ## ##     ## ##       ##     ## ###   ### ###   ## ##    ##
  #    ##       ##     ## ##       ##     ## #### #### ####  ## ##
  #    ##       ##     ## ##       ##     ## ## ### ## ## ## ##  ######
  #    ##       ##     ## ##       ##     ## ##     ## ##  ####       ##
  #    ##    ## ##     ## ##       ##     ## ##     ## ##   ### ##    ##
  #     ######   #######  ########  #######  ##     ## ##    ##  ######

  getColumnAlign: (col) -> @tableEditor.getScreenColumn(col).align

  getColumnsAligns: ->
    @tableEditor.getScreenColumns().map (column) -> column.align

  setAbsoluteColumnsWidths: (@absoluteColumnsWidths) -> @requestUpdate()

  setColumnsWidths: (columnsWidths) ->
    @tableEditor.getScreenColumn(i).width = w for w,i in columnsWidths
    @requestUpdate()

  getColumnsContainer: -> @tableHeaderRow

  getColumnsOffsetContainer: -> @tableCells

  getColumnsScrollContainer: -> @getRowsContainer()

  getColumnsWrapper: -> @tableHeaderCells

  getColumnResizeRuler: -> @columnRuler

  insertColumnBefore: -> @tableEditor.insertColumnBefore() unless @readOnly

  insertColumnAfter: -> @tableEditor.insertColumnAfter() unless @readOnly

  deleteColumnAtCursor: -> @tableEditor.deleteColumnAtCursor() unless @readOnly

  getFirstVisibleColumn: ->
    @tableEditor.getScreenColumnIndexAtPixelPosition(@getColumnsScrollContainer().scrollLeft)

  getLastVisibleColumn: ->
    scrollViewWidth = @getColumnsScrollContainer().clientWidth

    @tableEditor.getScreenColumnIndexAtPixelPosition(@getColumnsScrollContainer().scrollLeft + scrollViewWidth)

  getColumnOverdraw: -> @columnOverdraw ? @configColumnOverdraw

  setColumnOverdraw: (@columnOverdraw) -> @requestUpdate()

  isCursorColumn: (column) ->
    @tableEditor.getCursors().some (cursor) ->
      cursor.getPosition().column is column

  isSelectedColumn: (column) ->
    @tableEditor.getSelections().some (selection) ->
      selection.getRange().containsColumn(column)

  getScreenColumnIndexAtPixelPosition: (x) ->
    x -= @getColumnsOffsetContainer().getBoundingClientRect().left

    @tableEditor.getScreenColumnIndexAtPixelPosition(x)

  makeColumnVisible: (column) ->
    container = @getColumnsScrollContainer()
    columnWidth = @tableEditor.getScreenColumnWidthAt(column)

    scrollViewWidth = container.offsetWidth
    currentScrollLeft = container.scrollLeft

    columnOffset = @tableEditor.getScreenColumnOffsetAt(column)

    scrollLeftAsFirstVisibleColumn = columnOffset
    scrollLeftAsLastVisibleColumn = columnOffset - (scrollViewWidth - columnWidth)

    return if scrollLeftAsFirstVisibleColumn >= currentScrollLeft and
              scrollLeftAsFirstVisibleColumn + columnWidth <= currentScrollLeft + scrollViewWidth

    if columnOffset > currentScrollLeft
      container.scrollLeft = scrollLeftAsLastVisibleColumn
    else
      container.scrollLeft = scrollLeftAsFirstVisibleColumn

  #     ######  ######## ##       ##        ######
  #    ##    ## ##       ##       ##       ##    ##
  #    ##       ##       ##       ##       ##
  #    ##       ######   ##       ##        ######
  #    ##       ##       ##       ##             ##
  #    ##    ## ##       ##       ##       ##    ##
  #     ######  ######## ######## ########  ######

  cellScreenRect: (position) ->
    {top, left, width, height} = @tableEditor.getScreenCellRect(position)

    bodyOffset = @getRowsOffsetContainer().getBoundingClientRect()
    tableOffset = @getBoundingClientRect()

    top += bodyOffset.top - tableOffset.top
    left += bodyOffset.left - tableOffset.left

    {top, left, width, height}

  cellPositionAtScreenPosition: (x,y) ->
    return unless x? and y?

    bodyOffset = @getRowsOffsetContainer().getBoundingClientRect()

    y -= bodyOffset.top
    x -= bodyOffset.left

    row = @tableEditor.getScreenRowIndexAtPixelPosition(y)
    column = @tableEditor.getScreenColumnIndexAtPixelPosition(x)

    {row, column}

  makeCellVisible: (position) ->
    position = Point.fromObject(position)
    @makeRowVisible(position.row)
    @makeColumnVisible(position.column)

  isCursorCell: (position) ->
    @tableEditor.getCursors().some (cursor) ->
      cursor.getPosition().isEqual(position)

  isSelectedCell: (position) ->
    @tableEditor.getSelections().some (selection) ->
      selection.getRange().containsPoint(position)

  #     ######   #######  ##    ## ######## ########   #######  ##
  #    ##    ## ##     ## ###   ##    ##    ##     ## ##     ## ##
  #    ##       ##     ## ####  ##    ##    ##     ## ##     ## ##
  #    ##       ##     ## ## ## ##    ##    ########  ##     ## ##
  #    ##       ##     ## ##  ####    ##    ##   ##   ##     ## ##
  #    ##    ## ##     ## ##   ###    ##    ##    ##  ##     ## ##
  #     ######   #######  ##    ##    ##    ##     ##  #######  ########

  save: -> @tableEditor.save()

  copySelectedCells: -> @tableEditor.copySelectedCells()

  cutSelectedCells: ->
    if @readOnly
      @tableEditor.copySelectedCells()
    else
      @tableEditor.cutSelectedCells()

  pasteClipboard: -> @tableEditor.pasteClipboard() unless @readOnly

  delete: -> @tableEditor.delete()

  focus: -> @hiddenInput.focus() unless @hasFocus()

  hasFocus: -> this is document.activeElement

  moveLeft: ->
    @tableEditor.moveLeft()
    @afterCursorMove()

  moveRight: ->
    @tableEditor.moveRight()
    @afterCursorMove()

  moveUp: ->
    @tableEditor.moveUp()
    @afterCursorMove()

  moveDown: ->
    @tableEditor.moveDown()
    @afterCursorMove()

  moveLeftInSelection: ->
    @tableEditor.moveLeftInSelection()
    @afterCursorMove()

  moveRightInSelection: ->
    @tableEditor.moveRightInSelection()
    @afterCursorMove()

  moveUpInSelection: ->
    @tableEditor.moveUpInSelection()
    @afterCursorMove()

  moveDownInSelection: ->
    @tableEditor.moveDownInSelection()
    @afterCursorMove()

  moveToTop: ->
    @tableEditor.moveToTop()
    @afterCursorMove()

  moveToBottom: ->
    @tableEditor.moveToBottom()
    @afterCursorMove()

  moveToRight: ->
    @tableEditor.moveToRight()
    @afterCursorMove()

  moveToLeft: ->
    @tableEditor.moveToLeft()
    @afterCursorMove()

  pageUp: ->
    @tableEditor.pageUp()
    @afterCursorMove()

  pageDown: ->
    @tableEditor.pageDown()
    @afterCursorMove()

  pageLeft: ->
    @tableEditor.pageLeft()
    @afterCursorMove()

  pageRight: ->
    @tableEditor.pageRight()
    @afterCursorMove()

  addCursorBelowLastSelection: ->
    @tableEditor.addCursorBelowLastSelection()
    @afterCursorMove()

  addCursorAboveLastSelection: ->
    @tableEditor.addCursorAboveLastSelection()
    @afterCursorMove()

  addCursorLeftToLastSelection: ->
    @tableEditor.addCursorLeftToLastSelection()
    @afterCursorMove()

  addCursorRightToLastSelection: ->
    @tableEditor.addCursorRightToLastSelection()
    @afterCursorMove()

  afterCursorMove: ->
    @makeCellVisible(@tableEditor.getCursorPosition())
    @checkEllipsisDisplay()

  checkEllipsisDisplay: ->
    @cancelEllipsisDisplay()
    if @getScreenCellAtPosition(@tableEditor.getCursorPosition())?.classList.contains('ellipsis')
      @scheduleEllipsisDisplay()

  cancelEllipsisDisplay: ->
    clearTimeout(@ellipsisTimeout) if @ellipsisTimeout?
    if @ellipsisDisplay?
      @ellipsisDisplay.parentNode?.removeChild(@ellipsisDisplay)
      delete @ellipsisDisplay

  scheduleEllipsisDisplay: ->
    @ellipsisTimeout = setTimeout((=> @displayEllipsis()), 500)

  displayEllipsis: ->
    delete @ellipsisTimeout

    cellPosition = @tableEditor.getCursorPosition()
    cellElement = @getScreenCellAtPosition(cellPosition)
    return unless cellElement?

    cellRect = @cellScreenRect(cellPosition)
    bounds = @getBoundingClientRect()

    @ellipsisDisplay = document.createElement('div')
    @ellipsisDisplay.className = 'ellipsis-display'
    @ellipsisDisplay.textContent = cellElement.textContent
    @ellipsisDisplay.style.cssText = "
      top: #{cellRect.top + bounds.top}px;
      left: #{cellRect.left + bounds.left}px;
      min-width: #{cellRect.width}px;
      min-height: #{cellRect.height}px;
    "

    @shadowRoot.appendChild(@ellipsisDisplay)

  alignLeft: ->
    if @targetColumnForAlignment?
      @tableEditor.getScreenColumn(@targetColumnForAlignment).align = 'left'
    else
      @tableEditor.getScreenColumn(@tableEditor.getCursorPosition().column).align = 'left'

  alignCenter: ->
    if @targetColumnForAlignment?
      @tableEditor.getScreenColumn(@targetColumnForAlignment).align = 'center'
    else
      @tableEditor.getScreenColumn(@tableEditor.getCursorPosition().column).align = 'center'

  alignRight: ->
    if @targetColumnForAlignment?
      @tableEditor.getScreenColumn(@targetColumnForAlignment).align = 'right'
    else
      @tableEditor.getScreenColumn(@tableEditor.getCursorPosition().column).align = 'right'

  expandColumn: ->
    amount = atom.config.get('tablr.columnWidthIncrement')

    columns = []
    @tableEditor.getCursors().forEach (cursor) =>
      column = cursor.getPosition().column
      return if column in columns

      @tableEditor.setScreenColumnWidthAt(column, @tableEditor.getScreenColumnWidthAt(column) + amount)
      columns.push(column)

    @checkEllipsisDisplay()

  shrinkColumn: ->
    amount = atom.config.get('tablr.columnWidthIncrement')

    columns = []
    @tableEditor.getCursors().forEach (cursor) =>
      column = cursor.getPosition().column
      return if column in columns

      @tableEditor.setScreenColumnWidthAt(column, @tableEditor.getScreenColumnWidthAt(column) - amount)
      columns.push(column)

    @checkEllipsisDisplay()

  expandRow: ->
    amount = atom.config.get('tablr.rowHeightIncrement')

    rows = []
    @tableEditor.getCursors().forEach (cursor) =>
      row = cursor.getPosition().row
      return if row in rows

      @tableEditor.setScreenRowHeightAt(row, @tableEditor.getScreenRowHeightAt(row) + amount)
      rows.push(row)

    @checkEllipsisDisplay()

  shrinkRow: ->
    amount = atom.config.get('tablr.rowHeightIncrement')

    rows = []
    @tableEditor.getCursors().forEach (cursor) =>
      row = cursor.getPosition().row
      return if row in rows

      @tableEditor.setScreenRowHeightAt(row, @tableEditor.getScreenRowHeightAt(row) - amount)
      rows.push(row)

    @checkEllipsisDisplay()

  goToLine: ([row, column]) ->
    if row? and column?
      if typeof column is 'string'
        column = @tableEditor.getColumnIndex(column) + 1

      @tableEditor.setCursorAtScreenPosition([row - 1, column - 1])
    else if row?
      @tableEditor.setCursorAtScreenPosition([row - 1, 0])

    @makeCellVisible(@tableEditor.getCursorPosition())

  openGoToLineModal: ->
    goToLineElement = new GoToLineElement()
    goToLineElement.setModel(this)
    goToLineElement.attach()
    goToLineElement

  #    ######## ########  #### ########
  #    ##       ##     ##  ##     ##
  #    ##       ##     ##  ##     ##
  #    ######   ##     ##  ##     ##
  #    ##       ##     ##  ##     ##
  #    ##       ##     ##  ##     ##
  #    ######## ########  ####    ##

  isEditing: -> @editing

  startCellEdit: (initialData) ->
    return if @readOnly

    @createTextEditor() unless @editor?

    @subscribeToCellTextEditor(@editor)

    @editing = true

    cursor = @tableEditor.getLastCursor()
    position = cursor.getPosition()
    activeCellRect = @cellScreenRect(position)
    bounds = @getBoundingClientRect()

    @editorElement.style.top = @toUnit(activeCellRect.top + bounds.top)
    @editorElement.style.left = @toUnit(activeCellRect.left + bounds.left)
    @editorElement.style.minWidth = @toUnit(activeCellRect.width)
    @editorElement.style.minHeight = @toUnit(activeCellRect.height)
    @editorElement.style.display = 'block'

    @editorElement.dataset.column = @tableEditor.getScreenColumn(position.column).name ? columnName(position.column)
    @editorElement.dataset.row = position.row + 1

    @editorElement.focus()

    @editor.setText(String(cursor.getValue() ? @getUndefinedDisplay()))

    @editor.getBuffer().history.clearUndoStack()
    @editor.getBuffer().history.clearRedoStack()

    @editor.setText(initialData) if initialData?

  confirmCellEdit: ->
    @stopEdit()
    positions = @tableEditor.getCursors().map (c) -> c.getPosition()

    newValue = @editor.getText()
    unless newValue is @tableEditor.getLastCursor().getValue()
      @tableEditor.setValuesAtScreenPositions(positions, [newValue])

  startColumnEdit: ({target, pageX, pageY}) =>
    return if @readOnly

    @createTextEditor() unless @editor?

    @subscribeToColumnTextEditor(@editor)

    @editing = true

    columnIndex = @getScreenColumnIndexAtPixelPosition(pageX, pageY)
    if @columnUnderEdit = @tableEditor.getScreenColumn(columnIndex)
      @columnUnderEditIndex = columnIndex
      columnRect = target.parentNode.getBoundingClientRect()

      @editorElement.style.top = @toUnit(columnRect.top)
      @editorElement.style.left =  @toUnit(columnRect.left)
      @editorElement.style.minWidth = @toUnit(columnRect.width)
      @editorElement.style.minHeight = @toUnit(columnRect.height)
      @editorElement.style.display = 'block'

      @editorElement.removeAttribute('data-row')
      @editorElement.removeAttribute('data-column')

      @editorElement.focus()
      @editor.setText(@columnUnderEdit.name ? columnName(columnIndex))

      @editor.getBuffer().history.clearUndoStack()
      @editor.getBuffer().history.clearRedoStack()

  confirmColumnEdit: ->
    @stopEdit()
    newValue = @editor.getText()

    if newValue is '' or newValue is columnName(@columnUnderEditIndex)
      @columnUnderEdit.name = undefined
    else if newValue isnt @columnUnderEdit.name
      @columnUnderEdit.name = newValue

    delete @columnUnderEdit
    delete @columnUnderEditIndex

  stopEdit: ->
    @editing = false
    @editorElement.style.display = 'none'
    @textEditorSubscriptions?.dispose()
    @textEditorSubscriptions = null
    @focus()

  createTextEditor: ->
    @editor = new TextEditor({mini: true})
    @editorElement = atom.views.getView(@editor)
    @appendChild(@editorElement)

  subscribeToCellTextEditor: (editor) ->
    @textEditorSubscriptions = new CompositeDisposable
    @textEditorSubscriptions.add atom.commands.add 'atom-table-editor atom-text-editor[mini]',

      'tablr:move-right-in-selection': (e) =>
        e.stopPropagation()
        @confirmCellEdit()
        @moveRightInSelection()
      'tablr:move-left-in-selection': (e) =>
        e.stopPropagation()
        @confirmCellEdit()
        @moveLeftInSelection()
      'core:cancel': (e) =>
        @stopEdit()
        e.stopPropagation()
        return false
      'core:confirm': (e) =>
        @confirmCellEdit()
        e.stopPropagation()
        return false

    @textEditorSubscriptions.add @subscribeTo @editorElement,
      'click': (e) =>
        e.stopPropagation()
        e.preventDefault()
        @editorElement.focus()

  subscribeToColumnTextEditor: (editorView) ->
    @textEditorSubscriptions = new CompositeDisposable
    @textEditorSubscriptions.add atom.commands.add 'atom-table-editor atom-text-editor[mini]',

      'tablr:move-right-in-selection': (e) =>
        e.stopPropagation()
        @confirmColumnEdit()
        @moveRightInSelection()
      'tablr:move-left-in-selection': (e) =>
        e.stopPropagation()
        @confirmColumnEdit()
        @moveLeftInSelection()
      'core:cancel': (e) =>
        e.stopPropagation()
        @stopEdit()
        return false
      'core:confirm': (e) =>
        e.stopPropagation()
        @confirmColumnEdit()
        return false

  #     ######  ######## ##       ########  ######  ########
  #    ##    ## ##       ##       ##       ##    ##    ##
  #    ##       ##       ##       ##       ##          ##
  #     ######  ######   ##       ######   ##          ##
  #          ## ##       ##       ##       ##          ##
  #    ##    ## ##       ##       ##       ##    ##    ##
  #     ######  ######## ######## ########  ######     ##

  addSelection: (selection) ->
    selectionElement = atom.views.getView(selection)

    @tableCells.appendChild(selectionElement)

  resetSelections: ->
    @tableEditor.setSelectedRange(@tableEditor.getLastSelection().getRange())

  expandSelectionRight: ->
    @tableEditor.expandRight()
    @makeColumnVisible(@tableEditor.getLastSelection().getRange().end.column - 1)
    @requestUpdate()

  expandSelectionLeft: ->
    @tableEditor.expandLeft()
    @makeColumnVisible(@tableEditor.getLastSelection().getRange().start.column)
    @requestUpdate()

  expandSelectionUp: ->
    @tableEditor.expandUp()
    @makeRowVisible(@tableEditor.getLastSelection().getRange().start.row)
    @requestUpdate()

  expandSelectionDown: ->
    @tableEditor.expandDown()
    @makeRowVisible(@tableEditor.getLastSelection().getRange().end.row - 1)
    @requestUpdate()

  expandSelectionToEndOfLine: ->
    @tableEditor.expandToRight()
    @makeColumnVisible(@tableEditor.getLastSelection().getRange().end.column - 1)
    @requestUpdate()

  expandSelectionToBeginningOfLine: ->
    @tableEditor.expandToLeft()
    @makeColumnVisible(@tableEditor.getLastSelection().getRange().start.column)
    @requestUpdate()

  expandSelectionToEndOfTable: ->
    @tableEditor.expandToBottom()
    @makeRowVisible(@tableEditor.getLastSelection().getRange().end.row - 1)
    @requestUpdate()

  expandSelectionToBeginningOfTable: ->
    @tableEditor.expandToTop()
    @makeRowVisible(@tableEditor.getLastSelection().getRange().start.row)
    @requestUpdate()

  #    ########    ####    ########
  #    ##     ##  ##  ##   ##     ##
  #    ##     ##   ####    ##     ##
  #    ##     ##  ####     ##     ##
  #    ##     ## ##  ## ## ##     ##
  #    ##     ## ##   ##   ##     ##
  #    ########   ####  ## ########

  startDragScrollInterval: (method, args...) ->
    @dragScrollInterval = setInterval (=> method.apply(this, args)), 50

  clearDragScrollInterval: ->
    clearInterval(@dragScrollInterval)

  startDrag: (e) ->
    return if @dragging

    @dragging = true

    if e.target.matches('.selection-box-handle')
      selection = e.target.parentNode.getModel()

    @initializeDragEvents @body,
      'mousemove': stopPropagationAndDefault (e) => @drag(e, selection)
      'mouseup': stopPropagationAndDefault (e) => @endDrag(e, selection)

  drag: (e, selection) ->
    @clearDragScrollInterval()

    if @dragging
      if selection?
        cursorPosition = selection.getCursor().getPosition()
      else
        selection = @tableEditor.getLastSelection()
        cursorPosition = selection.getCursor().getPosition()

      {pageX, pageY} = e
      {row, column} = @cellPositionAtScreenPosition pageX, pageY
      newRange = new Range

      row = Math.max(0, row)
      column = Math.max(0, column)

      if row < cursorPosition.row
        newRange.start.row = row
        newRange.end.row = cursorPosition.row + 1
      else if row > cursorPosition.row
        newRange.end.row = row + 1
        newRange.start.row = cursorPosition.row
      else
        newRange.end.row = cursorPosition.row + 1
        newRange.start.row = cursorPosition.row

      if column < cursorPosition.column
        newRange.start.column = column
        newRange.end.column = cursorPosition.column + 1
      else if column > cursorPosition.column
        newRange.end.column = column + 1
        newRange.start.column = cursorPosition.column
      else
        newRange.end.column = cursorPosition.column + 1
        newRange.start.column = cursorPosition.column

      selection.setRange(newRange)

      @scrollDuringDrag(row, column)
      @requestUpdate()

      @startDragScrollInterval(@drag, e, selection)

  endDrag: (e, selection) ->
    return unless @dragging

    @drag(e, selection)
    @clearDragScrollInterval()
    @tableEditor.mergeSelections()
    @dragging = false
    @dragSubscription.dispose()

  startGutterDrag: (e) ->
    return if @dragging

    {metaKey, ctrlKey, shiftKey, pageX, pageY} = e

    row = @getScreenRowIndexAtPixelPosition(pageY)
    return unless row?

    @dragging = true

    if metaKey or (ctrlKey and process.platform isnt 'darwin')
      @tableEditor.addSelectionAtScreenRange(@tableEditor.getRowRange(row))
    else
      @tableEditor.setSelectedRow(row)

    selection = @tableEditor.getLastSelection()

    @initializeDragEvents @body,
      'mousemove': stopPropagationAndDefault (e) =>
        @gutterDrag(e, {startRow: row, selection})
      'mouseup': stopPropagationAndDefault (e) =>
        @endGutterDrag(e, {startRow: row, selection})

  gutterDrag: (e, o) ->
    {pageY} = e
    {startRow, selection} = o
    if @dragging
      @clearDragScrollInterval()
      row = @getScreenRowIndexAtPixelPosition(pageY)

      if row > startRow
        selection.setRange(@tableEditor.getRowsRange([startRow, row]))
      else if row < startRow
        selection.setRange(@tableEditor.getRowsRange([row, startRow]))
      else
        selection.setRange(@tableEditor.getRowRange(row))

      @scrollDuringDrag(row)
      @requestUpdate()
      @startDragScrollInterval(@gutterDrag, e, o)

  endGutterDrag: (e,o) ->
    return unless @dragging

    @dragSubscription.dispose()
    @gutterDrag(e,o)
    @clearDragScrollInterval()
    @dragging = false

  startRowResizeDrag: (e) ->
    return if @dragging

    @dragging = true

    row = @getScreenRowIndexAtPixelPosition(e.pageY)

    handle = e.target
    handleHeight = handle.offsetHeight
    handleOffset = handle.getBoundingClientRect()
    dragOffset = handleOffset.top - e.pageY

    initial = {row, handle, handleHeight, dragOffset}

    rulerTop = @tableEditor.getScreenRowOffsetAt(row) + @tableEditor.getScreenRowHeightAt(row)

    ruler = @getRowResizeRuler()
    ruler.classList.add('visible')
    ruler.style.top = @toUnit(rulerTop)

    @initializeDragEvents @body,
      'mousemove': stopPropagationAndDefault (e) => @rowResizeDrag(e, initial)
      'mouseup': stopPropagationAndDefault (e) => @endRowResizeDrag(e, initial)

  rowResizeDrag: ({pageY}, {row, handleHeight, dragOffset}) ->
    if @dragging
      ruler = @getRowResizeRuler()
      rowY = @tableEditor.getScreenRowOffsetAt(row) - @getRowsScrollContainer().scrollTop
      rulerTop = Math.max(rowY + @tableEditor.getMinimumRowHeight(), pageY - @body.getBoundingClientRect().top + dragOffset)
      ruler.style.top = @toUnit(rulerTop)

  endRowResizeDrag: ({pageY}, {row, handleHeight, dragOffset}) ->
    return unless @dragging

    rowY = @rowScreenPosition(row) - @getRowsScrollContainer().scrollTop
    newRowHeight = pageY - rowY + dragOffset + handleHeight
    @tableEditor.setScreenRowHeightAt(row, Math.max(@tableEditor.getMinimumRowHeight(), newRowHeight))
    @getRowResizeRuler().classList.remove('visible')

    @dragSubscription.dispose()
    @dragging = false

  startColumnResizeDrag: ({pageX, target}) ->
    return if @dragging

    @dragging = true

    handleWidth = target.offsetWidth
    handleOffset = target.getBoundingClientRect()
    dragOffset = handleOffset.left - pageX

    cellElement = target.parentNode
    position = parseInt cellElement.dataset.column

    initial = {handle: target, position, handleWidth, dragOffset, startX: pageX}

    @initializeDragEvents this,
      'mousemove': stopPropagationAndDefault (e) =>
        @columnResizeDrag(e, initial)
      'mouseup': stopPropagationAndDefault (e) =>
        @endColumnResizeDrag(e, initial)

    ruler = @getColumnResizeRuler()
    ruler.classList.add('visible')
    ruler.style.left = @toUnit(pageX - @head.getBoundingClientRect().left)
    ruler.style.height = @toUnit(@offsetHeight)

  columnResizeDrag: ({pageX}, {position, dragOffset, handleWidth}) ->
    ruler = @getColumnResizeRuler()

    headOffset = @head.getBoundingClientRect().left
    headWrapperOffset = @getColumnsOffsetContainer().getBoundingClientRect().left
    columnX = @tableEditor.getScreenColumnOffsetAt(position) - @getColumnsScrollContainer().scrollLeft
    rulerLeft = Math.max(
      headWrapperOffset - headOffset + columnX + @tableEditor.getMinimumScreenColumnWidth(),
      pageX - headOffset + dragOffset - ruler.offsetWidth
    )

    ruler.style.left = @toUnit(rulerLeft)

  endColumnResizeDrag: ({pageX}, {startX, position}) ->
    return unless @dragging

    moveX = pageX - startX

    column = @tableEditor.getScreenColumn(position)
    width = @tableEditor.getScreenColumnWidthAt(position)
    column.width = Math.max(@tableEditor.getMinimumScreenColumnWidth(), width + moveX)

    @getColumnResizeRuler().classList.remove('visible')
    @dragSubscription.dispose()
    @dragging = false

  scrollDuringDrag: (row, column) ->
    container = @getRowsScrollContainer()

    scrollTop = container.scrollTop
    rowOffset = @tableEditor.getScreenRowOffsetAt(row)
    rowHeight = @tableEditor.getScreenRowHeightAt(row)

    if row >= @getLastVisibleRow() - 1 and rowOffset + rowHeight >= scrollTop + @height - @height / 5
      container.scrollTop += atom.config.get('tablr.scrollSpeedDuringDrag')
    else if row <= @getFirstVisibleRow() + 1
      container.scrollTop -= atom.config.get('tablr.scrollSpeedDuringDrag')

    if column?
      scrollLeft = container.scrollLeft
      columnOffset = @tableEditor.getScreenColumnOffsetAt(row)
      columnWidth = @tableEditor.getScreenColumnWidthAt(row)

      if column >= @getLastVisibleColumn() - 1  and columnOffset + columnWidth >= scrollLeft + @width - @width / 5
        container.scrollLeft += atom.config.get('tablr.scrollSpeedDuringDrag')
      else if column <= @getFirstVisibleColumn() + 1
        container.scrollLeft -= atom.config.get('tablr.scrollSpeedDuringDrag')

  initializeDragEvents: (object, events) ->
    @dragSubscription = new CompositeDisposable
    for event,callback of events
      @dragSubscription.add @addDisposableEventListener object, event, callback

  #    ##     ## ########  ########     ###    ######## ########
  #    ##     ## ##     ## ##     ##   ## ##      ##    ##
  #    ##     ## ##     ## ##     ##  ##   ##     ##    ##
  #    ##     ## ########  ##     ## ##     ##    ##    ######
  #    ##     ## ##        ##     ## #########    ##    ##
  #    ##     ## ##        ##     ## ##     ##    ##    ##
  #     #######  ##        ########  ##     ##    ##    ########

  setScrollTop: (scroll) ->
    if scroll?
      @getRowsContainer().scrollTop = scroll
      @requestUpdate(false)

    @getRowsContainer().scrollTop

  setScrollLeft: (scroll) ->
    if scroll?
      @getRowsContainer().scrollLeft
      @requestUpdate(false)

    @getRowsContainer().scrollLeft

  requestUpdate: (@hasChanged=true) =>
    return if @destroyed or @updateRequested

    @updateRequested = true
    requestAnimationFrame =>
      @update()
      @updateRequested = false

  requestEllipsisCheck: ->
    requestAnimationFrame => cell.checkEllipsis() for key,cell of @cells

  markDirtyCell: (position) ->
    @dirtyPositions ?= []
    @dirtyPositions[position.row] ?= []
    @dirtyPositions[position.row][position.column] = true
    @dirtyColumns ?= []
    @dirtyColumns[position.column] = true

  markDirtyCells: (positions) ->
    @markDirtyCell(position) for position in positions

  markDirtyRange: (range) ->
    range.each (row, column) => @markDirtyCell({row, column})

  update: =>
    return unless @tableEditor?
    firstVisibleRow = @getFirstVisibleRow()
    lastVisibleRow = @getLastVisibleRow()
    firstVisibleColumn = @getFirstVisibleColumn()
    lastVisibleColumn = @getLastVisibleColumn()

    if firstVisibleRow >= @firstRenderedRow and
       lastVisibleRow <= @lastRenderedRow and
       firstVisibleColumn >= @firstRenderedColumn and
       lastVisibleColumn <= @lastRenderedColumn and
       not @hasChanged
      return

    maxCellCount = ((lastVisibleRow - firstVisibleRow) + @getRowOverdraw() * 2) * ((lastVisibleColumn - firstVisibleColumn) + @getColumnOverdraw() * 2)

    rowOverdraw = @getRowOverdraw()
    firstRow = Math.max 0, firstVisibleRow - rowOverdraw
    lastRow = Math.min @tableEditor.getScreenRowCount(), lastVisibleRow + rowOverdraw
    visibleRows = [firstRow...lastRow]
    oldVisibleRows = [@firstRenderedRow...@lastRenderedRow]

    columns = @tableEditor.getScreenColumns()
    columnOverdraw = @getColumnOverdraw()
    firstColumn = Math.max 0, firstVisibleColumn - columnOverdraw
    lastColumn = Math.min columns.length, lastVisibleColumn + columnOverdraw
    visibleColumns = [firstColumn...lastColumn]
    oldVisibleColumns = [@firstRenderedColumn...@lastRenderedColumn]

    intactFirstRow = @firstRenderedRow
    intactLastRow = @lastRenderedRow
    intactFirstColumn = @firstRenderedColumn
    intactLastColumn = @lastRenderedColumn

    @updateWidthAndHeight()
    @updateScroll()
    @updateSelections() if @wholeTableIsDirty

    endUpdate = =>
      @firstRenderedRow = firstRow
      @lastRenderedRow = lastRow
      @firstRenderedColumn = firstColumn
      @lastRenderedColumn = lastColumn
      @hasChanged = false
      @dirtyPositions = null
      @dirtyColumns = null
      @wholeTableIsDirty = false
      @requestEllipsisCheck()

    # We never rendered anything
    unless @firstRenderedRow?
      for column in visibleColumns
        @appendHeaderCell(columns[column], column)
        @appendCell(row, column) for row in visibleRows

      @appendGutterCell(row) for row in visibleRows

      return endUpdate()

    # Whole table redraw, when the table suddenly jump from one edge to the
    # other and the old and new visible range doesn't intersect.
    else if lastRow < @firstRenderedRow or firstRow >= @lastRenderedRow or lastColumn < @firstRenderedColumn or firstColumn >= @lastRenderedColumn

      @releaseCell(cell) for key,cell of @cells
      @releaseGutterCell(cell) for row,cell of @gutterCells
      @releaseHeaderCell(cell) for column,cell of @headerCells

      @cells = {}
      @headerCells = {}
      @gutterCells = {}

      for column in visibleColumns
        @appendHeaderCell(columns[column], column)
        @appendCell(row, column) for row in visibleRows

      @appendGutterCell(row) for row in visibleRows

      return endUpdate()

    # Classical scroll routine
    else if firstRow isnt @firstRenderedRow or lastRow isnt @lastRenderedRow or firstColumn isnt @firstRenderedColumn or lastColumn isnt @lastRenderedColumn
      disposed = 0
      created = 0

      if firstRow > @firstRenderedRow
        intactFirstRow = firstRow
        for row in [@firstRenderedRow...firstRow]
          @disposeGutterCell(row)
          @disposeCell(row, column) for column in oldVisibleColumns
      if lastRow < @lastRenderedRow
        intactLastRow = lastRow
        for row in [lastRow...@lastRenderedRow]
          @disposeGutterCell(row)
          @disposeCell(row, column) for column in oldVisibleColumns
      if firstColumn > @firstRenderedColumn
        intactFirstColumn = firstColumn
        for column in [@firstRenderedColumn...firstColumn]
          @disposeHeaderCell(column)
          @disposeCell(row, column) for row in oldVisibleRows
      if lastColumn < @lastRenderedColumn
        intactLastColumn = lastColumn
        for column in [lastColumn...@lastRenderedColumn]
          @disposeHeaderCell(column)
          @disposeCell(row, column) for row in oldVisibleRows

      if firstRow < @firstRenderedRow
        for row in [firstRow...@firstRenderedRow]
          @appendGutterCell(row)
          @appendCell(row, column) for column in visibleColumns
      if lastRow > @lastRenderedRow
        for row in [@lastRenderedRow...lastRow]
          @appendGutterCell(row)
          @appendCell(row, column) for column in visibleColumns
      if firstColumn < @firstRenderedColumn
        for column in [firstColumn...@firstRenderedColumn]
          @appendHeaderCell(columns[column], column)
          @appendCell(row, column) for row in visibleRows
      if lastColumn > @lastRenderedColumn
        for column in [@lastRenderedColumn...lastColumn]
          @appendHeaderCell(columns[column], column)
          @appendCell(row, column) for row in visibleRows

    if @dirtyPositions? or @wholeTableIsDirty
      for row in [intactFirstRow...intactLastRow]
        if @wholeTableIsDirty or @dirtyPositions[row]?
          @gutterCells[row]?.setModel({row})

        for column in [intactFirstColumn...intactLastColumn]
          if @wholeTableIsDirty or @dirtyPositions[row]?[column]
            @cells[row + '-' + column]?.setModel(@getCellObjectAtPosition([row, column]))

      for column in [intactFirstColumn...intactLastColumn]
        if @wholeTableIsDirty or @dirtyColumns[column]
          @headerCells[column]?.setModel({
            column: columns[column],
            index: column
          })

    endUpdate()

  updateWidthAndHeight: ->
    width = @tableEditor.getContentWidth()
    height = @tableEditor.getContentHeight()

    if @scrollPastEnd
      columnWidth = @tableEditor.getScreenColumnWidth()
      rowHeight = @tableEditor.getRowHeight()
      width += Math.max(columnWidth, @tableRows.offsetWidth - columnWidth)
      height += Math.max(rowHeight * 3, @tableRows.offsetHeight - rowHeight * 3)

    @tableCells.style.cssText = """
    height: #{height}px;
    width: #{width}px;
    """
    @tableGutter.style.cssText = """
    height: #{height}px;
    """
    @tableHeaderCells.style.cssText = """
    width: #{width}px;
    """

    @tableGutterFiller.textContent = @tableHeaderFiller.textContent = @tableEditor.getScreenRowCount()

  updateScroll: ->
    @getColumnsContainer().scrollLeft = @getColumnsScrollContainer().scrollLeft
    @getGutter().scrollTop = @getRowsContainer().scrollTop

  updateSelections: ->
    @tableEditor.getSelections().forEach (selection) ->
      atom.views.getView(selection).update()

  getScreenCellAtPosition: (position) ->
    position = Point.fromObject(position)
    @cells[position.row + '-' + position.column]

  appendCell: (row, column) ->
    key = row + '-' + column
    @cells[key] ? @cells[key] = @requestCell(@getCellObjectAtPosition([row, column]))

  getCellObjectAtPosition: (position) ->
    {row, column} = Point.fromObject(position)

    {
      cell:
        value: @tableEditor.getValueAtScreenPosition([row, column])
        column: @tableEditor.getScreenColumn(column)
      column
      row
    }

  disposeCell: (row, column) ->
    key = row + '-' + column
    cell = @cells[key]
    return unless cell?
    @releaseCell(cell)
    delete @cells[key]

  appendHeaderCell: (column, index) ->
    @headerCells[index] ? @headerCells[index] = @requestHeaderCell({column, index})

  disposeHeaderCell: (column) ->
    return unless cell = @headerCells[column]
    @releaseHeaderCell(cell)
    delete @headerCells[column]

  appendGutterCell: (row) ->
    @gutterCells[row] ? @gutterCells[row] = @requestGutterCell({row})

  disposeGutterCell: (row) ->
    return unless cell = @gutterCells[row]
    @releaseGutterCell(cell)
    delete @gutterCells[row]

  floatToPercent: (w) -> @toUnit(Math.round(w * 10000) / 100, '%')

  floatToPixel: (w) -> @toUnit(w)

  toUnit: (value, unit=PIXEL) -> "#{value}#{unit}"

#    ######## ##       ######## ##     ## ######## ##    ## ########
#    ##       ##       ##       ###   ### ##       ###   ##    ##
#    ##       ##       ##       #### #### ##       ####  ##    ##
#    ######   ##       ######   ## ### ## ######   ## ## ##    ##
#    ##       ##       ##       ##     ## ##       ##  ####    ##
#    ##       ##       ##       ##     ## ##       ##   ###    ##
#    ######## ######## ######## ##     ## ######## ##    ##    ##

module.exports = TableElement = document.registerElement 'atom-table-editor', prototype: TableElement.prototype

TableElement.registerViewProvider = ->
  atom.views.addViewProvider TableEditor, (model) ->
    element = new TableElement
    element.setModel(model)
    element


#     ######  ##     ## ########
#    ##    ## ###   ### ##     ##
#    ##       #### #### ##     ##
#    ##       ## ### ## ##     ##
#    ##       ##     ## ##     ##
#    ##    ## ##     ## ##     ##
#     ######  ##     ## ########

preventAndStop = (f) -> (e) ->
  f.call(this, e)
  e.stopPropagation()
  e.preventDefault()

stopEventPropagation = (commandListeners) ->
  newCommandListeners = {}
  for commandName, commandListener of commandListeners
    do (commandListener) ->
      newCommandListeners[commandName] = (event) ->
        event.stopPropagation()
        commandListener.call(@getModel(), event)
  newCommandListeners

stopEventPropagationAndGroupUndo = (commandListeners) ->
  newCommandListeners = {}
  for commandName, commandListener of commandListeners
    do (commandListener) ->
      newCommandListeners[commandName] = (event) ->
        event.stopPropagation()
        model = @getModel()
        model.transact atom.config.get('editor.undoGroupingInterval'), ->
          commandListener.call(model, event)
  newCommandListeners

TableElement.registerCommands = ->
  atom.commands.add 'atom-table-editor',
    'core:save': preventAndStop (e) -> @save()
    'core:confirm': -> @startCellEdit()
    'core:cancel': -> @resetSelections()
    'core:copy': -> @copySelectedCells()
    'core:cut': -> @cutSelectedCells()
    'core:paste': -> @pasteClipboard()
    'core:undo': -> @tableEditor.undo()
    'core:redo': -> @tableEditor.redo()
    'core:backspace': -> @delete()
    'core:move-left': -> @moveLeft()
    'core:move-right': -> @moveRight()
    'core:move-up': -> @moveUp()
    'core:move-down': -> @moveDown()
    'core:move-to-top': -> @moveToTop()
    'core:move-to-bottom': -> @moveToBottom()
    'tablr:move-to-end-of-line': -> @moveToRight()
    'tablr:move-to-beginning-of-line': -> @moveToLeft()
    'core:page-up': -> @pageUp()
    'core:page-down': -> @pageDown()
    'tablr:page-left': -> @pageLeft()
    'tablr:page-right': -> @pageRight()
    'core:select-right': -> @expandSelectionRight()
    'core:select-left': -> @expandSelectionLeft()
    'core:select-up': -> @expandSelectionUp()
    'core:select-down': -> @expandSelectionDown()
    'tablr:move-left-in-selection': -> @moveLeftInSelection()
    'tablr:move-right-in-selection': -> @moveRightInSelection()
    'tablr:move-up-in-selection': -> @moveUpInSelection()
    'tablr:move-down-in-selection': -> @moveDownInSelection()
    'tablr:select-to-end-of-line': -> @expandSelectionToEndOfLine()
    'tablr:select-to-beginning-of-line': -> @expandSelectionToBeginningOfLine()
    'tablr:select-to-end-of-table': -> @expandSelectionToEndOfTable()
    'tablr:select-to-beginning-of-table': -> @expandSelectionToBeginningOfTable()
    'tablr:insert-row-before': -> @insertRowBefore()
    'tablr:insert-row-after': -> @insertRowAfter()
    'tablr:delete-row': -> @deleteRowAtCursor()
    'tablr:insert-column-before': -> @insertColumnBefore()
    'tablr:insert-column-after': -> @insertColumnAfter()
    'tablr:delete-column': -> @deleteColumnAtCursor()
    'tablr:align-left': -> @alignLeft()
    'tablr:align-center': -> @alignCenter()
    'tablr:align-right': -> @alignRight()
    'tablr:add-selection-below': -> @addCursorBelowLastSelection()
    'tablr:add-selection-above': -> @addCursorAboveLastSelection()
    'tablr:add-selection-left': -> @addCursorLeftToLastSelection()
    'tablr:add-selection-right': -> @addCursorRightToLastSelection()
    'tablr:expand-column': -> @expandColumn()
    'tablr:shrink-column': -> @shrinkColumn()
    'tablr:expand-row': -> @expandRow()
    'tablr:shrink-row': -> @shrinkRow()
    'tablr:go-to-line': -> @openGoToLineModal()

  atom.commands.add 'atom-table-editor atom-text-editor[mini]', stopEventPropagation(
    'core:move-up': -> @moveUp()
    'core:move-down': -> @moveDown()
    'core:move-to-top': -> @moveToTop()
    'core:move-to-bottom': -> @moveToBottom()
    'core:page-up': -> @pageUp()
    'core:page-down': -> @pageDown()
    'core:select-to-top': -> @selectToTop()
    'core:select-to-bottom': -> @selectToBottom()
    'core:select-page-up': -> @selectPageUp()
    'core:select-page-down': -> @selectPageDown()
    'editor:add-selection-below': -> @addSelectionBelow()
    'editor:add-selection-above': -> @addSelectionAbove()
    'editor:split-selections-into-lines': -> @splitSelectionsIntoLines()
    'editor:toggle-soft-tabs': -> @toggleSoftTabs()
    'editor:toggle-soft-wrap': -> @toggleSoftWrapped()
    'editor:fold-all': -> @foldAll()
    'editor:unfold-all': -> @unfoldAll()
    'editor:fold-current-row': -> @foldCurrentRow()
    'editor:unfold-current-row': -> @unfoldCurrentRow()
    'editor:fold-selection': -> @foldSelectedLines()
    'editor:fold-at-indent-level-1': -> @foldAllAtIndentLevel(0)
    'editor:fold-at-indent-level-2': -> @foldAllAtIndentLevel(1)
    'editor:fold-at-indent-level-3': -> @foldAllAtIndentLevel(2)
    'editor:fold-at-indent-level-4': -> @foldAllAtIndentLevel(3)
    'editor:fold-at-indent-level-5': -> @foldAllAtIndentLevel(4)
    'editor:fold-at-indent-level-6': -> @foldAllAtIndentLevel(5)
    'editor:fold-at-indent-level-7': -> @foldAllAtIndentLevel(6)
    'editor:fold-at-indent-level-8': -> @foldAllAtIndentLevel(7)
    'editor:fold-at-indent-level-9': -> @foldAllAtIndentLevel(8)
    'editor:log-cursor-scope': -> @logCursorScope()
    'editor:copy-path': -> @copyPathToClipboard()
    'editor:toggle-indent-guide': -> atom.config.set('editor.showIndentGuide', not atom.config.get('editor.showIndentGuide'))
    'editor:toggle-line-numbers': -> atom.config.set('editor.showLineNumbers', not atom.config.get('editor.showLineNumbers'))
    'editor:scroll-to-cursor': -> @scrollToCursorPosition()
  )

  atom.commands.add 'atom-table-editor atom-text-editor[mini]', stopEventPropagationAndGroupUndo(
    'editor:indent': -> @indent()
    'editor:auto-indent': -> @autoIndentSelectedRows()
    'editor:indent-selected-rows': -> @indentSelectedRows()
    'editor:outdent-selected-rows': -> @outdentSelectedRows()
    'editor:newline': -> @insertNewline()
    'editor:newline-below': -> @insertNewlineBelow()
    'editor:newline-above': -> @insertNewlineAbove()
    'editor:toggle-line-comments': -> @toggleLineCommentsInSelection()
    'editor:checkout-head-revision': -> @checkoutHeadRevision()
    'editor:move-line-up': -> @moveLineUp()
    'editor:move-line-down': -> @moveLineDown()
    'editor:duplicate-lines': -> @duplicateLines()
    'editor:join-lines': -> @joinLines()
  )

TableElement.registerCommands()
