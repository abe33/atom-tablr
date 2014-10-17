{View} = require 'atom'
{CompositeDisposable, Disposable} = require 'event-kit'
React = require 'react-atom-fork'
TableComponent = require './table-component'

module.exports =
class TableView extends View
  @content: ->
    @div class: 'table-edit', =>
      @table outlet: 'tableHeaderView', class: 'table-edit-header'
      @div outlet: 'scrollView', class: 'scroll-view', =>

  initialize: (@table) ->
    @subscriptions = new CompositeDisposable
    @scroll = 0

    props = {@table, parentView: this}
    @component = React.renderComponent(TableComponent(props), @scrollView[0])

    @subscriptions.add @table.onDidChangeRows @requestUpdate
    @subscriptions.add @table.onDidAddColumn @onColumnAdded
    @subscriptions.add @table.onDidRemoveColumn @onColumnRemoved

    @subscriptions.add @asDisposable @scrollView.on 'scroll', @requestUpdate

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
    row = Math.floor(@scrollView.scrollTop() / @getRowHeight())

  getLastVisibleRow: ->
    scrollViewHeight = @scrollView.height()

    row = Math.floor((@scrollView.scrollTop() + scrollViewHeight) / @getRowHeight())

  #     ######   #######  ##       ##     ## ##     ## ##    ##  ######
  #    ##    ## ##     ## ##       ##     ## ###   ### ###   ## ##    ##
  #    ##       ##     ## ##       ##     ## #### #### ####  ## ##
  #    ##       ##     ## ##       ##     ## ## ### ## ## ## ##  ######
  #    ##       ##     ## ##       ##     ## ##     ## ##  ####       ##
  #    ##    ## ##     ## ##       ##     ## ##     ## ##   ### ##    ##
  #     ######   #######  ########  #######  ##     ## ##    ##  ######

  getColumnsAligns: ->
    count = @table.getColumnsCount()
    res = (@table.getColumn(col).align for col in [0...count])
    console.log res
    res

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

  #    ##     ## ########  ########     ###    ######## ########
  #    ##     ## ##     ## ##     ##   ## ##      ##    ##
  #    ##     ## ##     ## ##     ##  ##   ##     ##    ##
  #    ##     ## ########  ##     ## ##     ##    ##    ######
  #    ##     ## ##        ##     ## #########    ##    ##
  #    ##     ## ##        ##     ## ##     ##    ##    ##
  #     #######  ##        ########  ##     ##    ##    ########

  scrollTop: (scroll) ->
    if scroll?
      @scrollView.scrollTop(scroll)
      @requestUpdate()

    @scrollView.scrollTop()

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

    @component.setState {
      firstRow
      lastRow
      rowHeight: @getRowHeight()
      columnsWidths: @getColumnsWidths()
      columnsAligns: @getColumnsAligns()
      totalRows: @table.getRowsCount()
    }

    @firstRenderedRow = firstRow
    @lastRenderedRow = lastRow
    @hasChanged = false

  asDisposable: (subscription) -> new Disposable -> subscription.off()

  floatToPercent: (w) -> "#{Math.round w * 100}%"
