Identifiable = require './mixins/identifiable'

module.exports =
class Cell
  Identifiable.includeInto(this)

  constructor: ({@value, @column}) ->
    @initID()

    # @value ?= @column.options.default
    @value = null if typeof @value is 'undefined'

  getColumn: -> @column
  getValue: -> @value
  setValue: (newValue, transaction=true) ->
    oldValue = @value
    @value = newValue

    @row?.cellUpdated(this, oldValue, newValue, transaction)
