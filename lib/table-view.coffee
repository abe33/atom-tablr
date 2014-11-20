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

    @subscriptions = new CompositeDisposable
    @subscriptions.add @table.onDidChangeRows @requestUpdate
    @subscriptions.add @table.onDidAddColumn @onColumnAdded
    @subscriptions.add @table.onDidRemoveColumn @onColumnRemoved

    @subscriptions.add @asDisposable @hiddenInput.on 'textInput', (e) =>
      unless @isEditing()
        @startEdit()
        @editView.setText(e.originalEvent.data)

    @subscriptions.add @asDisposable @on 'core:confirm', => @startEdit()
    @subscriptions.add @asDisposable @on 'core:undo', => @table.undo()
    @subscriptions.add @asDisposable @on 'core:redo', => @table.redo()
    @subscriptions.add @asDisposable @on 'core:move-left', => @moveLeft()
    @subscriptions.add @asDisposable @on 'core:move-right', => @moveRight()
    @subscriptions.add @asDisposable @on 'core:move-up', => @moveUp()
    @subscriptions.add @asDisposable @on 'core:move-down', => @moveDown()
    @subscriptions.add @asDisposable @on 'core:move-to-top', => @moveToTop()
    @subscriptions.add @asDisposable @on 'core:move-to-bottom', => @moveToBottom()
    @subscriptions.add @asDisposable @on 'core:page-up', => @pageUp()
    @subscriptions.add @asDisposable @on 'core:page-down', => @pageDown()
    @subscriptions.add @asDisposable @on 'mousedown', (e) =>
      e.preventDefault()
      @focus()

    @subscriptions.add @asDisposable @body.on 'scroll', @requestUpdate
    @subscriptions.add @asDisposable @body.on 'dblclick', (e) => @startEdit()
    @subscriptions.add @asDisposable @body.on 'mousedown', (e) =>
      e.preventDefault()

      @stopEdit() if @isEditing()

      if position = @cellPositionAtScreenPosition(e.pageX, e.pageY)
        @activateCellAtPosition position

      @focus()

    @configUndefinedDisplay = atom.config.get('table-edit.undefinedDisplay')
    @subscriptions.add @asDisposable atom.config.observe 'table-edit.undefinedDisplay', (@configUndefinedDisplay) =>
      @requestUpdate(true)

    @configPageMovesAmount = atom.config.get('table-edit.pageMovesAmount')
    @subscriptions.add @asDisposable atom.config.observe 'table-edit.pageMovesAmount', (@configPageMovesAmount) =>
      @requestUpdate(true)

    @configRowHeight = atom.config.get('table-edit.rowHeight')
    @subscriptions.add @asDisposable atom.config.observe 'table-edit.rowHeight', (@configRowHeight) =>
      @computeRowOffsets()
      @requestUpdate(true)

    @configRowOverdraw = atom.config.get('table-edit.rowOverdraw')
    @subscriptions.add @asDisposable atom.config.observe 'table-edit.rowOverdraw', (@configRowOverdraw) =>
      @requestUpdate(true)

    @subscribeToColumn(column) for column in @table.getColumns()

  attach: (target) ->
    @onAttach()
    target.append(this)

  onAttach: ->
    @computeRowOffsets()
    @requestUpdate(true)

  destroy: ->
    @subscriptions.dispose()
    @remove()

  showGutter: ->
    @gutter = true
    @requestUpdate(true)

  hideGutter: ->
    @gutter = false
    @requestUpdate(true)

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
    @requestUpdate(true)

  getRowHeightAt: (index) -> @rowHeights[index] ? @getRowHeight()

  setRowHeightAt: (index, height) ->
    @rowHeights[index] = height
    @computeRowOffsets()
    @requestUpdate(true)

  getRowOffsetAt: (index) -> @rowOffsets[index]

  getRowOverdraw: -> @rowOverdraw ? @configRowOverdraw

  setRowOverdraw: (@rowOverdraw) -> @requestUpdate(true)

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
    @requestUpdate(true)

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

    @requestUpdate(true)

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
    @requestUpdate(true)

  onColumnRemoved: ({column}) ->
    @unsubscribeFromColumn(column)
    @requestUpdate(true)

  subscribeToColumn: (column) ->
    @columnSubscriptions ?= {}
    subscription = @columnSubscriptions[column.id] = new CompositeDisposable

    subscription.add column.onDidChangeName => @requestUpdate(true)
    subscription.add column.onDidChangeOption => @requestUpdate(true)

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
    @requestUpdate(true)
    @makeRowVisible(position.row)

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

    @requestUpdate(true)
    @makeRowVisible(@activeCellPosition.row)

  moveLeft: ->
    if @activeCellPosition.column - 1 >= 0
      @activeCellPosition.column--
    else
      @activeCellPosition.column = @getLastColumn()

      if @activeCellPosition.row - 1 >= 0
        @activeCellPosition.row--
      else
        @activeCellPosition.row = @getLastRow()

    @requestUpdate(true)
    @makeRowVisible(@activeCellPosition.row)

  moveUp: ->
    if @activeCellPosition.row - 1 >= 0
      @activeCellPosition.row--
    else
      @activeCellPosition.row = @getLastRow()

    @requestUpdate(true)
    @makeRowVisible(@activeCellPosition.row)

  moveDown: ->
    if @activeCellPosition.row + 1 < @table.getRowsCount()
      @activeCellPosition.row++
    else
      @activeCellPosition.row = 0

    @requestUpdate(true)
    @makeRowVisible(@activeCellPosition.row)

  moveToTop: ->
    return if @activeCellPosition.row is 0

    @activeCellPosition.row = 0
    @requestUpdate(true)
    @makeRowVisible(@activeCellPosition.row)

  moveToBottom: ->
    end = @getLastRow()
    return if @activeCellPosition.row is end

    @activeCellPosition.row = end
    @requestUpdate(true)
    @makeRowVisible(@activeCellPosition.row)

  pageDown: ->
    amount = @getPageMovesAmount()
    if @activeCellPosition.row + amount < @table.getRowsCount()
      @activeCellPosition.row += amount
    else
      @activeCellPosition.row = @getLastRow()

    @requestUpdate(true)
    @makeRowVisible(@activeCellPosition.row)

  pageUp: ->
    amount = @getPageMovesAmount()
    if @activeCellPosition.row - amount >= 0
      @activeCellPosition.row -= amount
    else
      @activeCellPosition.row = 0

    @requestUpdate(true)
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

  getSelection: ->
    new Range(@activeCellPosition, @activeCellPosition)

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
      @requestUpdate()

    @body.scrollTop()

  requestUpdate: (forceUpdate=false) =>
    @hasChanged = forceUpdate

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
