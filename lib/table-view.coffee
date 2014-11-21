{Point, Range, TextEditorView, View} = require 'atom'
{CompositeDisposable, Disposable} = require 'event-kit'
PropertyAccessors = require 'property-accessors'
React = require 'react-atom-fork'
TableComponent = require './table-component'
TableHeaderComponent = require './table-header-component'

module.exports =
class TableView extends View
  PropertyAccessors.includeInto(this)

  @content: ->
    @div class: 'table-edit', =>
      @input type: 'text', class: 'hidden-input', outlet: 'hiddenInput'
      @div outlet: 'head', class: 'table-edit-header', =>
      @div outlet: 'body', class: 'scroll-view', =>

  initialize: (@table) ->
    @gutter = false
    @scroll = 0
    @activeCellPosition = new Point
    @rowHeights = {}
    @rowOffsets = null

    props = {@table, parentView: this}
    @bodyComponent = React.renderComponent(TableComponent(props), @body[0])
    @headComponent = React.renderComponent(TableHeaderComponent(props), @head[0])

    subs = @subscriptions = new CompositeDisposable
    sub = (o,e,c) => subs.add @asDisposable o.on e, c

    subs.add @table.onDidChangeRows @requestUpdate
    subs.add @table.onDidAddColumn @onColumnAdded
    subs.add @table.onDidRemoveColumn @onColumnRemoved

    sub @hiddenInput, 'textInput', (e) =>
      unless @isEditing()
        @startEdit()
        @editView.setText(e.originalEvent.data)

    sub @, 'core:confirm', => @startEdit()
    sub @, 'core:undo', => @table.undo()
    sub @, 'core:redo', => @table.redo()
    sub @, 'core:move-left', => @moveLeft()
    sub @, 'core:move-right', => @moveRight()
    sub @, 'core:move-up', => @moveUp()
    sub @, 'core:move-down', => @moveDown()
    sub @, 'core:move-to-top', => @moveToTop()
    sub @, 'core:move-to-bottom', => @moveToBottom()
    sub @, 'core:page-up', => @pageUp()
    sub @, 'core:page-down', => @pageDown()
    sub @, 'core:select-right', => @expandSelectionRight()
    sub @, 'core:select-left', => @expandSelectionLeft()
    sub @, 'core:select-up', => @expandSelectionUp()
    sub @, 'core:select-down', => @expandSelectionDown()
    sub @, 'mousedown', (e) => e.preventDefault(); @focus()

    sub @body, 'scroll', @requestUpdate
    sub @body, 'dblclick', (e) => @startEdit()
    sub @body, 'mousedown', (e) =>
      e.preventDefault()

      @stopEdit() if @isEditing()

      if position = @cellPositionAtScreenPosition(e.pageX, e.pageY)
        @activateCellAtPosition position

      @focus()

    @configUndefinedDisplay = atom.config.get('table-edit.undefinedDisplay')
    subs.add @asDisposable atom.config.observe 'table-edit.undefinedDisplay', (@configUndefinedDisplay) =>
      @requestUpdate()

    @configPageMovesAmount = atom.config.get('table-edit.pageMovesAmount')
    subs.add @asDisposable atom.config.observe 'table-edit.pageMovesAmount', (@configPageMovesAmount) =>
      @requestUpdate()

    @configRowHeight = atom.config.get('table-edit.rowHeight')
    subs.add @asDisposable atom.config.observe 'table-edit.rowHeight', (@configRowHeight) =>
      @computeRowOffsets()
      @requestUpdate()

    @configRowOverdraw = atom.config.get('table-edit.rowOverdraw')
    subs.add @asDisposable atom.config.observe 'table-edit.rowOverdraw', (@configRowOverdraw) =>
      @requestUpdate()

    @setSelectionFromActiveCell()
    @subscribeToColumn(column) for column in @table.getColumns()

  attach: (target) ->
    @onAttach()
    target.append(this)

  onAttach: ->
    @computeRowOffsets()
    @requestUpdate()

  destroy: ->
    @subscriptions.dispose()
    @remove()

  showGutter: ->
    @gutter = true
    @requestUpdate()

  hideGutter: ->
    @gutter = false
    @requestUpdate()

  getRows: ->
    @rows ?= @body.find('.table-edit-rows')

  getUndefinedDisplay: -> @undefinedDisplay ? @configUndefinedDisplay

  #    ########   #######  ##      ##  ######
  #    ##     ## ##     ## ##  ##  ## ##    ##
  #    ##     ## ##     ## ##  ##  ## ##
  #    ########  ##     ## ##  ##  ##  ######
  #    ##   ##   ##     ## ##  ##  ##       ##
  #    ##    ##  ##     ## ##  ##  ## ##    ##
  #    ##     ##  #######   ###  ###   ######

  getLastRow: -> @table.getRowsCount() - 1

  getRowHeight: -> @rowHeight ? @configRowHeight

  setRowHeight: (@rowHeight) ->
    @computeRowOffsets()
    @requestUpdate()

  getRowHeightAt: (index) -> @rowHeights[index] ? @getRowHeight()

  setRowHeightAt: (index, height) ->
    @rowHeights[index] = height
    @computeRowOffsets()
    @requestUpdate()

  getRowOffsetAt: (index) -> @rowOffsets[index]

  getRowOverdraw: -> @rowOverdraw ? @configRowOverdraw

  setRowOverdraw: (@rowOverdraw) -> @requestUpdate()

  getFirstVisibleRow: ->
    @findRowAtScreenPosition(@body.scrollTop())

  getLastVisibleRow: ->
    scrollViewHeight = @body.height()

    @findRowAtScreenPosition(@body.scrollTop() + scrollViewHeight) ? @table.getRowsCount() - 1

  isActiveRow: (row) -> @activeCellPosition.row is row

  makeRowVisible: (row) ->
    rowHeight = @getRowHeightAt(row)
    scrollViewHeight = @body.height()
    currentScrollTop = @body.scrollTop()

    rowOffset = @getRowOffsetAt(row)

    scrollTopAsFirstVisibleRow = rowOffset
    scrollTopAsLastVisibleRow = rowOffset - (scrollViewHeight - rowHeight)

    return if scrollTopAsFirstVisibleRow >= currentScrollTop and
              scrollTopAsFirstVisibleRow + rowHeight <= currentScrollTop + scrollViewHeight

    difAsFirstVisibleRow = Math.abs(currentScrollTop - scrollTopAsFirstVisibleRow)
    difAsLastVisibleRow = Math.abs(currentScrollTop - scrollTopAsLastVisibleRow)

    if difAsLastVisibleRow < difAsFirstVisibleRow
      @body.scrollTop(scrollTopAsLastVisibleRow)
    else
      @body.scrollTop(scrollTopAsFirstVisibleRow)

  computeRowOffsets: ->
    offsets = []
    offset = 0

    for i in [0...@table.getRowsCount()]
      offsets.push offset
      offset += @getRowHeightAt(i)

    @rowOffsets = offsets

  findRowAtScreenPosition: (y) ->
    for i in [0...@table.getRowsCount()]
      offset = @getRowOffsetAt(i)
      return i - 1 if y < offset

    return @table.getRowsCount() - 1

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
    return @columnsPercentWidths if @columnsPercentWidths?

    if @hasColumnWithWidth()
      @columnsWidths = @getColumnsWidthsFromModel()
      @columnsPercentWidths = @columnsWidths.map @floatToPercent
    else
      count = @table.getColumnsCount()
      (1 / count for n in [0...count]).map @floatToPercent

  getColumnsWidthsFromModel: ->
    count = @table.getColumnsCount()

    widths = (@table.getColumn(col).width for col in [0...count])
    @normalizeColumnsWidths(widths)

  getColumnsScreenWidths: ->
    width = @getRows().width()
    @getColumnsWidthsFromModel().map (v) => v * width

  getColumnsScreenMargins: ->
    widths = @getColumnsWidthsFromModel()
    pad = 0
    width = @getRows().width()
    margins = widths.map (v) =>
      res = pad
      pad += v * width
      res

    margins

  setColumnsWidths: (columnsWidths) ->
    widths = @normalizeColumnsWidths(columnsWidths)

    @columnsWidths = widths
    @columnsPercentWidths = widths.map @floatToPercent

    @requestUpdate()

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
    @table.cellAtPosition(@activeCellPosition)

  isActiveCell: (cell) -> @getActiveCell() is cell

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
    height = @getRowHeightAt(position.row)

    {top, left, width, height}

  cellScreenPosition: (position) ->
    {top, left} = @cellScrollPosition(position)

    content = @getRows()
    contentOffset = content.offset()

    {
      top: top + contentOffset.top,
      left: left + contentOffset.left
    }

  cellScrollPosition: (position) ->
    position = Point.fromObject(position)
    margins = @getColumnsScreenMargins()
    {
      top: @getRowOffsetAt(position.row)
      left: margins[position.column]
    }

  cellPositionAtScreenPosition: (x,y) ->
    return unless x? and y?

    content = @getRows()

    bodyWidth = content.width()
    bodyOffset = content.offset()

    x -= bodyOffset.left
    y -= bodyOffset.top

    row = @findRowAtScreenPosition(y)

    columnsWidths = @getColumnsWidthsFromModel()
    column = -1
    pad = 0
    while pad <= x
      pad += columnsWidths[column+1] * bodyWidth
      column++

    {row, column}

  #     ######   #######  ##    ## ######## ########   #######  ##
  #    ##    ## ##     ## ###   ##    ##    ##     ## ##     ## ##
  #    ##       ##     ## ####  ##    ##    ##     ## ##     ## ##
  #    ##       ##     ## ## ## ##    ##    ########  ##     ## ##
  #    ##       ##     ## ##  ####    ##    ##   ##   ##     ## ##
  #    ##    ## ##     ## ##   ###    ##    ##    ##  ##     ## ##
  #     ######   #######  ##    ##    ##    ##     ##  #######  ########

  focus: ->
    @hiddenInput.focus() unless document.activeElement is @hiddenInput.element

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

    @editView.find('.hidden-input').focus()

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
    @subscriptions.add @asDisposable editorView.on 'table-edit:move-right', (e) =>
      @confirmEdit()
      @moveRight()

    @subscriptions.add @asDisposable editorView.on 'table-edit:move-left', (e) =>
      @confirmEdit()
      @moveLeft()

    @subscriptions.add @asDisposable editorView.on 'core:cancel', (e) =>
      @stopEdit()
      e.stopImmediatePropagation()
      return false

    @subscriptions.add @asDisposable editorView.on 'core:confirm', (e) =>
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

  getSelection: -> @selection

  isSelectedCell: (cell) ->
    @iseSelectedPosition(@table.positionOfCell(cell))

  isSelectedPosition: (position) ->
    position = Point.fromObject(position)

    position.row >= @selection.start.row and
    position.row <= @selection.end.row and
    position.column >= @selection.start.column and
    position.column <= @selection.end.column

  setSelection: (selection) ->
    @selection = Range.fromObject(selection)
    @activeCellPosition = Point.fromObject(@selection.start)
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
    if @selectionExpandedDown()
      @selection.end.row = Math.max(@selection.end.row - 1, 0)
    else
      @selection.start.row = Math.max(@selection.start.row - 1, 0)
    @requestUpdate()

  expandSelectionDown: ->
    if @selectionExpandedUp()
      @selection.start.row = Math.min(@selection.start.row + 1, @getLastRow())
    else
      @selection.end.row = Math.min(@selection.end.row + 1, @getLastRow())
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
      columnsWidths: @getColumnsWidths()
      columnsAligns: @getColumnsAligns()
      totalRows: @table.getRowsCount()
    }

    @bodyComponent.setState state
    @headComponent.setState state

    @firstRenderedRow = firstRow
    @lastRenderedRow = lastRow
    @hasChanged = false

  asDisposable: (subscription) -> new Disposable -> subscription.off()

  floatToPercent: (w) -> "#{Math.round(w * 10000) / 100}%"
