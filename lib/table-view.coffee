{Point, Range} = require 'atom'
{View, $} = require 'space-pen'
{TextEditorView} = require 'atom-space-pen-views'
{CompositeDisposable, Disposable} = require 'event-kit'
PropertyAccessors = require 'property-accessors'
React = require 'react-atom-fork'
TableComponent = require './table-component'
TableHeaderComponent = require './table-header-component'

stopPropagationAndDefault = (f) -> (e) ->
  e.stopPropagation()
  e.preventDefault()
  f?(e)

module.exports =
class TableView extends View
  PropertyAccessors.includeInto(this)

  @content: ->
    @div class: 'table-edit', =>
      @input type: 'text', class: 'hidden-input', outlet: 'hiddenInput'
      @div outlet: 'head', class: 'table-edit-header'
      @div outlet: 'body', class: 'scroll-view'

  initialize: (@table) ->
    @gutter = false
    @scroll = 0
    @activeCellPosition = new Point
    @rowHeights = {}
    @rowOffsets = null

    @subscriptions = new CompositeDisposable

    @subscriptions.add @table.onDidChangeRows @requestUpdate
    @subscriptions.add @table.onDidAddColumn @onColumnAdded
    @subscriptions.add @table.onDidRemoveColumn @onColumnRemoved

    @subscribeTo @hiddenInput,
      'textInput': (e) =>
        unless @isEditing()
          @startEdit()
          @editView.setText(e.originalEvent.data)

    @subscriptions.add atom.commands.add '.table-edit',
      'core:confirm': => @startEdit()
      'core:undo': => @table.undo()
      'core:redo': => @table.redo()
      'core:move-left': => @moveLeft()
      'core:move-right': => @moveRight()
      'core:move-up': => @moveUp()
      'core:move-down': => @moveDown()
      'core:move-to-top': => @moveToTop()
      'core:move-to-bottom': => @moveToBottom()
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

    @subscribeTo this,
      'mousedown': stopPropagationAndDefault (e) => @focus()
      'click': stopPropagationAndDefault()

    @subscribeTo @head,
      'mousedown': stopPropagationAndDefault (e) =>
        if column = @columnAtScreenPosition(e.pageX, e.pageY)
          if column.name is @order
            if @direction is -1
              @resetSort()
            else
              @toggleSortDirection()
          else
            @sortBy(column.name)

    @subscribeTo @head, '.table-edit-header-cell .column-resize-handle',
      'mousedown': stopPropagationAndDefault (e) => @startColumnResizeDrag(e)
      'click': stopPropagationAndDefault()

    @subscribeTo @body,
      'scroll': => @requestUpdate()
      'dblclick': (e) => @startEdit()
      'mousedown': stopPropagationAndDefault (e) =>
        @stopEdit() if @isEditing()

        if position = @cellPositionAtScreenPosition(e.pageX, e.pageY)
          @activateCellAtPosition position

        @startDrag(e)
        @focus()
      'click': stopPropagationAndDefault()

    @subscribeTo @body, '.table-edit-gutter',
      'mousedown': stopPropagationAndDefault (e) => @startGutterDrag(e)
      'click': stopPropagationAndDefault()

    @subscribeTo @body, '.table-edit-gutter .row-resize-handle',
      'mousedown': stopPropagationAndDefault (e) => @startRowResizeDrag(e)
      'click': stopPropagationAndDefault()

    @subscribeTo @body, '.selection-box-handle',
      'mousedown': stopPropagationAndDefault (e) => @startDrag(e)
      'click': stopPropagationAndDefault()

    @updateScreenRows()

    @observeConfig
      'table-edit.undefinedDisplay': (@configUndefinedDisplay) =>
        @requestUpdate()
      'table-edit.pageMovesAmount': (@configPageMovesAmount) => @requestUpdate()
      'table-edit.minimumRowHeight': (@configMinimumRowHeight) =>
      'table-edit.rowHeight': (@configRowHeight) =>
        @computeRowOffsets()
        @requestUpdate()
      'table-edit.rowOverdraw': (@configRowOverdraw) => @requestUpdate()

    @setSelectionFromActiveCell()
    @subscribeToColumn(column) for column in @table.getColumns()

    props = {@table, parentView: this}
    @bodyComponent = React.renderComponent(TableComponent(props), @body[0])
    @headComponent = React.renderComponent(TableHeaderComponent(props), @head[0])

  attach: (target) ->
    @onAttach()
    target.append(this)

  onAttach: ->
    @computeRowOffsets()
    @requestUpdate()

  destroy: ->
    @off()
    @body.off()
    @hiddenInput.off()

    @subscriptions.dispose()
    @remove()

  showGutter: ->
    @gutter = true
    @requestUpdate()

  hideGutter: ->
    @gutter = false
    @requestUpdate()

  getUndefinedDisplay: -> @undefinedDisplay ? @configUndefinedDisplay

  subscribeTo: (object, selector, events) ->
    [events, selector] = [selector, null] if typeof selector is 'object'
    if selector
      for event, callback of events
        @subscriptions.add @asDisposable object.on event, selector, callback
    else
      for event, callback of events
        @subscriptions.add @asDisposable object.on event, callback

  observeConfig: (configs) ->
    for config, callback of configs
      @subscriptions.add atom.config.observe config, callback

  #    ########   #######  ##      ##  ######
  #    ##     ## ##     ## ##  ##  ## ##    ##
  #    ##     ## ##     ## ##  ##  ## ##
  #    ########  ##     ## ##  ##  ##  ######
  #    ##   ##   ##     ## ##  ##  ##       ##
  #    ##    ##  ##     ## ##  ##  ## ##    ##
  #    ##     ##  #######   ###  ###   ######

  isActiveRow: (row) -> @activeCellPosition.row is row

  isSelectedRow: (row) ->
    row >= @selection.start.row and row <= @selection.end.row

  getRowHeight: -> @rowHeight ? @configRowHeight

  getMinimumRowHeight: -> @minimumRowHeight ? @configMinimumRowHeight

  setRowHeight: (@rowHeight) ->
    @computeRowOffsets()
    @requestUpdate()

  getRowHeightAt: (index) ->
    @rowHeights[index] ? @getRowHeight()

  setRowHeightAt: (index, height) ->
    minHeight = @getMinimumRowHeight()
    height = minHeight if height < minHeight
    @rowHeights[index] = height
    @computeRowOffsets()
    @requestUpdate()

  getRowRange: (row) -> Range.fromObject([[row, 0], [row, @getLastColumn()]])

  getRowOffsetAt: (index) -> @getScreenRowOffsetAt(@modelRowToScreenRow(index))

  getRowOverdraw: -> @rowOverdraw ? @configRowOverdraw

  setRowOverdraw: (@rowOverdraw) -> @requestUpdate()

  getLastRow: -> @table.getRowsCount() - 1

  getFirstVisibleRow: ->
    @findRowAtPosition(@body.scrollTop())

  getLastVisibleRow: ->
    scrollViewHeight = @body.height()

    @findRowAtPosition(@body.scrollTop() + scrollViewHeight) ? @table.getRowsCount() - 1

  getScreenRows: -> @screenRows

  getScreenRow: (row) -> @table.getRow(@screenRowToModelRow(row))

  getScreenRowHeightAt: (row) -> @getRowHeightAt(@screenRowToModelRow(row))

  setScreenRowHeightAt: (row, height) ->
    @setRowHeightAt(@screenRowToModelRow(row), height)

  getScreenRowOffsetAt: (row) -> @rowOffsets[row]

  getRowsContainer: ->
    @rowsContainer ?= @body.find('.table-edit-rows')

  getRowResizeRuler: ->
    @rowResizeRuler ?= @body.find('.row-resize-ruler')

  screenRowToModelRow: (row) -> @screenToModelRowsMap[row]

  modelRowToScreenRow: (row) -> @modelToScreenRowsMap[row]

  makeRowVisible: (row) ->
    rowHeight = @getScreenRowHeightAt(row)
    scrollViewHeight = @body.height()
    currentScrollTop = @body.scrollTop()

    rowOffset = @getScreenRowOffsetAt(row)

    scrollTopAsFirstVisibleRow = rowOffset
    scrollTopAsLastVisibleRow = rowOffset - (scrollViewHeight - rowHeight)

    return if scrollTopAsFirstVisibleRow >= currentScrollTop and
              scrollTopAsFirstVisibleRow + rowHeight <= currentScrollTop + scrollViewHeight

    if rowOffset > currentScrollTop
      @body.scrollTop(scrollTopAsLastVisibleRow)
    else
      @body.scrollTop(scrollTopAsFirstVisibleRow)

  computeRowOffsets: ->
    offsets = []
    offset = 0

    for i in [0...@table.getRowsCount()]
      offsets.push offset
      offset += @getScreenRowHeightAt(i)

    @rowOffsets = offsets

  rowScreenPosition: (row) ->
    top = @getScreenRowOffsetAt(row)

    content = @getRowsContainer()
    contentOffset = content.offset()

    top + contentOffset.top

  findRowAtPosition: (y) ->
    for i in [0...@table.getRowsCount()]
      offset = @getScreenRowOffsetAt(i)
      return i - 1 if y < offset

    return @table.getRowsCount() - 1

  findRowAtScreenPosition: (y) ->
    content = @getRowsContainer()

    bodyOffset = content.offset()

    y -= bodyOffset.top

    @findRowAtPosition(y)

  updateScreenRows: ->
    rows = @table.getRows()
    @screenRows = rows.concat()
    @screenRows.sort(@compareRows(@order, @direction)) if @order?
    @screenToModelRowsMap = (rows.indexOf(row) for row in @screenRows)
    @modelToScreenRowsMap = (@screenRows.indexOf(row) for row in rows)
    @computeRowOffsets()

  compareRows: (order, direction) -> (a,b) ->
    a = a[order]
    b = b[order]
    if a > b
      direction
    else if a < b
      -direction
    else
      0

  #     ######   #######  ##       ##     ## ##     ## ##    ##  ######
  #    ##    ## ##     ## ##       ##     ## ###   ### ###   ## ##    ##
  #    ##       ##     ## ##       ##     ## #### #### ####  ## ##
  #    ##       ##     ## ##       ##     ## ## ### ## ## ## ##  ######
  #    ##       ##     ## ##       ##     ## ##     ## ##  ####       ##
  #    ##    ## ##     ## ##       ##     ## ##     ## ##   ### ##    ##
  #     ######   #######  ########  #######  ##     ## ##    ##  ######

  getLastColumn: -> @table.getColumnsCount() - 1

  isActiveColumn: (column) -> @activeCellPosition.column is column

  getColumnsAligns: ->
    [0...@table.getColumnsCount()].map (col) =>
      @columnsAligns?[col] ? @table.getColumn(col).align

  setColumnsAligns: (@columnsAligns) ->
    @requestUpdate()

  hasColumnWithWidth: -> @table.getColumns().some (c) -> c.width?

  getColumnsWidths: ->
    return @columnsWidths if @columnsWidths

    if @hasColumnWithWidth()
      @columnsWidths = @getColumnsWidthsFromModel()
    else
      count = @table.getColumnsCount()
      (1 / count for n in [0...count])

  getColumnsWidthPercentages: -> @getColumnsWidths().map @floatToPercent

  getColumnsWidthsFromModel: ->
    count = @table.getColumnsCount()

    widths = (@table.getColumn(col).width for col in [0...count])
    @normalizeColumnsWidths(widths)

  getColumnsScreenWidths: ->
    width = @getRowsContainer().width()
    @getColumnsWidths().map (v) => v * width

  getColumnsScreenMargins: ->
    widths = @getColumnsWidths()
    pad = 0
    width = @getRowsContainer().width()
    margins = widths.map (v) =>
      res = pad
      pad += v * width
      res

    margins

  setColumnsWidths: (columnsWidths) ->
    widths = @normalizeColumnsWidths(columnsWidths)
    @columnsWidths = widths

    @requestUpdate()

  getColumnsContainer: ->
    @columnsContainer ?= @head.find('.table-edit-header-row')

  getColumnResizeRuler: ->
    @columnResizeRuler ?= @head.find('.column-resize-ruler')

  columnAtScreenPosition: (x,y) ->
    return unless x? and y?

    content = @getColumnsContainer()

    bodyWidth = content.width()
    bodyOffset = content.offset()

    x -= bodyOffset.left
    y -= bodyOffset.top

    columnsWidths = @getColumnsWidths()
    column = -1
    pad = 0
    while pad <= x
      pad += columnsWidths[column+1] * bodyWidth
      column++

    @table.getColumn(column)

  normalizeColumnsWidths: (columnsWidths) ->
    restWidth = 1
    wholeWidth = 0
    missingIndices = []
    widths = []

    for index in [0...@table.getColumnsCount()]
      width = columnsWidths[index]
      if width?
        widths[index] = width
        wholeWidth += width
        restWidth -= width
      else
        missingIndices.push index

    if (missingCount = missingIndices.length)
      if restWidth <= 0 and missingCount
        restWidth = wholeWidth
        wholeWidth *= 2

      for index in missingIndices
        widths[index] = restWidth / missingCount

    if wholeWidth > 1
      widths = widths.map (w) -> w * (1 / wholeWidth)

    widths

  onColumnAdded: ({column}) ->
    @subscribeToColumn(column)
    @requestUpdate()

  onColumnRemoved: ({column}) ->
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
    widths = @getColumnsScreenWidths()

    width = widths[position.column]
    height = @getScreenRowHeightAt(position.row)

    {top, left, width, height}

  cellScreenPosition: (position) ->
    {top, left} = @cellScrollPosition(position)

    content = @getRowsContainer()
    contentOffset = content.offset()

    {
      top: top + contentOffset.top,
      left: left + contentOffset.left
    }

  cellScrollPosition: (position) ->
    position = Point.fromObject(position)
    margins = @getColumnsScreenMargins()
    {
      top: @getScreenRowOffsetAt(position.row)
      left: margins[position.column]
    }

  cellPositionAtScreenPosition: (x,y) ->
    return unless x? and y?

    content = @getRowsContainer()

    bodyWidth = content.width()
    bodyOffset = content.offset()

    x -= bodyOffset.left
    y -= bodyOffset.top

    row = @findRowAtPosition(y)

    columnsWidths = @getColumnsWidths()
    column = -1
    pad = 0
    while pad <= x
      pad += columnsWidths[column+1] * bodyWidth
      column++

    {row, column}

  screenPosition: (position) ->
    {row, column} = Point.fromObject(position)

    {row: @modelRowToScreenRow(row), column}

  modelPosition: (position) ->
    {row, column} = Point.fromObject(position)

    {row: @screenRowToModelRow(row), column}

  #     ######   #######  ##    ## ######## ########   #######  ##
  #    ##    ## ##     ## ###   ##    ##    ##     ## ##     ## ##
  #    ##       ##     ## ####  ##    ##    ##     ## ##     ## ##
  #    ##       ##     ## ## ## ##    ##    ########  ##     ## ##
  #    ##       ##     ## ##  ####    ##    ##   ##   ##     ## ##
  #    ##    ## ##     ## ##   ###    ##    ##    ##  ##     ## ##
  #     ######   #######  ##    ##    ##    ##     ##  #######  ########

  focus: ->
    @hiddenInput.focus() unless document.activeElement is @hiddenInput[0]

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
    @makeRowVisible(@activeCellPosition.row)

  getPageMovesAmount: -> @pageMovesAmount ? @configPageMovesAmount

  #    ######## ########  #### ########
  #    ##       ##     ##  ##     ##
  #    ##       ##     ##  ##     ##
  #    ######   ##     ##  ##     ##
  #    ##       ##     ##  ##     ##
  #    ##       ##     ##  ##     ##
  #    ######## ########  ####    ##

  isEditing: -> @editing

  startEdit: =>
    @createEditView() unless @editView?

    @editing = true

    activeCell = @getActiveCell()
    activeCellRect = @cellScreenRect(@activeCellPosition)

    @editView.css(
      top: activeCellRect.top + 'px'
      left: activeCellRect.left + 'px'
    )
    .width(activeCellRect.width)
    .height(activeCellRect.height)
    .show()

    @editView.focus()

    @editView.setText(activeCell.getValue().toString())

    @editView.getModel().getBuffer().history.clearUndoStack()
    @editView.getModel().getBuffer().history.clearRedoStack()

  confirmEdit: ->
    @stopEdit()
    activeCell = @getActiveCell()
    newValue = @editView.getText()
    activeCell.setValue(newValue) unless newValue is activeCell.getValue()

  stopEdit: ->
    @editing = false
    @editView.hide()
    @focus()

  createEditView: ->
    @editView = new TextEditorView({})
    @subscribeToTextEditor(@editView)
    @append(@editView)

  subscribeToTextEditor: (editorView) ->
    @subscriptions.add atom.commands.add '.table-edit atom-text-editor',
      'table-edit:move-right': (e) =>
        @confirmEdit()
        @moveRight()
      'table-edit:move-left': (e) =>
        @confirmEdit()
        @moveLeft()
      'core:cancel': (e) =>
        @stopEdit()
        e.stopImmediatePropagation()
        return false
      'core:confirm': (e) =>
        @confirmEdit()
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

    widths = @getColumnsWidths()

    for col in [@selection.start.column..@selection.end.column]
      width += widths[col] * 100

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

    @body.on 'mousemove', stopPropagationAndDefault (e) => @drag(e)
    @body.on 'mouseup', stopPropagationAndDefault (e) => @endDrag(e)
    @initializeDragDisposable()

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

    @body.on 'mousemove', stopPropagationAndDefault (e) => @gutterDrag(e)
    @body.on 'mouseup', stopPropagationAndDefault (e) => @endGutterDrag(e)
    @initializeDragDisposable()

    row = @findRowAtScreenPosition(e.pageY)
    @setSelection(@getRowRange(row)) if row?

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

    handle = $(e.target)
    handleHeight = handle.height()
    handleOffset = handle.offset()
    dragOffset = handleOffset.top - e.pageY

    initial = {row, handle, handleHeight, dragOffset}

    @body.on 'mousemove', stopPropagationAndDefault (e) => @rowResizeDrag(e, initial)
    @body.on 'mouseup', stopPropagationAndDefault (e) => @endRowResizeDrag(e, initial)

    rulerTop = @getScreenRowOffsetAt(row) + @getScreenRowHeightAt(row)

    @getRowResizeRuler().addClass('visible').css(top: rulerTop)
    @initializeDragDisposable()

  rowResizeDrag: (e, {row, handleHeight, dragOffset}) ->
    if @dragging
      {pageY} = e
      rowY = @rowScreenPosition(row)
      newRowHeight = Math.max(pageY - rowY + dragOffset + handleHeight, @getMinimumRowHeight())
      rulerTop = @getScreenRowOffsetAt(row) + newRowHeight
      @getRowResizeRuler().css(top: rulerTop)

  endRowResizeDrag: (e, {row, handleHeight, dragOffset}) ->
    return unless @dragging

    {pageY} = e
    rowY = @rowScreenPosition(row)
    newRowHeight = pageY - rowY + dragOffset + handleHeight
    @setScreenRowHeightAt(row, newRowHeight)
    @getRowResizeRuler().removeClass('visible')

    @dragSubscription.dispose()
    @dragging = false

  startColumnResizeDrag: ({pageX, target}) ->
    return if @dragging

    @dragging = true

    handle = $(target)
    handleWidth = handle.width()
    handleOffset = handle.offset()
    dragOffset = handleOffset.left - pageX

    leftCellIndex = handle.parent().index()
    rightCellIndex = handle.parent().next().index()

    initial = {handle, leftCellIndex, rightCellIndex, handleWidth, dragOffset, startX: pageX}

    @on 'mousemove', stopPropagationAndDefault (e) => @columnResizeDrag(e, initial)
    @on 'mouseup', stopPropagationAndDefault (e) => @endColumnResizeDrag(e, initial)
    @dragSubscription = new Disposable =>
      @off 'mousemove'
      @off 'mouseup'

    @getColumnResizeRuler().addClass('visible').css(left: pageX - @head.offset().left).height(@height())

  columnResizeDrag: ({pageX}) ->
    @getColumnResizeRuler().css(left: pageX - @head.offset().left)

  endColumnResizeDrag: ({pageX}, {startX, leftCellIndex, rightCellIndex}) ->
    return unless @dragging

    moveX = pageX - startX
    columnsScreenWidths = @getColumnsScreenWidths()
    columnsWidths = @getColumnsWidths().concat()

    leftCellWidth = columnsScreenWidths[leftCellIndex]
    rightCellWidth = columnsScreenWidths[rightCellIndex]
    columnsWidth = @getColumnsContainer().width()

    leftCellRatio = (leftCellWidth + moveX) / columnsWidth
    rightCellRatio = (rightCellWidth - moveX) / columnsWidth

    columnsWidths[leftCellIndex] = leftCellRatio
    columnsWidths[rightCellIndex] = rightCellRatio

    @setColumnsWidths(columnsWidths)

    @getColumnResizeRuler().removeClass('visible')
    @dragSubscription.dispose()
    @dragging = false

  scrollDuringDrag: (row) ->
    if row >= @getLastVisibleRow() - 1
      @makeRowVisible(row + 1)
    else if row <= @getFirstVisibleRow() + 1
      @makeRowVisible(row - 1)

  initializeDragDisposable: ->
    @dragSubscription = new Disposable =>
      @body.off 'mousemove'
      @body.off 'mouseup'

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

  scrollTop: (scroll) ->
    if scroll?
      @body.scrollTop(scroll)
      @requestUpdate(false)

    @body.scrollTop()

  requestUpdate: (@hasChanged=true) =>
    return if @updateRequested

    @updateRequested = true
    requestAnimationFrame =>
      @update()
      @updateRequested = false

  update: =>
    firstVisibleRow = @getFirstVisibleRow()
    lastVisibleRow = @getLastVisibleRow()

    return if firstVisibleRow >= @firstRenderedRow and lastVisibleRow <= @lastRenderedRow and not @hasChanged

    rowOverdraw = @getRowOverdraw()
    firstRow = Math.max 0, firstVisibleRow - rowOverdraw
    lastRow = Math.min @table.getRowsCount(), lastVisibleRow + rowOverdraw

    state = {
      @gutter
      firstRow
      lastRow
      columnsWidths: @getColumnsWidthPercentages()
      columnsAligns: @getColumnsAligns()
      totalRows: @table.getRowsCount()
    }

    @bodyComponent.setState state
    @headComponent.setState state

    @firstRenderedRow = firstRow
    @lastRenderedRow = lastRow
    @hasChanged = false

  floatToPercent: (w) -> "#{Math.round(w * 10000) / 100}%"

  asDisposable: (o) -> new Disposable -> o?.off()
