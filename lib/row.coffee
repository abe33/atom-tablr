PropertyAccessors = require 'property-accessors'

module.exports =
class Row
  PropertyAccessors.includeInto(this)

  constructor: ({@cells, @table}={cells: []}) ->
    @createCellAccessor(cell) for cell in @cells

  getCells: -> @cells

  getCellsCount: -> @cells.length

  addCell: (cell) ->
    @cells.push cell
    @createCellAccessor(cell)

  removeCellAt: (index) ->
    @destroyCellAccessor(@cells[index])
    @cells.splice(index, 1)

  createCellAccessor: (cell) ->
    @accessor cell.getColumn().name,
      configurable: true
      get: -> cell.getValue()
      set: (value) -> cell.setValue(value)

  destroyCellAccessor: (cell) ->
    delete @[cell.getColumn().name]
