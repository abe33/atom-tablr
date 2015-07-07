Mixin = require 'mixto'

module.exports =
class ColumnsAxis extends Mixin
  getActiveColumn: ->
    @table.getColumn(@activeCellPosition.column)

  isActiveColumn: (column) ->
    @activeCellPosition.column is column

  isSelectedColumn: (column) ->
    @selection.start.column <= column <= @selection.end.column

  getContentWidth: ->
    lastIndex = @getLastColumn()
    return 0 if lastIndex < 1

    @getScreenColumnOffsetAt(lastIndex) + @getScreenColumnWidthAt(lastIndex)

  getColumnWidth: ->
    @columnWidth ? @configColumnWidth

  getMinimumColumnWidth: ->
    @minimumColumnWidth ? @configMinimumColumnWidth

  setColumnWidth: (@columnWidth) ->
    @computeColumnOffsets()
    @requestUpdate()

  getColumnWidthAt: (index) ->
    @table.getColumn(index)?.width ? @getColumnWidth()

  setColumnWidthAt: (index, width) ->
    minWidth = @getMinimumColumnWidth()
    width = minWidth if width < minWidth
    @table.getColumn(index)?.width = width

  getColumnOffsetAt: (index) -> @getScreenColumnOffsetAt(@modelColumnToScreenColumn(index))

  getColumnOverdraw: -> @columnOverdraw ? @configColumnOverdraw

  setColumnOverdraw: (@columnOverdraw) -> @requestUpdate()

  getLastColumn: -> @table.getColumnsCount() - 1

  getFirstVisibleColumn: ->
    @findColumnAtPosition(@getColumnsScrollContainer().scrollLeft)

  getLastVisibleColumn: ->
    scrollViewWidth = @getColumnsScrollContainer().clientWidth

    @findColumnAtPosition(@getColumnsScrollContainer().scrollLeft + scrollViewWidth)

  getScreenColumns: -> @screenColumns

  getScreenColumn: (column) ->
    @table.getColumn(@screenColumnToModelColumn(column))

  getScreenColumnWidthAt: (column) ->
    @getColumnWidthAt(@screenColumnToModelColumn(column))

  setScreenColumnWidthAt: (column, width) ->
    @setColumnWidthAt(@screenColumnToModelColumn(column), width)

  getScreenColumnOffsetAt: (column) ->
    @columnOffsets[column]

  deleteActiveColumn: ->
    confirmation = atom.confirm
      message: 'Are you sure you want to delete the current active column?'
      detailedMessage: "You are deleting the column ##{@activeCellPosition.column + 1}."
      buttons: ['Delete Column', 'Cancel']

    @table.removeColumnAt(@activeCellPosition.column) if confirmation is 0

  screenColumnToModelColumn: (column) -> @screenToModelColumnsMap[column]

  modelColumnToScreenColumn: (column) -> @modelToScreenColumnsMap[column]

  makeColumnVisible: (column) ->
    container = @getColumnsScrollContainer()
    columnWidth = @getScreenColumnWidthAt(column)

    scrollViewWidth = container.offsetWidth
    currentScrollLeft = container.scrollLeft

    columnOffset = @getScreenColumnOffsetAt(column)

    scrollLeftAsFirstVisibleColumn = columnOffset
    scrollLeftAsLastVisibleColumn = columnOffset - (scrollViewWidth - columnWidth)

    return if scrollLeftAsFirstVisibleColumn >= currentScrollLeft and
              scrollLeftAsFirstVisibleColumn + columnWidth <= currentScrollLeft + scrollViewWidth

    if columnOffset > currentScrollLeft
      container.scrollLeft = scrollLeftAsLastVisibleColumn
    else
      container.scrollLeft = scrollLeftAsFirstVisibleColumn

  computeColumnOffsets: ->
    offsets = []
    offset = 0

    for i in [0...@table.getColumnsCount()]
      offsets.push offset
      offset += @getScreenColumnWidthAt(i)

    @columnOffsets = offsets

  columnScreenPosition: (column) ->
    left = @getScreenColumnOffsetAt(column)

    content = @getColumnsScrollContainer()
    contentOffset = content.getBoundingClientRect()

    left + contentOffset.left

  findColumnAtPosition: (x) ->
    for i in [0...@table.getColumnsCount()]
      offset = @getScreenColumnOffsetAt(i)
      return i - 1 if x < offset

    return @table.getColumnsCount() - 1

  findColumnAtScreenPosition: (x) ->
    content = @getColumnsOffsetContainer()

    bodyOffset = content.getBoundingClientRect()

    x -= bodyOffset.left

    @findColumnAtPosition(x)

  updateScreenColumns: ->
    columns = @table.getColumns()
    @screenColumns = columns.concat()
    @screenColumns.sort(@compareColumns(@order, @direction)) if @order?
    @screenToModelColumnsMap = (columns.indexOf(column) for column in @screenColumns)
    @modelToScreenColumnsMap = (@screenColumns.indexOf(column) for column in columns)
    @computeColumnOffsets()

  compareColumns: (order, direction) -> (a,b) ->
    a = a[order]
    b = b[order]
    if a > b
      direction
    else if a < b
      -direction
    else
      0
