{View} = require 'atom'

module.exports =
class TableView extends View
  @content: ->
    @div class: 'table-edit', =>
      @table outlet: 'tableHeaderView', class: 'table-edit-header'
      @div outlet: 'scrollView', class: 'scroll-view', =>
        @table outlet: 'tableView', class: 'table'

  initialize: (@table) ->

  destroy: ->
    @remove()

  getRowHeight: -> @rowHeight

  setRowHeight: (@rowHeight) ->

  getRowOverdraw: -> @rowOverdraw

  setRowOverdraw: (@rowOverdraw) ->

  getFirstVisibleRow: ->
    scrollTop = @scrollView.scrollTop()
    row = Math.floor(scrollTop / @getRowHeight())

  getLastVisibleRow: ->
    scrollTop = @scrollView.scrollTop()
    scrollViewHeight = @scrollView.height()

    row = Math.floor((scrollTop + scrollViewHeight) / @getRowHeight())
