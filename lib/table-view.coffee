{View} = require 'atom'
{CompositeDisposable} = require 'event-kit'
React = require 'react-atom-fork'
TableComponent = require './table-component'

module.exports =
class TableView extends View
  @content: ->
    @div class: 'table-edit', =>
      @table outlet: 'tableHeaderView', class: 'table-edit-header'
      @div outlet: 'scrollView', class: 'scroll-view', =>
        @div outlet: 'tableNode', class: 'table'

  initialize: (@table) ->
    @subscriptions = new CompositeDisposable

    props = {@table, parentView: this}
    @component = React.renderComponent(TableComponent(props), @tableNode[0])

    # node = @component.getDOMNode()

    @subscriptions.add @table.onDidChangeRows @requestUpdate

  destroy: ->
    @subscriptions.dispose()
    @remove()

  getRowHeight: -> @rowHeight

  setRowHeight: (@rowHeight) ->

  getRowOverdraw: -> @rowOverdraw or 0

  setRowOverdraw: (@rowOverdraw) ->

  getFirstVisibleRow: ->
    scrollTop = @scrollView.scrollTop()
    row = Math.floor(scrollTop / @getRowHeight())

  getLastVisibleRow: ->
    scrollTop = @scrollView.scrollTop()
    scrollViewHeight = @scrollView.height()

    row = Math.floor((scrollTop + scrollViewHeight) / @getRowHeight())

  scrollTop: (scrollTop) -> @scrollView.scrollTop(scrollTop)

  requestUpdate: =>
    return if @updateRequested

    @updateRequested = true
    requestAnimationFrame =>
      @update()
      @updateRequested = false

  update: =>
    firstVisibleRow = @getFirstVisibleRow()
    lastVisibleRow = @getLastVisibleRow()
    firstRow = Math.max 0, firstVisibleRow - @rowOverdraw
    lastRow = Math.min @table.getRowsCount(), lastVisibleRow + @rowOverdraw

    console.log firstVisibleRow, lastVisibleRow, @rowOverdraw

    @component.setState({firstRow, lastRow})
