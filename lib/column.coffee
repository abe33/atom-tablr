{Emitter} = require 'event-kit'
PropertyAccessors = require 'property-accessors'
Identifiable = require './mixins/identifiable'

module.exports =
class Column
  Identifiable.includeInto(this)
  PropertyAccessors.includeInto(this)

  @::accessor 'name', get: -> @options.name
  @::accessor 'width', get: -> @options.width
  @::accessor 'align', get: -> @options.align

  constructor: (@options={}) ->
    @initID()

    @emitter = new Emitter

  onDidChangeName: (callback) ->
    @emitter.on 'did-change-name', callback

  onDidChangeOption: (callback) ->
    @emitter.on 'did-change-option', callback

  setName: (newName) ->
    oldName = @name
    @setOption 'name', newName
    @emitter.emit 'did-change-name', {oldName, newName, column: this}

  setWidth: (newWidth) -> @setOption 'width', newWidth

  setAlign: (newAlign) -> @setOption 'align', newAlign

  setOption: (name, newValue) ->
    oldValue = @[name]
    @options[name] = newValue

    @emitter.emit 'did-change-option', {
      option: name
      column: this
      oldValue
      newValue
    }
