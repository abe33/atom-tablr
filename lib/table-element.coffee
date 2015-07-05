{Point, Range, TextEditor} = require 'atom'
{CompositeDisposable, Disposable} = require 'event-kit'
{EventsDelegation, SpacePenDSL} = require 'atom-utils'
PropertyAccessors = require 'property-accessors'

Table = require './table'
TableCellElement = require './table-cell-element'
TableHeaderCellElement = require './table-header-cell-element'
TableGutterCellElement = require './table-gutter-cell-element'
Axis = require './mixins/axis'
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
  Axis.includeInto(this)
  Pool.includeInto(this)

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

  gutter: false
  rowOffsets: null
  columnOffsets: null
  absoluteColumnsWidths: false

  createdCallback: ->
    @cells = []
    @headerCells = []
    @gutterCells = []

    @activeCellPosition = new Point
    @subscriptions = new CompositeDisposable

    @absoluteColumnsWidths = @hasAttribute('absolute-columns-widths')

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
      'core:undo': => @table.undo()
      'core:redo': => @table.redo()
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
      'table-edit:delete-row': => @deleteActiveRow()
      'table-edit:insert-column-before': => @insertColumnBefore()
      'table-edit:insert-column-after': => @insertColumnAfter()
      'table-edit:delete-column': => @deleteActiveColumn()

    @subscriptions.add @subscribeTo this,
      'mousedown': stopPropagationAndDefault (e) => @focus()
      'click': stopPropagationAndDefault()

    @subscriptions.add @subscribeTo @head,
      'mousedown': stopPropagationAndDefault (e) =>
        columnIndex = @findColumnAtScreenPosition(e.pageX, e.pageY)
        if column = @getScreenColumn(columnIndex)
          if column.name is @order
            if @direction is -1
              @resetSort()
            else
              @toggleSortDirection()
          else
            @sortBy(column.name)

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
          @activateCellAtPosition position

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
      'table-edit.minimumRowHeight': (@configMinimumRowHeight) =>
      'table-edit.rowHeight': (@configRowHeight) =>
        if @table?
          @computeRowOffsets()
          @requestUpdate() if @attached
      'table-edit.rowOverdraw': (@configRowOverdraw) =>
        @requestUpdate() if @attached
      'table-edit.columnWidth': (@configColumnWidth) =>
        if @table?
          @computeColumnOffsets()
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
    @computeRowOffsets()
    @computeColumnOffsets()
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

  getModel: -> @table

  buildModel: ->
    model = new Table
    model.addColumn('untitled')
    model.addRow()
    @setModel(model)

  setModel: (table) ->
    return unless table?

    @unsetModel() if @table?

    @table = table
    @modelSubscriptions = new CompositeDisposable()
    @modelSubscriptions.add @table.onDidAddColumn (e) => @onColumnAdded(e)
    @modelSubscriptions.add @table.onDidRemoveColumn (e) => @onColumnRemoved(e)
    @modelSubscriptions.add @table.onDidChangeColumnsOptions =>
      @computeColumnOffsets()
      @requestUpdate()
    @modelSubscriptions.add @table.onDidChangeRows =>
      @updateScreenRows()
      @computeRowOffsets()
      @requestUpdate()
    @modelSubscriptions.add @table.onDidChangeRowsOptions =>
      @computeRowOffsets()
      @requestUpdate()

    @subscribeToColumn(column) for column in @table.getColumns()

    @updateScreenRows()
    @updateScreenColumns()
    @setSelectionFromActiveCell()
    @requestUpdate()

  unsetModel: ->
    @modelSubscriptions.dispose()
    @modelSubscriptions = null
    @table = null

  #    ########   #######  ##      ##  ######
  #    ##     ## ##     ## ##  ##  ## ##    ##
  #    ##     ## ##     ## ##  ##  ## ##
  #    ########  ##     ## ##  ##  ##  ######
  #    ##   ##   ##     ## ##  ##  ##       ##
  #    ##    ##  ##     ## ##  ##  ## ##    ##
  #    ##     ##  #######   ###  ###   ######

  getRowRange: (row) -> Range.fromObject([[row, 0], [row, @getLastColumn()]])

  getRowsContainer: -> @tableRows

  getRowsOffsetContainer: -> @getRowsWrapper()

  getRowsScrollContainer: -> @getRowsContainer()

  getRowsWrapper: -> @tableCells

  getRowResizeRuler: -> @rowRuler

  insertRowBefore: -> @table.addRowAt(@activeCellPosition.row)

  insertRowAfter: -> @table.addRowAt(@activeCellPosition.row + 1)

  @axis 'y', 'height', 'top', 'row', 'rows'

  #     ######   #######  ##       ##     ## ##     ## ##    ##  ######
  #    ##    ## ##     ## ##       ##     ## ###   ### ###   ## ##    ##
  #    ##       ##     ## ##       ##     ## #### #### ####  ## ##
  #    ##       ##     ## ##       ##     ## ## ### ## ## ## ##  ######
  #    ##       ##     ## ##       ##     ## ##     ## ##  ####       ##
  #    ##    ## ##     ## ##       ##     ## ##     ## ##   ### ##    ##
  #     ######   #######  ########  #######  ##     ## ##    ##  ######

  getColumnAlign: (col) ->
    @columnsAligns?[col] ? @table.getColumn(col).align

  getColumnsAligns: ->
    [0...@table.getColumnsCount()].map (col) =>
      @columnsAligns?[col] ? @table.getColumn(col).align

  setColumnsAligns: (@columnsAligns) ->
    @requestUpdate()

  setAbsoluteColumnsWidths: (@absoluteColumnsWidths) -> @requestUpdate()

  setColumnsWidths: (columnsWidths) ->
    @getScreenColumn(i).width = w for w,i in columnsWidths
    @requestUpdate()

  getColumnsContainer: -> @tableHeaderRow

  getColumnsOffsetContainer: -> @tableCells

  getColumnsScrollContainer: -> @getRowsContainer()

  getColumnsWrapper: -> @tableHeaderCells

  getColumnResizeRuler: -> @columnRuler

  getNewColumnName: -> @newColumnId ?= 0; "untitled_#{@newColumnId++}"

  insertColumnBefore: ->
    @table.addColumnAt(@activeCellPosition.column, @getNewColumnName())

  insertColumnAfter: ->
    @table.addColumnAt(@activeCellPosition.column + 1, @getNewColumnName())

  onColumnAdded: ({column}) ->
    @updateScreenColumns()
    @subscribeToColumn(column)
    @requestUpdate()

  onColumnRemoved: ({column, index}) ->
    @updateScreenColumns()
    @unsubscribeFromColumn(column)
    @requestUpdate()

  subscribeToColumn: (column) ->
    @columnSubscriptions ?= {}
    subscription = @columnSubscriptions[column.id] = new CompositeDisposable

    subscription.add column.onDidChangeName => @requestUpdate()
    subscription.add column.onDidChangeOption => @requestUpdate()

  unsubscribeFromColumn: (column) ->
    @columnSubscriptions[column.id]?.dispose()
    delete @columnSubscriptions[column.id]

  @axis 'x', 'width', 'left', 'column', 'columns'

  #     ######  ######## ##       ##        ######
  #    ##    ## ##       ##       ##       ##    ##
  #    ##       ##       ##       ##       ##
  #    ##       ######   ##       ##        ######
  #    ##       ##       ##       ##             ##
  #    ##    ## ##       ##       ##       ##    ##
  #     ######  ######## ######## ########  ######

  getActiveCell: ->
    @table.cellAtPosition(@modelPosition(@activeCellPosition))

  isActiveCell: (cell) -> @getActiveCell() is cell

  isSelectedCell: (cell) -> @isSelectedPosition(@table.positionOfCell(cell))

  activateCell: (cell) ->
    @activateCellAtPosition(@table.positionOfCell(cell))

  activateCellAtPosition: (position) ->
    return unless position?

    position = Point.fromObject(position)

    @activeCellPosition = position
    @afterActiveCellMove()

  cellScreenRect: (position) ->
    {top, left} = @cellScreenPosition(position)

    width = @getScreenColumnWidthAt(position.column)
    height = @getScreenRowHeightAt(position.row)

    {top, left, width, height}

  cellScreenPosition: (position) ->
    {top, left} = @cellScrollPosition(position)

    {
      top: top + @getRowsOffsetContainer().getBoundingClientRect().top,
      left: left + @getColumnsOffsetContainer().getBoundingClientRect().left
    }

  cellScrollPosition: (position) ->
    position = Point.fromObject(position)
    {
      top: @getScreenRowOffsetAt(position.row)
      left: @getScreenColumnOffsetAt(position.column)
    }

  cellPositionAtScreenPosition: (x,y) ->
    return unless x? and y?

    row = @findRowAtScreenPosition(y)
    column = @findColumnAtScreenPosition(x)

    {row, column}

  screenPosition: (position) ->
    {row, column} = Point.fromObject(position)

    {row: @modelRowToScreenRow(row), column: @modelColumnToScreenColumn(column)}

  modelPosition: (position) ->
    {row, column} = Point.fromObject(position)

    {row: @screenRowToModelRow(row), column: @screenColumnToModelColumn(column)}

  makeCellVisible: (position) ->
    @makeRowVisible(position.row)
    @makeColumnVisible(position.column)

  #     ######   #######  ##    ## ######## ########   #######  ##
  #    ##    ## ##     ## ###   ##    ##    ##     ## ##     ## ##
  #    ##       ##     ## ####  ##    ##    ##     ## ##     ## ##
  #    ##       ##     ## ## ## ##    ##    ########  ##     ## ##
  #    ##       ##     ## ##  ####    ##    ##   ##   ##     ## ##
  #    ##    ## ##     ## ##   ###    ##    ##    ##  ##     ## ##
  #     ######   #######  ##    ##    ##    ##     ##  #######  ########

  focus: -> @hiddenInput.focus() unless @hasFocus()

  hasFocus: -> this is document.activeElement

  moveRight: ->
    if @activeCellPosition.column + 1 < @table.getColumnsCount()
      @activeCellPosition.column++
    else
      @activeCellPosition.column = 0

      if @activeCellPosition.row + 1 < @table.getRowsCount()
        @activeCellPosition.row++
      else
        @activeCellPosition.row = 0

    @afterActiveCellMove()

  moveLeft: ->
    if @activeCellPosition.column - 1 >= 0
      @activeCellPosition.column--
    else
      @activeCellPosition.column = @getLastColumn()

      if @activeCellPosition.row - 1 >= 0
        @activeCellPosition.row--
      else
        @activeCellPosition.row = @getLastRow()

    @afterActiveCellMove()

  moveUp: ->
    if @activeCellPosition.row - 1 >= 0
      @activeCellPosition.row--
    else
      @activeCellPosition.row = @getLastRow()

    @afterActiveCellMove()

  moveDown: ->
    if @activeCellPosition.row + 1 < @table.getRowsCount()
      @activeCellPosition.row++
    else
      @activeCellPosition.row = 0

    @afterActiveCellMove()

  moveToTop: ->
    return if @activeCellPosition.row is 0

    @activeCellPosition.row = 0
    @afterActiveCellMove()

  moveToBottom: ->
    end = @getLastRow()
    return if @activeCellPosition.row is end

    @activeCellPosition.row = end
    @afterActiveCellMove()

  moveToLeft: ->
    return if @activeCellPosition.column is 0

    @activeCellPosition.column = 0
    @afterActiveCellMove()

  moveToRight: ->
    end = @getLastColumn()
    return if @activeCellPosition.column is end

    @activeCellPosition.column = end
    @afterActiveCellMove()

  pageDown: ->
    amount = @getPageMovesAmount()
    if @activeCellPosition.row + amount < @table.getRowsCount()
      @activeCellPosition.row += amount
    else
      @activeCellPosition.row = @getLastRow()

    @afterActiveCellMove()

  pageUp: ->
    amount = @getPageMovesAmount()
    if @activeCellPosition.row - amount >= 0
      @activeCellPosition.row -= amount
    else
      @activeCellPosition.row = 0

    @afterActiveCellMove()

  afterActiveCellMove: ->
    @setSelectionFromActiveCell()
    @requestUpdate()
    @makeCellVisible(@activeCellPosition)

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

    activeCell = @getActiveCell()
    activeCellRect = @cellScreenRect(@activeCellPosition)

    @editorElement.style.top = @toUnit(activeCellRect.top)
    @editorElement.style.left = @toUnit(activeCellRect.left)
    @editorElement.style.width = @toUnit(activeCellRect.width)
    @editorElement.style.height = @toUnit(activeCellRect.height)
    @editorElement.style.display = 'block'

    @editorElement.dataset.column = activeCell.column.name
    @editorElement.dataset.row = @activeCellPosition.row + 1

    @editorElement.focus()

    @editor.setText(String(activeCell.getValue() ? @getUndefinedDisplay()))

    @editor.getBuffer().history.clearUndoStack()
    @editor.getBuffer().history.clearRedoStack()

  confirmCellEdit: ->
    @stopEdit()
    activeCell = @getActiveCell()
    newValue = @editor.getText()
    activeCell.setValue(newValue) unless newValue is activeCell.getValue()

  startColumnEdit: ({target, pageX, pageY}) =>
    @createTextEditor() unless @editor?

    @subscribeToColumnTextEditor(@editor)

    @editing = true

    columnIndex = @findColumnAtScreenPosition(pageX, pageY)
    if @columnUnderEdit = @getScreenColumn(columnIndex)
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

    @dragging = true

    row = @findRowAtScreenPosition(e.pageY)
    @setSelection(@getRowRange(row)) if row?

    @initializeDragEvents @body,
      'mousemove': stopPropagationAndDefault (e) => @gutterDrag(e)
      'mouseup': stopPropagationAndDefault (e) => @endGutterDrag(e)

  gutterDrag: (e) ->
    if @dragging
      row = @findRowAtScreenPosition(e.pageY)

      if row < @activeCellPosition.row
        @selection.start.row = row
        @selection.end.row = @activeCellPosition.row
      else if row > @activeCellPosition.row
        @selection.end.row = row
        @selection.start.row = @activeCellPosition.row
      else
        @selection.end.row = @activeCellPosition.row
        @selection.start.row = @activeCellPosition.row

      @scrollDuringDrag(row)
      @requestUpdate()

  endGutterDrag: (e) ->
    return unless @dragging

    @dragSubscription.dispose()
    @gutterDrag(e)
    @dragging = false

  startRowResizeDrag: (e) ->
    return if @dragging

    @dragging = true

    row = @findRowAtScreenPosition(e.pageY)

    handle = e.target
    handleHeight = handle.offsetHeight
    handleOffset = handle.getBoundingClientRect()
    dragOffset = handleOffset.top - e.pageY

    initial = {row, handle, handleHeight, dragOffset}

    rulerTop = @getScreenRowOffsetAt(row) + @getScreenRowHeightAt(row)

    ruler = @getRowResizeRuler()
    ruler.classList.add('visible')
    ruler.style.top = @toUnit(rulerTop)

    @initializeDragEvents @body,
      'mousemove': stopPropagationAndDefault (e) => @rowResizeDrag(e, initial)
      'mouseup': stopPropagationAndDefault (e) => @endRowResizeDrag(e, initial)

  rowResizeDrag: ({pageY}, {row, handleHeight, dragOffset}) ->
    if @dragging
      ruler = @getRowResizeRuler()
      rulerTop = Math.max(@getMinimumRowHeight(), pageY - @body.getBoundingClientRect().top + dragOffset + handleHeight - ruler.offsetHeight)
      ruler.style.top = @toUnit(rulerTop)

  endRowResizeDrag: ({pageY}, {row, handleHeight, dragOffset}) ->
    return unless @dragging

    rowY = @rowScreenPosition(row) - @getRowsScrollContainer().scrollTop
    newRowHeight = pageY - rowY + dragOffset + handleHeight
    @setScreenRowHeightAt(row, Math.max(@getMinimumRowHeight(), newRowHeight))
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

    column = @getScreenColumn(position)
    width = @getScreenColumnWidthAt(position)
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

  #     ######   #######  ########  ######## #### ##    ##  ######
  #    ##    ## ##     ## ##     ##    ##     ##  ###   ## ##    ##
  #    ##       ##     ## ##     ##    ##     ##  ####  ## ##
  #     ######  ##     ## ########     ##     ##  ## ## ## ##   ####
  #          ## ##     ## ##   ##      ##     ##  ##  #### ##    ##
  #    ##    ## ##     ## ##    ##     ##     ##  ##   ### ##    ##
  #     ######   #######  ##     ##    ##    #### ##    ##  ######

  sortBy: (@order, @direction=1) ->
    @updateScreenRows()
    @requestUpdate()

  toggleSortDirection: ->
    @direction *= -1
    @updateScreenRows()
    @requestUpdate()

  resetSort: ->
    @order = null
    @updateScreenRows()
    @requestUpdate()

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
    return unless @table?
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
    lastRow = Math.min @table.getRowsCount(), lastVisibleRow + rowOverdraw
    visibleRows = [firstRow...lastRow]
    oldVisibleRows = [@firstRenderedRow...@lastRenderedRow]

    columns = @table.getColumns()
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
        @cells[column][row]?.setModel({
          row
          column
          cell: @getScreenRow(row).getCell(column)
        })
    for column in [intactFirstColumn...intactLastColumn]
      @headerCells[column]?.setModel({column: columns[column], index: column})

    @firstRenderedRow = firstRow
    @lastRenderedRow = lastRow
    @firstRenderedColumn = firstColumn
    @lastRenderedColumn = lastColumn
    @hasChanged = false

  updateWidthAndHeight: ->
    @tableCells.style.cssText = """
    height: #{@getContentHeight()}px;
    width: #{@getContentWidth()}px;
    """
    @tableGutter.style.cssText = """
    height: #{@getContentHeight()}px;
    """
    @tableHeaderCells.style.cssText = """
    width: #{@getContentWidth()}px;
    """

    @tableGutterFiller.textContent = @tableHeaderFiller.textContent = @table.getRowsCount()

  updateScroll: ->
    @getColumnsContainer().scrollLeft = @getColumnsScrollContainer().scrollLeft
    @getGutter().scrollTop = @getRowsContainer().scrollTop

  updateSelection: ->
    if @selectionSpansManyCells()
      {top, left, width, height} = @selectionScrollRect()
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

  getScreenCellAt: (row, column) -> @cells[column][row]

  appendCell: (row, column) ->
    @cells[column] ?= []
    return @cells[column][row] if @cells[column][row]?

    cell = @getScreenRow(row).getCell(column)
    @cells[column][row] = @requestCell({cell, column, row})

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
  atom.views.addViewProvider Table, (model) ->
    element = new TableElement
    element.setModel(model)
    element
