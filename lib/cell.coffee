
module.exports =
class Cell
  constructor: ({@value, @column}) ->
    @value ||= @column.options.default
    @value = null if typeof @value is 'undefined'

  getColumn: -> @column
  getValue: -> @value
