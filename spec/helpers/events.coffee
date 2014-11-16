{$} = require 'atom'

module.exports =
  mousedown: (obj, x, y) ->
    event = $.Event "mousedown", {
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
