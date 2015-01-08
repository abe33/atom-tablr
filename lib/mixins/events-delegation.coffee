Mixin = require 'mixto'
{Disposable} = require 'event-kit'

eachPair = (object, callback) -> callback(k,v) for k,v of object

module.exports =
class EventsDelegation extends Mixin
  subscribeTo: (object, selector, events) ->
    return unless object?

    @eventsMap ?= new WeakMap
    @eventsMap.set(object, {}) unless @eventsMap.get(object)?

    eventsForObject = @eventsMap.get(object)

    [events, selector] = [selector, null] if typeof selector is 'object'
    selector = '__NONE__' unless selector?

    eachPair events, (event, callback) =>
      unless eventsForObject[event]?
        eventsForObject[event] = {}
        @createEventListener(object, event)

      eventsForObject[event][selector] = callback

  createEventListener: (object, event) ->
    listener = (e) =>
      eventsForObject = @eventsMap.get(object)[event]

      {target} = e
      for selector,callback of eventsForObject
        continue if selector is '__NONE__'

        if target.matches(selector)
          callback(e)
          return true

      eventsForObject['__NONE__']?(e)
      return true

    object.addEventListener event, listener
    @subscriptions.add new Disposable ->
      object.removeEventListener event, listener

  addEventDisposable: (object, event, listener) ->
    object.addEventListener event, listener
    new Disposable -> object.removeEventListener event, listener
