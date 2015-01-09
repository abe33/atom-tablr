Mixin = require 'mixto'
{Disposable} = require 'event-kit'

eachPair = (object, callback) -> callback(k,v) for k,v of object

NO_SELECTOR = '__NONE__'

module.exports =
class EventsDelegation extends Mixin
  subscribeTo: (object, selector, events) ->
    return unless object?

    @eventsMap ?= new WeakMap
    @eventsMap.set(object, {}) unless @eventsMap.get(object)?

    eventsForObject = @eventsMap.get(object)

    [events, selector] = [selector, null] if typeof selector is 'object'
    selector = NO_SELECTOR unless selector?

    eachPair events, (event, callback) =>
      unless eventsForObject[event]?
        eventsForObject[event] = {}
        @createEventListener(object, event)

      eventsForObject[event][selector] = callback

  createEventListener: (object, event) ->
    listener = (e) =>
      eventsForObject = @eventsMap.get(object)[event]

      {target} = e
      @eachSelector eventsForObject, (selector,callback) =>
        if @targetMatch(target, selector)
          callback(e)
          return true

      eventsForObject[NO_SELECTOR]?(e)
      return true

    object.addEventListener event, listener
    @subscriptions.add new Disposable ->
      object.removeEventListener event, listener

  eachSelector: (eventsForObject, callback) ->
    keys = Object.keys(eventsForObject)
    keys.sort (a,b) -> b.split(' ').length - a.split(' ').length
    keys.forEach (key) -> callback(key, eventsForObject[key])

  targetMatch: (target, selector) ->
    return true if target.matches(selector)

    parent = target.parentNode
    while parent? and parent.matches?
      return true if parent.matches(selector)
      parent = parent.parentNode

    false

  addEventDisposable: (object, event, listener) ->
    object.addEventListener event, listener
    new Disposable -> object.removeEventListener event, listener
