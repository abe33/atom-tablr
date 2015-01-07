{$} = require 'atom-space-pen-views'

objectCenterCoordinates = (obj) ->
  {top, left} = obj.offset()
  {x: left + obj.width() / 2, y: top + obj.height() / 2}

module.exports =
  mousedown: (obj, x, y) ->
    {x,y} = objectCenterCoordinates(obj) unless x? and y?
    event = $.Event "mousedown", {
      which: 1
      pageX: x
      pageY: y
    }

    obj.trigger(event)

  mousemove: (obj, x, y) ->
    {x,y} = objectCenterCoordinates(obj) unless x? and y?
    event = $.Event "mousemove", {
      which: 1
      pageX: x
      pageY: y
    }

    obj.trigger(event)

  mouseup: (obj, x, y) ->
    {x,y} = objectCenterCoordinates(obj) unless x? and y?
    event = $.Event "mouseup", {
      which: 1
      pageX: x
      pageY: y
    }

    obj.trigger(event)

  mousewheel: (obj, x, y) ->
    {x,y} = objectCenterCoordinates(obj) unless x? and y?
    event = $.Event "mousewheel", {
      which: 1
      pageX: x
      pageY: y
    }

    obj.trigger(event)

  textInput: (obj, data) ->
    event = $.Event "textInput", {
      originalEvent:
        data: data
    }

    obj.trigger(event)

  objectCenterCoordinates: objectCenterCoordinates
