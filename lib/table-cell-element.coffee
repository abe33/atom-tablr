{registerOrUpdateElement} = require 'atom-utils'

module.exports =
class TableCellElement extends HTMLElement
  setModel: (@model) ->
    @released = false
    {cell, column, row} = @model

    @className = @getCellClasses(cell, column, row).join(' ')
    @dataset.row = row
    @dataset.column = column
    @style.cssText = """
      width: #{@tableEditor.getScreenColumnWidthAt(column)}px;
      left: #{@tableEditor.getScreenColumnOffsetAt(column)}px;
      height: #{@tableEditor.getScreenRowHeightAt(row)}px;
      top: #{@tableEditor.getScreenRowOffsetAt(row)}px;
      text-align: #{@tableEditor.getScreenColumnAlignAt(column)};
    """
    if cell.column.cellRender?
      @innerHTML = cell.column.cellRender(cell, [row, column])
    else
      @textContent = cell.value ? @tableElement.getUndefinedDisplay()

    @lastRow = row
    @lastColumn = column
    @lastValue = cell.value

  isReleased: -> @released

  release: (dispatchEvent=true) ->
    return if @released
    @style.cssText = 'display: none;'
    delete @dataset.rowId
    delete @dataset.columnId
    @released = true

  getCellClasses: (cell, column, row) ->
    classes = ['tablr-cell']
    classes.push 'active' if @tableElement.isCursorCell([row, column])
    classes.push 'selected' if @tableElement.isSelectedCell([row, column])
    classes

  isSameCell: (cell, column, row) ->
    cell.value is @lastValue and column is @lastColumn and row is @lastRow

module.exports =
TableCellElement =
registerOrUpdateElement 'tablr-cell', TableCellElement.prototype
