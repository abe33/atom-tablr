{Emitter} = require 'atom'

module.exports =
class CursorSelectionBinding
  constructor: ({@cursor, @selection}) ->
    @emitter = new Emitter

  onDidDestroy: (callback) ->
    @emitter.on 'did-destroy', callback

  destroy: ->
    @emitter.emit 'did-destroy', this
    @emitter.dispose()
