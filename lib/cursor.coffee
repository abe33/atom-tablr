{Point} = require 'atom'
Range = require './range'

module.exports =
class Cursor
  constructor: ({@tableEditor, @position}) ->
    @position ?= new Point()

  getPosition: ->
    @position

  getRange: ->
    new Range(@position, {
      row: Math.min(@tableEditor.getScreenRowCount(), @position.row + 1)
      column: Math.min(@tableEditor.getScreenColumnCount(), @position.column + 1)
    })

  moveUp: ->
    newRow = @position.row - 1
    newRow = @tableEditor.getScreenRowCount() - 1 if newRow < 0

    @position.row = newRow
    @selection.resetRangeOnCursor()

  moveDown: ->
    newRow = @position.row + 1
    newRow = 0 if newRow >= @tableEditor.getScreenRowCount()

    @position.row = newRow
    @selection.resetRangeOnCursor()

  moveLeft: ->
    newColumn = @position.column - 1
    newColumn = @tableEditor.getScreenColumnCount() - 1 if newColumn < 0

    @position.column = newColumn
    @selection.resetRangeOnCursor()

  moveRight: ->
    newColumn = @position.column + 1
    newColumn = 0 if newColumn >= @tableEditor.getScreenColumnCount()

    @position.column = newColumn
    @selection.resetRangeOnCursor()
