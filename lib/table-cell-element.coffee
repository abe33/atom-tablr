
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
    @dataset.row = row
    @dataset.column = column
    @style.cssText = """
      width: #{@tableEditor.getScreenColumnWidthAt(column)}px;
      left: #{@tableEditor.getScreenColumnOffsetAt(column)}px;
      height: #{@tableEditor.getScreenRowHeightAt(row)}px;
      top: #{@tableEditor.getScreenRowOffsetAt(row)}px;
      text-align: #{@tableEditor.getScreenColumnAlignAt(column)};
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
    if @tableElement.isCursorCell([row, column])
      classes.push 'active'
    else if @tableElement.isCursorColumn(column)
      classes.push 'active-column'
    else if @tableElement.isCursorRow(row)
      classes.push 'active-row'

    classes.push 'selected' if @tableElement.isSelectedCell([row, column])

    classes.push 'order' if @tableElement.order is cell.column.name

    classes

module.exports = TableCellElement = document.registerElement 'atom-table-cell', prototype: TableCellElement.prototype
