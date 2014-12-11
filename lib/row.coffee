PropertyAccessors = require 'property-accessors'
Identifiable = require './mixins/identifiable'

module.exports =
class Row
  PropertyAccessors.includeInto(this)
  Identifiable.includeInto(this)

  @::accessor 'height',
    get: -> @options.height
    set: (height) -> @options.height = height

  constructor: ({@cells, @table, @options}={}) ->
    @options ||= {}
    @initID()
    @cells ||= []

    @createCellAccessor(cell) for cell in @cells

  getValues: -> @cells.map (cell) -> cell.getValue()

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

    cell.row = this
    @createCellAccessor(cell)

  removeCellAt: (index) ->
    cell = @cells[index]
    @destroyCellAccessor(cell)
    @cells.splice(index, 1)
    delete cell.row

  cellByColumnName: (name) ->
    @cells.filter((cell) -> cell.getColumn().name is name)[0]

  createCellAccessor: (cell) ->
    name = cell.getColumn().name
    cell.row = this
    @accessor name,
      configurable: true
      get: -> cell.getValue()
      set: (newValue) -> @setProperty(cell, newValue)

  setProperty: (cell, newValue, transaction=true) ->
    cell = @cellByColumnName(cell) if typeof cell is 'string'
    cell.setValue(newValue, transaction)

  cellUpdated: (cell, oldValue, newValue, transaction=true) ->
    @table.rowUpdated({row: this, cell, oldValue, newValue, transaction})

  destroyCellAccessor: (cell) ->
    delete @[cell.getColumn().name]

  updateCellAccessorName: (oldName, newName) ->
    cell = @cellByColumnName(newName)

    delete @[oldName]
    @createCellAccessor(cell)
