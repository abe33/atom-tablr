_ = require 'underscore-plus'

mouseEvent = (type, properties={}) ->
  defaults = {
    bubbles: true
    cancelable: (type isnt "mousemove")
    view: window
    detail: 0
    pageX: 0
    pageY: 0
    clientX: 0
    clientY: 0
    ctrlKey: false
    altKey: false
    shiftKey: false
    metaKey: false
    button: 0
    relatedTarget: `undefined`
  }

  properties[k] = v for k,v of defaults when not properties[k]?

  new MouseEvent type, properties

inputEvent = (type, properties={}) ->

  event = new Event type, properties
  event.data = properties.data
  event

objectCenterCoordinates = (obj) ->
  {top, left, width, height} = obj.getBoundingClientRect()
  {x: left + width / 2, y: top + height / 2}

module.exports = {objectCenterCoordinates, mouseEvent, inputEvent}

['mousedown', 'mousemove', 'mouseup', 'click', 'dblclick'].forEach (key) ->
  module.exports[key] = (obj, x, y, cx, cy) ->
    if typeof x is 'object'
      options = x
      x = undefined
    else
      options = {}

    {x,y} = objectCenterCoordinates(obj) unless x? and y?

    unless cx? and cy?
      cx = x
      cy = y

    obj.dispatchEvent(mouseEvent key, _.extend(options, {pageX: x, pageY: y, clientX: cx, clientY: cy}))

module.exports.mousewheel = (obj, deltaX=0, deltaY=0) ->
  obj.dispatchEvent(mouseEvent 'mousewheel', {deltaX, deltaY})

module.exports.scroll = (obj, deltaX=0, deltaY=0) ->
  obj.dispatchEvent(mouseEvent 'scroll', {deltaX, deltaY})

module.exports.textInput = (obj, data) ->
  obj.dispatchEvent(inputEvent 'textInput', {data})
