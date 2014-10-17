{Emitter} = require 'event-kit'
PropertyAccessors = require 'property-accessors'
Identifiable = require './mixins/identifiable'

module.exports =
class Column
  Identifiable.includeInto(this)
  PropertyAccessors.includeInto(this)  

  @::accessor 'width', get: -> @options.width
  @::accessor 'align', get: -> @options.align

  constructor: ({@name, @options}={options: {}}) ->
    @initID()

    @emitter = new Emitter

  onDidChangeName: (callback) ->
    @emitter.on 'did-change-name', callback

  onDidChangeOption: (callback) ->
    @emitter.on 'did-change-option', callback

  setName: (newName) ->
    oldName = @name
    @name = newName

    @emitter.emit 'did-change-name', {oldName, newName, column: this}

  setWidth: (newWidth) ->
    oldWidth = @width
    @options.width = newWidth

    @emitter.emit 'did-change-option', {
      option: 'width'
      oldValue: oldWidth
      newValue: newWidth
      column: this
    }
