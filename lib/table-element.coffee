Delegator = require 'delegato'
{Point, TextEditor} = require 'atom'
{CompositeDisposable, Disposable} = require 'event-kit'
{EventsDelegation, SpacePenDSL} = require 'atom-utils'
PropertyAccessors = require 'property-accessors'

Table = require './table'
TableEditor = require './table-editor'
TableCellElement = require './table-cell-element'
TableHeaderCellElement = require './table-header-cell-element'
TableGutterCellElement = require './table-gutter-cell-element'
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
    @div class: 'table-edit-header', outlet: 'head', =>
      @div class: 'table-edit-header-content', =>
        @div class: 'table-edit-header-filler', outlet: 'tableHeaderFiller'
        @div class: 'table-edit-header-row', outlet: 'tableHeaderRow', =>
          @div class: 'table-edit-header-wrapper', outlet: 'tableHeaderCells'
        @div class: 'column-resize-ruler', outlet: 'columnRuler'

    @div class: 'table-edit-body', outlet: 'body', =>
      @div class: 'table-edit-content', =>
        @div class: 'table-edit-rows', outlet: 'tableRows', =>
          @div class: 'table-edit-rows-wrapper', outlet: 'tableCells', =>
            @div class: 'selection-box', outlet: 'tableSelectionBox'
            @div class: 'selection-box-handle', outlet: 'tableSelectionBoxHandle'

        @div class: 'table-edit-gutter', =>
          @div class: 'table-edit-gutter-wrapper', outlet: 'tableGutter', =>
            @div class: 'table-edit-gutter-filler', outlet: 'tableGutterFiller'

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
        columnIndex = @getScreenColumnIndexAtPixelPosition(e.pageX, e.pageY)
        if column = @tableEditor.getScreenColumn(columnIndex)
          if column.name is @tableEditor.order
            if @tableEditor.direction is -1
              @tableEditor.resetSort()
            else
              @tableEditor.toggleSortDirection()
          else
            @tableEditor.sortBy(column.name)

    @subscriptions.add @subscribeTo @getRowsContainer(),
      'scroll': (e) => @requestUpdate()

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

        if position = @cellPositionAtScreenPosition(e.pageX, e.pageY)
          @tableEditor.setCursorAtScreenPosition position

        @startDrag(e)
        @focus()
      'click': stopPropagationAndDefault()

    @subscriptions.add @subscribeTo @body, '.table-edit-gutter',
      'mousedown': stopPropagationAndDefault (e) => @startGutterDrag(e)
      'click': stopPropagationAndDefault()

    @subscriptions.add @subscribeTo @body, '.table-edit-gutter .row-resize-handle',
      'mousedown': stopPropagationAndDefault (e) => @startRowResizeDrag(e)
      'click': stopPropagationAndDefault()

    @subscriptions.add @subscribeTo @body, '.selection-box-handle',
      'mousedown': stopPropagationAndDefault (e) => @startDrag(e)
      'click': stopPropagationAndDefault()

  subscribeToConfig: ->
    @observeConfig
      'table-edit.undefinedDisplay': (@configUndefinedDisplay) =>
        @requestUpdate() if @attached
      'table-edit.pageMovesAmount': (@configPageMovesAmount) =>
        @requestUpdate() if @attached
      'table-edit.rowOverdraw': (@configRowOverdraw) =>
        @requestUpdate() if @attached
      'table-edit.columnOverdraw': (@configColumnOverdraw) =>
        @requestUpdate() if @attached
      'table-edit.scrollPastEnd': (@scrollPastEnd) =>
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

  getGutter: -> @shadowRoot.querySelector('.table-edit-gutter')

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

  afterCursorMove: ->
    @makeCellVisible(@tableEditor.getLastCursor().getPosition())

  getPageMovesAmount: -> @pageMovesAmount ? @configPageMovesAmount

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
    @editorElement.style.width = @toUnit(activeCellRect.width)
    @editorElement.style.height = @toUnit(activeCellRect.height)
    @editorElement.style.display = 'block'

    @editorElement.dataset.column = @tableEditor.getScreenColumn(position.column).name
    @editorElement.dataset.row = position.row + 1

    @editorElement.focus()

    @editor.setText(String(cursor.getValue() ? @getUndefinedDisplay()))

    @editor.getBuffer().history.clearUndoStack()
    @editor.getBuffer().history.clearRedoStack()

    @editor.setText(initialData) if initialData?

  confirmCellEdit: ->
    @stopEdit()
    cursor = @tableEditor.getLastCursor()
    position = cursor.getPosition()

    newValue = @editor.getText()
    unless newValue is cursor.getValue()
      @tableEditor.setValueAtScreenPosition(position, newValue)

  startColumnEdit: ({target, pageX, pageY}) =>
    return if @readOnly

    @createTextEditor() unless @editor?

    @subscribeToColumnTextEditor(@editor)

    @editing = true

    columnIndex = @getScreenColumnIndexAtPixelPosition(pageX, pageY)
    if @columnUnderEdit = @tableEditor.getScreenColumn(columnIndex)
      columnRect = target.parentNode.getBoundingClientRect()

      @editorElement.style.top = @toUnit(columnRect.top)
      @editorElement.style.left =  @toUnit(columnRect.left)
      @editorElement.style.width = @toUnit(columnRect.width)
      @editorElement.style.height = @toUnit(columnRect.height)
      @editorElement.style.display = 'block'

      @editorElement.focus()
      @editor.setText(@columnUnderEdit.name)

      @editor.getBuffer().history.clearUndoStack()
      @editor.getBuffer().history.clearRedoStack()

  confirmColumnEdit: ->
    @stopEdit()
    newValue = @editor.getText()
    @columnUnderEdit.name = newValue unless newValue is @columnUnderEdit.name
    delete @columnUnderEdit

  stopEdit: ->
    @editing = false
    @editorElement.style.display = 'none'
    @textEditorSubscriptions?.dispose()
    @textEditorSubscriptions = null
    @focus()

  createTextEditor: ->
    @editor = new TextEditor({})
    @editorElement = atom.views.getView(@editor)
    @appendChild(@editorElement)

  subscribeToCellTextEditor: (editor) ->
    @textEditorSubscriptions = new CompositeDisposable
    @textEditorSubscriptions.add atom.commands.add 'atom-table-editor atom-text-editor:not([mini])',

      'table-edit:move-right': (e) =>
        @confirmCellEdit()
        @moveRight()
      'table-edit:move-left': (e) =>
        @confirmCellEdit()
        @moveLeft()
      'core:cancel': (e) =>
        @stopEdit()
        e.stopImmediatePropagation()
        return false
      'core:confirm': (e) =>
        @confirmCellEdit()
        e.stopImmediatePropagation()
        return false

    @textEditorSubscriptions.add @subscribeTo @editorElement,
      'click': (e) =>
        e.stopPropagation()
        e.stopImmediatePropagation()
        e.preventDefault()
        @editorElement.focus()

  subscribeToColumnTextEditor: (editorView) ->
    @textEditorSubscriptions = new CompositeDisposable
    @textEditorSubscriptions.add atom.commands.add 'atom-table-editor atom-text-editor:not([mini])',

      'table-edit:move-right': (e) =>
        @confirmColumnEdit()
        @moveRight()
      'table-edit:move-left': (e) =>
        @confirmColumnEdit()
        @moveLeft()
      'core:cancel': (e) =>
        @stopEdit()
        e.stopImmediatePropagation()
        return false
      'core:confirm': (e) =>
        @confirmColumnEdit()
        e.stopImmediatePropagation()
        return false

  #     ######  ######## ##       ########  ######  ########
  #    ##    ## ##       ##       ##       ##    ##    ##
  #    ##       ##       ##       ##       ##          ##
  #     ######  ######   ##       ######   ##          ##
  #          ## ##       ##       ##       ##          ##
  #    ##    ## ##       ##       ##       ##    ##    ##
  #     ######  ######## ######## ########  ######     ##

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

  startDragScrollInterval: (method, e, o) ->
    @dragScrollInterval = setInterval (=> method.call(this, e, o)), 50

  clearDragScrollInterval: ->
    clearInterval(@dragScrollInterval)

  startDrag: (e) ->
    return if @dragging

    @dragging = true

    @initializeDragEvents @body,
      'mousemove': stopPropagationAndDefault (e) => @drag(e)
      'mouseup': stopPropagationAndDefault (e) => @endDrag(e)

  drag: (e) ->
    if @dragging
      @clearDragScrollInterval()
      {pageX, pageY} = e
      {row, column} = @cellPositionAtScreenPosition pageX, pageY
      cursorPosition = @tableEditor.getLastCursor().getPosition()
      selection = @tableEditor.getLastSelection()
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

      @startDragScrollInterval(@drag, e)

  endDrag: (e) ->
    return unless @dragging

    @drag(e)
    @clearDragScrollInterval()
    @dragging = false
    @dragSubscription.dispose()

  startGutterDrag: (e) ->
    return if @dragging

    row = @getScreenRowIndexAtPixelPosition(e.pageY)
    return unless row?

    @dragging = true
    @tableEditor.setSelectedRow(row)

    @initializeDragEvents @body,
      'mousemove': stopPropagationAndDefault (e) =>
        @gutterDrag(e, startRow: row)
      'mouseup': stopPropagationAndDefault (e) =>
        @endGutterDrag(e, startRow: row)

  gutterDrag: (e, o) ->
    {pageY} = e
    {startRow} = o
    if @dragging
      @clearDragScrollInterval()
      row = @getScreenRowIndexAtPixelPosition(pageY)

      if row > startRow
        @tableEditor.setSelectedRowRange([startRow, row])
      else if row < startRow
        @tableEditor.setSelectedRowRange([row, startRow])
      else
        @tableEditor.setSelectedRow(row)

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
      container.scrollTop += atom.config.get('table-edit.scrollSpeedDuringDrag')
    else if row <= @getFirstVisibleRow() + 1
      container.scrollTop -= atom.config.get('table-edit.scrollSpeedDuringDrag')

    if column?
      scrollLeft = container.scrollLeft
      columnOffset = @tableEditor.getScreenColumnOffsetAt(row)
      columnWidth = @tableEditor.getScreenColumnWidthAt(row)

      if column >= @getLastVisibleColumn() - 1  and columnOffset + columnWidth >= scrollLeft + @width - @width / 5
        container.scrollLeft += atom.config.get('table-edit.scrollSpeedDuringDrag')
      else if column <= @getFirstVisibleColumn() + 1
        container.scrollLeft -= atom.config.get('table-edit.scrollSpeedDuringDrag')

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
    @updateSelection()

    endUpdate = =>
      @firstRenderedRow = firstRow
      @lastRenderedRow = lastRow
      @firstRenderedColumn = firstColumn
      @lastRenderedColumn = lastColumn
      @hasChanged = false
      @dirtyPositions = null
      @dirtyColumns = null
      @wholeTableIsDirty = false

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

  updateSelection: ->
    if @tableEditor.getLastSelection().spanMoreThanOneCell()
      {top, left, right, bottom} = @selectionScrollRect()
      height = bottom - top
      width = right - left
      @tableSelectionBox.style.cssText = """
      top: #{top}px;
      left: #{left}px;
      height: #{height}px;
      width: #{width}px;
      """
      @tableSelectionBoxHandle.style.cssText = """
      top: #{top + height}px;
      left: #{left + width}px;
      """
    else
      @tableSelectionBox.style.cssText = "display: none"
      @tableSelectionBoxHandle.style.cssText = "display: none"

  selectionScrollRect: ->
    range = @tableEditor.getLastSelection().getRange()

    left: @tableEditor.getScreenColumnOffsetAt(range.start.column)
    top: @tableEditor.getScreenRowOffsetAt(range.start.row)
    right: @tableEditor.getScreenColumnOffsetAt(range.end.column - 1) + @tableEditor.getScreenColumnWidthAt(range.end.column - 1)
    bottom: @tableEditor.getScreenRowOffsetAt(range.end.row - 1) + @tableEditor.getScreenRowHeightAt(range.end.row - 1)

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

#     ######  ##     ## ########
#    ##    ## ###   ### ##     ##
#    ##       #### #### ##     ##
#    ##       ## ### ## ##     ##
#    ##       ##     ## ##     ##
#    ##    ## ##     ## ##     ##
#     ######  ##     ## ########

preventAndStop = (f) -> (e) ->
  f.call(this, e)
  e.stopImmediatePropagation()
  e.preventDefault()

atom.commands.add 'atom-table-editor',
  'core:save': preventAndStop (e) -> @save()
  'core:confirm': -> @startCellEdit()
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
  'table-edit:move-to-end-of-line': -> @moveToRight()
  'table-edit:move-to-beginning-of-line': -> @moveToLeft()
  'core:page-up': -> @pageUp()
  'core:page-down': -> @pageDown()
  'core:page-left': -> @pageLeft()
  'core:page-right': -> @pageRight()
  'core:select-right': -> @expandSelectionRight()
  'core:select-left': -> @expandSelectionLeft()
  'core:select-up': -> @expandSelectionUp()
  'core:select-down': -> @expandSelectionDown()
  'table-edit:move-left-in-selection': -> @moveLeftInSelection()
  'table-edit:move-right-in-selection': -> @moveRightInSelection()
  'table-edit:move-up-in-selection': -> @moveUpInSelection()
  'table-edit:move-down-in-selection': -> @moveDownInSelection()
  'table-edit:select-to-end-of-line': -> @expandSelectionToEndOfLine()
  'table-edit:select-to-beginning-of-line': -> @expandSelectionToBeginningOfLine()
  'table-edit:select-to-end-of-table': -> @expandSelectionToEndOfTable()
  'table-edit:select-to-beginning-of-table': -> @expandSelectionToBeginningOfTable()
  'table-edit:insert-row-before': -> @insertRowBefore()
  'table-edit:insert-row-after': -> @insertRowAfter()
  'table-edit:delete-row': -> @deleteRowAtCursor()
  'table-edit:insert-column-before': -> @insertColumnBefore()
  'table-edit:insert-column-after': -> @insertColumnAfter()
  'table-edit:delete-column': -> @deleteColumnAtCursor()

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
