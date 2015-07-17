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
    @cells = []
    @headerCells = []
    @gutterCells = []

    @subscriptions = new CompositeDisposable

    @subscribeToContent()
    @subscribeToConfig()

    @initCellsPool(TableCellElement, @tableCells)
    @initHeaderCellsPool(TableHeaderCellElement, @tableHeaderCells)
    @initGutterCellsPool(TableGutterCellElement, @tableGutter)

  subscribeToContent: ->
    @subscriptions.add @subscribeTo @hiddenInput,
      'textInput': (e) =>
        unless @isEditing()
          @startCellEdit()
          @editor.setText(e.data)

    @subscriptions.add atom.commands.add 'atom-table-editor',
      'core:confirm': => @startCellEdit()
      'core:undo': => @tableEditor.undo()
      'core:redo': => @tableEditor.redo()
      'core:move-left': => @moveLeft()
      'core:move-right': => @moveRight()
      'core:move-up': => @moveUp()
      'core:move-down': => @moveDown()
      'core:move-to-top': => @moveToTop()
      'core:move-to-bottom': => @moveToBottom()
      'table-edit:move-to-end-of-line': => @moveToRight()
      'table-edit:move-to-beginning-of-line': => @moveToLeft()
      'core:page-up': => @pageUp()
      'core:page-down': => @pageDown()
      'core:page-left': => @pageLeft()
      'core:page-right': => @pageRight()
      'core:select-right': => @expandSelectionRight()
      'core:select-left': => @expandSelectionLeft()
      'core:select-up': => @expandSelectionUp()
      'core:select-down': => @expandSelectionDown()
      'table-edit:select-to-end-of-line': => @expandSelectionToEndOfLine()
      'table-edit:select-to-beginning-of-line': => @expandSelectionToBeginningOfLine()
      'table-edit:select-to-end-of-table': => @expandSelectionToEndOfTable()
      'table-edit:select-to-beginning-of-table': => @expandSelectionToBeginningOfTable()
      'table-edit:insert-row-before': => @insertRowBefore()
      'table-edit:insert-row-after': => @insertRowAfter()
      'table-edit:delete-row': => @deleteCursorRow()
      'table-edit:insert-column-before': => @insertColumnBefore()
      'table-edit:insert-column-after': => @insertColumnAfter()
      'table-edit:delete-column': => @deleteCursorColumn()

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
    @subscriptions.dispose()
    @remove()

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
    return unless table?

    @unsetModel() if @tableEditor?

    @tableEditor = table
    @modelSubscriptions = subs = new CompositeDisposable()
    subs.add @tableEditor.onDidAddColumn (e) => @requestUpdate()
    subs.add @tableEditor.onDidRemoveColumn (e) => @requestUpdate()
    subs.add @tableEditor.onDidRemoveColumn => @requestUpdate()
    subs.add @tableEditor.onDidChangeColumnOption => @requestUpdate()
    subs.add @tableEditor.onDidChangeScreenRows => @requestUpdate()
    subs.add @tableEditor.onDidChangeRowHeight => @requestUpdate()
    subs.add @tableEditor.onDidChangeCellValue => @requestUpdate()
    subs.add @tableEditor.onDidAddCursor => @requestUpdate()
    subs.add @tableEditor.onDidRemoveCursor => @requestUpdate()
    subs.add @tableEditor.onDidChangeCursorPosition => @requestUpdate()
    subs.add @tableEditor.onDidAddSelection => @requestUpdate()
    subs.add @tableEditor.onDidRemoveSelection => @requestUpdate()
    subs.add @tableEditor.onDidChangeSelectionRange => @requestUpdate()

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
      selection.getRowRange().containsRow(row)

  getRowRange: (row) ->
    Range.fromObject([[row, 0], [row, @tableEditor.getLastColumnIndex()]])

  getRowsContainer: -> @tableRows

  getRowsOffsetContainer: -> @getRowsWrapper()

  getRowsScrollContainer: -> @getRowsContainer()

  getRowsWrapper: -> @tableCells

  getRowResizeRuler: -> @rowRuler

  insertRowBefore: ->
    @tableEditor.addRowAt(@tableEditor.screenRowToModelRow(@tableEditor.getCursorPosition().row))

  insertRowAfter: ->
    @tableEditor.addRowAt(@tableEditor.screenRowToModelRow(@tableEditor.getCursorPosition().row + 1))

  deleteCursorRow: ->
    @tableEditor.removeScreenRowAt(@tableEditor.screenRowToModelRow(@tableEditor.getCursorPosition().row))

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
    rowHeight = @tableEditor.getScreenRowHeightAt(row)

    scrollViewHeight = container.offsetHeight
    currentScrollTop = container.scrollTop

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

  getNewColumnName: -> @newColumnId ?= 0; "untitled_#{@newColumnId++}"

  insertColumnBefore: ->
    @tableEditor.addColumnAt(@tableEditor.getCursorPosition().column, @getNewColumnName())

  insertColumnAfter: ->
    @tableEditor.addColumnAt(@tableEditor.getCursorPosition().column + 1, @getNewColumnName())

  deleteCursorColumn: ->
    @tableEditor.removeColumnAt(@tableEditor.getCursorPosition().column)

  getFirstVisibleColumn: ->
    @getScreenColumnIndexAtPixelPosition(@getColumnsScrollContainer().scrollLeft)

  getLastVisibleColumn: ->
    scrollViewWidth = @getColumnsScrollContainer().clientWidth

    @getScreenColumnIndexAtPixelPosition(@getColumnsScrollContainer().scrollLeft + scrollViewWidth)

  getColumnOverdraw: -> @columnOverdraw ? @configColumnOverdraw

  setColumnOverdraw: (@columnOverdraw) -> @requestUpdate()

  isCursorColumn: (column) ->
    @tableEditor.getCursors().some (cursor) ->
      cursor.getPosition().column is column

  isSelectedColumn: (column) ->
    @tableEditor.getSelections().some (selection) ->
      selection.getRowRange().containsColumn(column)

  getScreenColumnIndexAtPixelPosition: (x) ->
    x -= @getColumnsOffsetContainer().getBoundingClientRect().left

    @tableEditor.getScreenColumnIndexAtPixelPosition(x)

  columnScreenPosition: (column) ->
    left = @tableEditor.getScreenColumnOffsetAt(column)

    content = @getColumnsScrollContainer()
    contentOffset = content.getBoundingClientRect()

    left + contentOffset.left

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

  cellScreenPosition: (position) ->
    {top, left} = @tableEditor.getScreenCellPosition(position)

    {
      top: top + @getRowsOffsetContainer().getBoundingClientRect().top,
      left: left + @getColumnsOffsetContainer().getBoundingClientRect().left
    }

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

  startCellEdit: =>
    @createTextEditor() unless @editor?

    @subscribeToCellTextEditor(@editor)

    @editing = true

    cursor = @tableEditor.getLastCursor()
    position = cursor.getPosition()
    activeCellRect = @cellScreenRect(position)

    @editorElement.style.top = @toUnit(activeCellRect.top)
    @editorElement.style.left = @toUnit(activeCellRect.left)
    @editorElement.style.width = @toUnit(activeCellRect.width)
    @editorElement.style.height = @toUnit(activeCellRect.height)
    @editorElement.style.display = 'block'

    @editorElement.dataset.column = @tableEditor.getScreenColumn(position.column).name
    @editorElement.dataset.row = position.row + 1

    @editorElement.focus()

    @editor.setText(String(cursor.getValue() ? @getUndefinedDisplay()))

    @editor.getBuffer().history.clearUndoStack()
    @editor.getBuffer().history.clearRedoStack()

  confirmCellEdit: ->
    @stopEdit()
    cursor = @tableEditor.getLastCursor()
    position = cursor.getPosition()

    newValue = @editor.getText()
    unless newValue is cursor.getValue()
      @tableEditor.setValueAtScreenPosition(position, newValue)

  startColumnEdit: ({target, pageX, pageY}) =>
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

  isSelectedPosition: (position) ->
    position = Point.fromObject(position)

    position.row >= @selection.start.row and
    position.row <= @selection.end.row and
    position.column >= @selection.start.column and
    position.column <= @selection.end.column

  getSelection: -> @selection

  selectionScrollRect: ->
    {top, left} = @cellScrollPosition(@selection.start)
    width = 0
    height = 0

    for col in [@selection.start.column..@selection.end.column]
      width += @getScreenColumnWidthAt(col)

    for row in [@selection.start.row..@selection.end.row]
      height += @getScreenRowHeightAt(row)

    {top, left, width, height}

  setSelection: (selection) ->
    @selection = Range.fromObject(selection)
    @activeCellPosition = @selection.start.copy()
    @requestUpdate()

  setSelectionFromActiveCell: ->
    @selection = Range.fromObject([
      [@activeCellPosition.row, @activeCellPosition.column]
      [@activeCellPosition.row, @activeCellPosition.column]
    ])

  expandSelectionRight: ->
    if @selectionExpandedLeft()
      @selection.start.column = Math.min(@selection.start.column + 1, @getLastColumn())
    else
      @selection.end.column = Math.min(@selection.end.column + 1, @getLastColumn())

    @requestUpdate()

  expandSelectionLeft: ->
    if @selectionExpandedRight()
      @selection.end.column = Math.max(@selection.end.column - 1, 0)
    else
      @selection.start.column = Math.max(@selection.start.column - 1, 0)

    @requestUpdate()

  expandSelectionUp: ->
    row = if @selectionExpandedDown()
      @selection.end.row = Math.max(@selection.end.row - 1, 0)
    else
      @selection.start.row = Math.max(@selection.start.row - 1, 0)

    @makeRowVisible(row)
    @requestUpdate()

  expandSelectionDown: ->
    row = if @selectionExpandedUp()
      @selection.start.row = Math.min(@selection.start.row + 1, @getLastRow())
    else
      @selection.end.row = Math.min(@selection.end.row + 1, @getLastRow())

    @makeRowVisible(row)
    @requestUpdate()

  expandSelectionToEndOfLine: ->
    @selection.start.column = @activeCellPosition.column
    @selection.end.column = @getLastColumn()
    @requestUpdate()

  expandSelectionToBeginningOfLine: ->
    @selection.start.column = 0
    @selection.end.column = @activeCellPosition.column
    @requestUpdate()

  expandSelectionToEndOfTable: ->
    @selection.start.row = @activeCellPosition.row
    @selection.end.row = @getLastRow()

    @makeRowVisible(@selection.end.row)
    @requestUpdate()

  expandSelectionToBeginningOfTable: ->
    @selection.start.row = 0
    @selection.end.row = @activeCellPosition.row

    @makeRowVisible(@selection.start.row)
    @requestUpdate()

  selectionExpandedRight: ->
    @activeCellPosition.column is @selection.start.column and
    @activeCellPosition.column isnt @selection.end.column

  selectionExpandedLeft: ->
    @activeCellPosition.column is @selection.end.column and
    @activeCellPosition.column isnt @selection.start.column

  selectionExpandedUp: ->
    @activeCellPosition.row is @selection.end.row and
    @activeCellPosition.row isnt @selection.start.row

  selectionExpandedDown: ->
    @activeCellPosition.row is @selection.start.row and
    @activeCellPosition.row isnt @selection.end.row

  selectionSpansManyCells: ->
    @selectionSpansManyColumns() or @selectionSpansManyRows()

  selectionSpansManyColumns: ->
    @selection.start.column isnt @selection.end.column

  selectionSpansManyRows: ->
    @selection.start.row isnt @selection.end.row

  #    ########    ####    ########
  #    ##     ##  ##  ##   ##     ##
  #    ##     ##   ####    ##     ##
  #    ##     ##  ####     ##     ##
  #    ##     ## ##  ## ## ##     ##
  #    ##     ## ##   ##   ##     ##
  #    ########   ####  ## ########

  startDrag: (e) ->
    return if @dragging

    @dragging = true

    @initializeDragEvents @body,
      'mousemove': stopPropagationAndDefault (e) => @drag(e)
      'mouseup': stopPropagationAndDefault (e) => @endDrag(e)

  drag: (e) ->
    if @dragging
      {pageX, pageY} = e
      {row, column} = @cellPositionAtScreenPosition pageX, pageY

      if row < @activeCellPosition.row
        @selection.start.row = row
        @selection.end.row = @activeCellPosition.row
      else if row > @activeCellPosition.row
        @selection.end.row = row
        @selection.start.row = @activeCellPosition.row
      else
        @selection.end.row = @activeCellPosition.row
        @selection.start.row = @activeCellPosition.row

      if column < @activeCellPosition.column
        @selection.start.column = column
        @selection.end.column = @activeCellPosition.column
      else if column > @activeCellPosition.column
        @selection.end.column = column
        @selection.start.column = @activeCellPosition.column
      else
        @selection.end.column = @activeCellPosition.column
        @selection.start.column = @activeCellPosition.column

      @scrollDuringDrag(row)
      @requestUpdate()

  endDrag: (e) ->
    return unless @dragging

    @drag(e)
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

  gutterDrag: ({pageY}, {startRow}) ->
    if @dragging
      console.log 'here'
      row = @getScreenRowIndexAtPixelPosition(pageY)

      if row > startRow
        @tableEditor.setSelectedRowRange([startRow, row])
      else if row < startRow
        @tableEditor.setSelectedRowRange([row, startRow])
      else
        @tableEditor.setSelectedRow(row)

      @scrollDuringDrag(row)
      @requestUpdate()

  endGutterDrag: (e,o) ->
    return unless @dragging

    @dragSubscription.dispose()
    @gutterDrag(e,o)
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
      rulerTop = Math.max(@tableEditor.getMinimumRowHeight(), pageY - @body.getBoundingClientRect().top + dragOffset + handleHeight - ruler.offsetHeight)
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

  columnResizeDrag: ({pageX}) ->
    ruler = @getColumnResizeRuler()
    ruler.style.left = @toUnit(pageX - @head.getBoundingClientRect().left)

  endColumnResizeDrag: ({pageX}, {startX, position}) ->
    return unless @dragging

    moveX = pageX - startX

    column = @tableEditor.getScreenColumn(position)
    width = @tableEditor.getScreenColumnWidthAt(position)
    column.width = width + moveX

    @getColumnResizeRuler().classList.remove('visible')
    @dragSubscription.dispose()
    @dragging = false

  scrollDuringDrag: (row) ->
    if row >= @getLastVisibleRow() - 1
      @makeRowVisible(row + 1)
    else if row <= @getFirstVisibleRow() + 1
      @makeRowVisible(row - 1)

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
    return if @updateRequested

    @updateRequested = true
    requestAnimationFrame =>
      @update()
      @updateRequested = false

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

    # We never rendered anything
    unless @firstRenderedRow?
      for column in visibleColumns
        @appendHeaderCell(columns[column], column)
        @appendCell(row, column) for row in visibleRows

      @appendGutterCell(row) for row in visibleRows

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


    for row in [intactFirstRow...intactLastRow]
      @gutterCells[row]?.setModel({row})
      for column in [intactFirstColumn...intactLastColumn]
        @cells[column][row]?.setModel(@getCellObjectAtPosition([row, column]))
    for column in [intactFirstColumn...intactLastColumn]
      @headerCells[column]?.setModel({column: columns[column], index: column})

    @firstRenderedRow = firstRow
    @lastRenderedRow = lastRow
    @firstRenderedColumn = firstColumn
    @lastRenderedColumn = lastColumn
    @hasChanged = false

  updateWidthAndHeight: ->
    @tableCells.style.cssText = """
    height: #{@tableEditor.getContentHeight()}px;
    width: #{@tableEditor.getContentWidth()}px;
    """
    @tableGutter.style.cssText = """
    height: #{@tableEditor.getContentHeight()}px;
    """
    @tableHeaderCells.style.cssText = """
    width: #{@tableEditor.getContentWidth()}px;
    """

    @tableGutterFiller.textContent = @tableHeaderFiller.textContent = @tableEditor.getScreenRowCount()

  updateScroll: ->
    @getColumnsContainer().scrollLeft = @getColumnsScrollContainer().scrollLeft
    @getGutter().scrollTop = @getRowsContainer().scrollTop

  updateSelection: ->
    # if @selectionSpansManyCells()
    #   {top, left, width, height} = @selectionScrollRect()
    #   @tableEditorSelectionBox.style.cssText = """
    #   top: #{top}px;
    #   left: #{left}px;
    #   height: #{height}px;
    #   width: #{width}px;
    #   """
    #   @tableEditorSelectionBoxHandle.style.cssText = """
    #   top: #{top + height}px;
    #   left: #{left + width}px;
    #   """
    # else
    #   @tableEditorSelectionBox.style.cssText = "display: none"
    #   @tableEditorSelectionBoxHandle.style.cssText = "display: none"

  getScreenCellAtPosition: (position) ->
    position = Point.fromObject(position)
    @cells[position.column][position.row]

  appendCell: (row, column) ->
    @cells[column] ?= []
    return @cells[column][row] if @cells[column][row]?

    @cells[column][row] = @requestCell(@getCellObjectAtPosition([row, column]))

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
    cell = @cells[column]?[row]
    return unless cell?
    @releaseCell(cell)
    @cells[column][row] = undefined

  appendHeaderCell: (column, index) ->
    return @headerCells[index] if @headerCells[index]?

    @headerCells[index] = @requestHeaderCell({column, index})

  disposeHeaderCell: (column) ->
    return unless cell = @headerCells[column]
    @releaseHeaderCell(cell)
    delete @headerCells[column]

  appendGutterCell: (row) ->
    return @gutterCells[row] if @gutterCells[row]?

    @gutterCells[row] = @requestGutterCell({row})

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
