PropertyAccessors = require 'property-accessors'

module.exports =
class Row
  PropertyAccessors.includeInto(this)

  constructor: ({@cells, @table}={cells: []}) ->
    @createCellAccessor(cell) for cell in @cells

  getCells: -> @cells

  createCellAccessor: (cell) ->
    @accessor cell.getColumn().name,
      configurable: true
      get: -> cell.getValue()
      set: (value) -> cell.setValue(value)
