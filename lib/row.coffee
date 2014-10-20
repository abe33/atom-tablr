PropertyAccessors = require 'property-accessors'
Identifiable = require './mixins/identifiable'

module.exports =
class Row
  PropertyAccessors.includeInto(this)
  Identifiable.includeInto(this)

  constructor: ({@cells, @table}={}) ->
    @initID()
    @cells ||= []

    @createCellAccessor(cell) for cell in @cells

  getValues: ->  @cells.map (cell) -> cell.getValue()

  getCells: -> @cells

  getCell: (index) -> @cells[index]

  getCellsCount: -> @cells.length

  addCell: (cell) ->
    @addCellAt(@cells.length, cell)

  eachCell: (block) -> block(cell,i) for cell,i in @cells

  addCellAt: (index, cell) ->
    if index < 0
      throw new Error "Can't add cell at index #{index}"

    if index >= @cells.length
      @cells.push cell
    else
      @cells.splice index, 0, cell

    @createCellAccessor(cell)

  removeCellAt: (index) ->
    @destroyCellAccessor(@cells[index])
    @cells.splice(index, 1)

  cellByColumnName: (name) ->
    @cells.filter((cell) -> cell.getColumn().name is name)[0]

  createCellAccessor: (cell) ->
    @accessor cell.getColumn().name,
      configurable: true
      get: -> cell.getValue()
      set: (value) ->
        cell.setValue(value)
        @table.rowUpdated(this)

  destroyCellAccessor: (cell) ->
    delete @[cell.getColumn().name]

  updateCellAccessorName: (oldName, newName) ->
    cell = @cellByColumnName(newName)

    delete @[oldName]
    @createCellAccessor(cell)
