{Emitter} = require 'event-kit'
Identifiable = require './mixins/identifiable'

module.exports =
class Column
  Identifiable.includeInto(this)

  constructor: ({@name, @options}={options: {}}) ->
    @initID()

    @emitter = new Emitter

  onDidChangeName: (callback) ->
    @emitter.on 'did-change-name', callback

  setName: (newName) ->
    oldName = @name
    @name = newName

    @emitter.emit 'did-change-name', {oldName, newName, column: this}
