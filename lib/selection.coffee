
module.exports =
class Selection
  constructor: ({@range, @cursor, @tableEditor}) ->
    @cursor.selection = this
    @resetRangeOnCursor() unless @range?

  destroy: ->
    @tableEditor.removeSelection(this)

  getCursor: -> @cursor

  setCursor: (@cursor) ->

  getRange: -> @range

  setRange: (@range) ->

  isEmpty: -> @range.isEmpty()

  spanMoreThanOneCell: -> @range.spanMoreThanOneCell()

  resetRangeOnCursor: ->
    @range = @cursor.getRange()
