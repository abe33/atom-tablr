Mixin = require 'mixto'

module.exports =
class RowsAxis extends Mixin
  getActiveRow: ->
    @table.getRow(@activeCellPosition.row)

  isCursorRow: (row) ->
    @activeCellPosition.row is row

  isSelectedRow: (row) ->
    @selection.start.row <= row <= @selection.end.row

  getContentHeight: ->
    lastIndex = @getLastRow()
    return 0 if lastIndex < 1

    @getScreenRowOffsetAt(lastIndex) + @getScreenRowHeightAt(lastIndex)

  getRowHeight: ->
    @rowHeight ? @configRowHeight

  getMinimumRowHeight: ->
    @minimumRowHeight ? @configMinimumRowHeight

  setRowHeight: (@rowHeight) ->
    @computeRowOffsets()
    @requestUpdate()

  getRowHeightAt: (index) ->
    @table.getRow(index)?.height ? @getRowHeight()

  setRowHeightAt: (index, height) ->
    minHeight = @getMinimumRowHeight()
    height = minHeight if height < minHeight
    @table.getRow(index)?.height = height

  getRowOffsetAt: (index) -> @getScreenRowOffsetAt(@modelRowToScreenRow(index))

  getRowOverdraw: -> @rowOverdraw ? @configRowOverdraw

  setRowOverdraw: (@rowOverdraw) -> @requestUpdate()

  getLastRow: -> @table.getRowCount() - 1

  getFirstVisibleRow: ->
    @findRowAtPosition(@getRowsScrollContainer().scrollTop)

  getLastVisibleRow: ->
    scrollViewHeight = @getRowsScrollContainer().clientHeight

    @findRowAtPosition(@getRowsScrollContainer().scrollTop + scrollViewHeight)

  getScreenRows: -> @screenRows

  getScreenRow: (row) ->
    @table.getRow(@screenRowToModelRow(row))

  getScreenRowHeightAt: (row) ->
    @getRowHeightAt(@screenRowToModelRow(row))

  setScreenRowHeightAt: (row, height) ->
    @setRowHeightAt(@screenRowToModelRow(row), height)

  getScreenRowOffsetAt: (row) ->
    @rowOffsets[row]

  deleteActiveRow: ->
    confirmation = atom.confirm
      message: 'Are you sure you want to delete the current active row?'
      detailedMessage: "You are deleting the row ##{@activeCellPosition.row + 1}."
      buttons: ['Delete Row', 'Cancel']

    @table.removeRowAt(@activeCellPosition.row) if confirmation is 0

  screenRowToModelRow: (row) -> @screenToModelRowsMap[row]

  modelRowToScreenRow: (row) -> @modelToScreenRowsMap[row]

  makeRowVisible: (row) ->
    container = @getRowsScrollContainer()
    rowHeight = @getScreenRowHeightAt(row)

    scrollViewHeight = container.offsetHeight
    currentScrollTop = container.scrollTop

    rowOffset = @getScreenRowOffsetAt(row)

    scrollTopAsFirstVisibleRow = rowOffset
    scrollTopAsLastVisibleRow = rowOffset - (scrollViewHeight - rowHeight)

    return if scrollTopAsFirstVisibleRow >= currentScrollTop and
              scrollTopAsFirstVisibleRow + rowHeight <= currentScrollTop + scrollViewHeight

    if rowOffset > currentScrollTop
      container.scrollTop = scrollTopAsLastVisibleRow
    else
      container.scrollTop = scrollTopAsFirstVisibleRow

  computeRowOffsets: ->
    offsets = []
    offset = 0

    for i in [0...@table.getRowCount()]
      offsets.push offset
      offset += @getScreenRowHeightAt(i)

    @rowOffsets = offsets

  rowScreenPosition: (row) ->
    top = @getScreenRowOffsetAt(row)

    content = @getRowsScrollContainer()
    contentOffset = content.getBoundingClientRect()

    top + contentOffset.top

  findRowAtPosition: (y) ->
    for i in [0...@table.getRowCount()]
      offset = @getScreenRowOffsetAt(i)
      return i - 1 if y < offset

    return @table.getRowCount() - 1

  findRowAtScreenPosition: (y) ->
    content = @getRowsOffsetContainer()

    bodyOffset = content.getBoundingClientRect()

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
