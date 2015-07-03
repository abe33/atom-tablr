
module.exports =
class TableCellElement extends HTMLElement
  setModel: (@model) ->
    @released = false
    {cell, column, row} = @model
    if cell.column.cellRender?
      @innerHTML = cell.column.cellRender(cell, [row, column])
    else
      @textContent = cell.value ? @tableElement.getUndefinedDisplay()

    @className = @getCellClasses(cell, column, row).join(' ')
    @dataset.rowId = row + 1
    @dataset.columnId = column + 1
    @style.cssText = """
      width: #{@tableElement.getScreenColumnWidthAt(column)}px;
      left: #{@tableElement.getScreenColumnOffsetAt(column)}px;
      height: #{@tableElement.getScreenRowHeightAt(row)}px;
      top: #{@tableElement.getScreenRowOffsetAt(row)}px;
      text-align: #{@tableElement.getColumnAlign(column) ? 'left'};
    """

  isReleased: -> @released

  release: (dispatchEvent=true) ->
    return if @released
    @style.cssText = 'display: none;'
    delete @dataset.rowId
    delete @dataset.columnId
    @released = true

  getCellClasses: (cell, column, row) ->
    classes = ['table-edit-cell']
    if @tableElement.isActiveCell(cell)
      classes.push 'active'
    else if @tableElement.isActiveColumn(column)
      classes.push 'active-column'
    else if @tableElement.isActiveRow(row)
      classes.push 'active-row'

    classes.push 'selected' if @tableElement.isSelectedPosition([row, column])

    classes.push 'order' if @tableElement.order is cell.getColumn().name

    classes

module.exports = TableCellElement = document.registerElement 'atom-table-cell', prototype: TableCellElement.prototype
