Identifiable = require './mixins/identifiable'

module.exports =
class Column
  Identifiable.includeInto(this)

  constructor: ({@name, @options}={options: {}}) ->
    @initID()
