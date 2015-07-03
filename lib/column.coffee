{Emitter} = require 'event-kit'
PropertyAccessors = require 'property-accessors'
Identifiable = require './mixins/identifiable'

module.exports =
class Column
  Identifiable.includeInto(this)
  PropertyAccessors.includeInto(this)

  @::accessor 'name',
    get: -> @options.name
    set: (newName) ->
      oldName = @name
      @setOption 'name', newName
      @emitter.emit 'did-change-name', {oldName, newName, column: this}

  @::accessor 'width',
    get: -> @options.width
    set: (newWidth) -> @setOption 'width', newWidth

  @::accessor 'align',
    get: -> @options.align
    set: (newAlign) -> @setOption 'align', newAlign

  @::accessor 'cellRender',
    get: -> @options.cellRender
    set: (newCellRender) -> @setOption 'cellRender', newCellRender

  constructor: (@options={}) ->
    @initID()

    @emitter = new Emitter

  onDidChangeName: (callback) ->
    @emitter.on 'did-change-name', callback

  onDidChangeOption: (callback) ->
    @emitter.on 'did-change-option', callback

  setOption: (name, newValue, cancelEvent=false) ->
    oldValue = @[name]
    @options[name] = newValue

    unless cancelEvent
      @emitter.emit 'did-change-option', {
        option: name
        column: this
        oldValue
        newValue
      }
