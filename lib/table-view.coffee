{View, Point, TextEditorView} = require 'atom'
{CompositeDisposable, Disposable} = require 'event-kit'
React = require 'react-atom-fork'
TableComponent = require './table-component'
TableHeaderComponent = require './table-header-component'

module.exports =
class TableView extends View
  @content: ->
    @div class: 'table-edit', =>
      @input type: 'text', class: 'hidden-input', outlet: 'hiddenInput'
      @div outlet: 'head', class: 'table-edit-header', =>
      @div outlet: 'body', class: 'scroll-view', =>

  initialize: (@table) ->
    @scroll = 0
    @activeCellPosition = new Point

    props = {@table, parentView: this}
    @bodyComponent = React.renderComponent(TableComponent(props), @body[0])
    @headComponent = React.renderComponent(TableHeaderComponent(props), @head[0])

    @subscriptions = new CompositeDisposable
    @subscriptions.add @table.onDidChangeRows @requestUpdate
    @subscriptions.add @table.onDidAddColumn @onColumnAdded
    @subscriptions.add @table.onDidRemoveColumn @onColumnRemoved

    @subscriptions.add @asDisposable @body.on 'scroll', @requestUpdate

    @subscriptions.add @asDisposable @on 'core:confirm', => @startEdit()
    @subscriptions.add @asDisposable @on 'core:move-left', => @moveLeft()
    @subscriptions.add @asDisposable @on 'core:move-right', => @moveRight()
    @subscriptions.add @asDisposable @on 'core:move-up', => @moveUp()
    @subscriptions.add @asDisposable @on 'core:move-down', => @moveDown()
    @subscriptions.add @asDisposable @on 'mousedown', (e) =>
      e.preventDefault()

      if position = @cellPositionAtScreenPosition(e.pageX, e.pageY)
        @activateCellAtPosition position

      @focus()

    @subscribeToColumn(column) for column in @table.getColumns()

  destroy: ->
    @subscriptions.dispose()
    @remove()

  #    ########   #######  ##      ##  ######
  #    ##     ## ##     ## ##  ##  ## ##    ##
  #    ##     ## ##     ## ##  ##  ## ##
  #    ########  ##     ## ##  ##  ##  ######
  #    ##   ##   ##     ## ##  ##  ##       ##
  #    ##    ##  ##     ## ##  ##  ## ##    ##
  #    ##     ##  #######   ###  ###   ######

  getRowHeight: -> @rowHeight

  setRowHeight: (@rowHeight) -> @requestUpdate(true)

  getRowOverdraw: -> @rowOverdraw or 0

  setRowOverdraw: (@rowOverdraw) -> @requestUpdate(true)

  getFirstVisibleRow: ->
    row = Math.floor(@body.scrollTop() / @getRowHeight())

  getLastVisibleRow: ->
    scrollViewHeight = @body.height()

    row = Math.floor((@body.scrollTop() + scrollViewHeight) / @getRowHeight())

  isActiveRow: (row) -> @activeCellPosition.row is row

  makeRowVisible: (row) ->
    rowHeight = @getRowHeight()
    scrollViewHeight = @body.height()
    currentScrollTop = @body.scrollTop()

    scrollTopAsFirstVisibleRow = row * rowHeight
    scrollTopAsLastVisibleRow = row * rowHeight - (scrollViewHeight - rowHeight)

    return if scrollTopAsFirstVisibleRow >= currentScrollTop and
              scrollTopAsFirstVisibleRow + rowHeight <= currentScrollTop + scrollViewHeight

    difAsFirstVisibleRow = Math.abs(currentScrollTop - scrollTopAsFirstVisibleRow)
    difAsLastVisibleRow = Math.abs(currentScrollTop - scrollTopAsLastVisibleRow)

    if difAsLastVisibleRow < difAsFirstVisibleRow
      @body.scrollTop(scrollTopAsLastVisibleRow)
    else
      @body.scrollTop(scrollTopAsFirstVisibleRow)

  #     ######   #######  ##       ##     ## ##     ## ##    ##  ######
  #    ##    ## ##     ## ##       ##     ## ###   ### ###   ## ##    ##
  #    ##       ##     ## ##       ##     ## #### #### ####  ## ##
  #    ##       ##     ## ##       ##     ## ## ### ## ## ## ##  ######
  #    ##       ##     ## ##       ##     ## ##     ## ##  ####       ##
  #    ##    ## ##     ## ##       ##     ## ##     ## ##   ### ##    ##
  #     ######   #######  ########  #######  ##     ## ##    ##  ######

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
    @getColumnsWidthsFromModel().map (v) => v * @body.width()

  getColumnsScreenMargins: ->
    widths = @getColumnsWidthsFromModel()
    pad = 0
    margins = widths.map (v) =>
      res = pad
      pad += v * @body.width()
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
    height = @getRowHeight()

    {top, left, width, height}

  cellScreenPosition: (position) ->
    {top, left} = @cellScrollPosition(position)

    contentOffset = @body.offset()

    {
      top: top + contentOffset.top - @body.scrollTop(),
      left: left + contentOffset.left
    }

  cellScrollPosition: (position) ->
    position = Point.fromObject(position)
    margins = @getColumnsScreenMargins()
    {
      top: position.row * @getRowHeight()
      left: margins[position.column]
    }

  cellPositionAtScreenPosition: (x,y) ->
    return unless x? and y?

    bodyWidth = @body.width()
    bodyOffset = @body.offset()
    bodyScrollTop = @body.scrollTop()

    x -= bodyOffset.left
    y -= bodyOffset.top

    row = Math.floor((bodyScrollTop + y) / @getRowHeight())

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
      @activeCellPosition.column = @table.getColumnsCount() - 1

      if @activeCellPosition.row - 1 >= 0
        @activeCellPosition.row--
      else
        @activeCellPosition.row = @table.getRowsCount() - 1

    @requestUpdate(true)
    @makeRowVisible(@activeCellPosition.row)

  moveUp: ->
    if @activeCellPosition.row - 1 >= 0
      @activeCellPosition.row--
    else
      @activeCellPosition.row = @table.getRowsCount() - 1

    @requestUpdate(true)
    @makeRowVisible(@activeCellPosition.row)

  moveDown: ->
    if @activeCellPosition.row + 1 < @table.getRowsCount()
      @activeCellPosition.row++
    else
      @activeCellPosition.row = 0

    @requestUpdate(true)
    @makeRowVisible(@activeCellPosition.row)

  #    ######## ########  #### ########
  #    ##       ##     ##  ##     ##
  #    ##       ##     ##  ##     ##
  #    ######   ##     ##  ##     ##
  #    ##       ##     ##  ##     ##
  #    ##       ##     ##  ##     ##
  #    ######## ########  ####    ##

  startEdit: =>
    @createEditView() unless @editView?

    activeCell = @table.cellAtPosition(@activeCellPosition)
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

  stopEdit: ->
    @editView.hide()
    @focus()

  createEditView: ->
    @editView = new TextEditorView({})
    @subscribeToTextEditor(@editView)
    @append(@editView)

  subscribeToTextEditor: (editorView) ->
    @subscriptions.add @asDisposable editorView.on 'core:cancel', (e) =>
      @stopEdit()
      e.stopImmediatePropagation()
      false

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

    firstRow = Math.max 0, firstVisibleRow - @rowOverdraw
    lastRow = Math.min @table.getRowsCount(), lastVisibleRow + @rowOverdraw

    @bodyComponent.setState {
      firstRow
      lastRow
      rowHeight: @getRowHeight()
      columnsWidths: @getColumnsWidths()
      columnsAligns: @getColumnsAligns()
      totalRows: @table.getRowsCount()
    }
    @headComponent.setState {
      columnsWidths: @getColumnsWidths()
      columnsAligns: @getColumnsAligns()
    }

    @firstRenderedRow = firstRow
    @lastRenderedRow = lastRow
    @hasChanged = false

  asDisposable: (subscription) -> new Disposable -> subscription.off()

  floatToPercent: (w) -> "#{Math.round(w * 10000) / 100}%"
