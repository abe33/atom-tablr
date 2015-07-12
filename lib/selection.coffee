
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

  expandLeft: ->
    @range.start.column = Math.max(0, @range.start.column - 1)

  expandRight: ->
    @range.end.column = Math.min(@tableEditor.getScreenColumnCount(), @range.end.column + 1)

  expandUp: ->
    @range.start.row = Math.max(0, @range.start.row - 1)

  expandDown: ->
    @range.end.row = Math.min(@tableEditor.getScreenRowCount(), @range.end.row + 1)

  spanMoreThanOneCell: -> @range.spanMoreThanOneCell()

  resetRangeOnCursor: ->
    @range = @cursor.getRange()
