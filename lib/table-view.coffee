{View, Point} = require 'atom'
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
    @subscriptions = new CompositeDisposable

    props = {@table, parentView: this}
    @bodyComponent = React.renderComponent(TableComponent(props), @body[0])
    @headComponent = React.renderComponent(TableHeaderComponent(props), @head[0])

    @subscriptions.add @table.onDidChangeRows @requestUpdate
    @subscriptions.add @table.onDidAddColumn @onColumnAdded
    @subscriptions.add @table.onDidRemoveColumn @onColumnRemoved

    @subscriptions.add @asDisposable @body.on 'scroll', @requestUpdate

    @subscriptions.add @asDisposable @on 'core:move-left', => @moveLeft()
    @subscriptions.add @asDisposable @on 'core:move-right', => @moveRight()
    @subscriptions.add @asDisposable @on 'core:move-up', => @moveUp()
    @subscriptions.add @asDisposable @on 'core:move-down', => @moveDown()
    @subscriptions.add @asDisposable @on 'mousedown', (e) =>
      e.preventDefault()
      @hiddenInput.focus() unless document.activeElement is @hiddenInput.element

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

  #     ######   #######  ##    ## ######## ########   #######  ##
  #    ##    ## ##     ## ###   ##    ##    ##     ## ##     ## ##
  #    ##       ##     ## ####  ##    ##    ##     ## ##     ## ##
  #    ##       ##     ## ## ## ##    ##    ########  ##     ## ##
  #    ##       ##     ## ##  ####    ##    ##   ##   ##     ## ##
  #    ##    ## ##     ## ##   ###    ##    ##    ##  ##     ## ##
  #     ######   #######  ##    ##    ##    ##     ##  #######  ########

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

  moveUp: ->
    if @activeCellPosition.row - 1 >= 0
      @activeCellPosition.row--
    else
      @activeCellPosition.row = @table.getRowsCount() - 1

    @requestUpdate(true)

  moveDown: ->
    if @activeCellPosition.row + 1 < @table.getRowsCount()
      @activeCellPosition.row++
    else
      @activeCellPosition.row = 0

    @requestUpdate(true)


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
