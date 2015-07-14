{Point, Emitter} = require 'atom'
Range = require './range'

module.exports =
class Cursor
  constructor: ({@tableEditor, @position}) ->
    @position ?= new Point()
    @emitter = new Emitter

  onDidChangePosition: (callback) ->
    @emitter.on 'did-change-position', callback

  onDidDestroy: (callback) ->
    @emitter.on 'did-destroy', callback

  destroy: ->
    @tableEditor.removeCursor(this)
    @emitter.emit('did-destroy', this)

  getPosition: -> @position

  getValue: -> @tableEditor.getValueAtScreenPosition(@getPosition())

  setPosition: (position, resetSelection=true) ->
    @position = Point.fromObject(position)
    @cursorMoved(resetSelection)

  getRange: ->
    new Range(@position, {
      row: Math.min(@tableEditor.getScreenRowCount(), @position.row + 1)
      column: Math.min(@tableEditor.getScreenColumnCount(), @position.column + 1)
    })

  moveUp: ->
    newRow = @position.row - 1
    newRow = @tableEditor.getScreenRowCount() - 1 if newRow < 0

    @position.row = newRow
    @cursorMoved()

  moveDown: ->
    newRow = @position.row + 1
    newRow = 0 if newRow >= @tableEditor.getScreenRowCount()

    @position.row = newRow
    @cursorMoved()

  moveLeft: ->
    newColumn = @position.column - 1
    newColumn = @tableEditor.getScreenColumnCount() - 1 if newColumn < 0

    @position.column = newColumn
    @cursorMoved()

  moveRight: ->
    newColumn = @position.column + 1
    newColumn = 0 if newColumn >= @tableEditor.getScreenColumnCount()

    @position.column = newColumn
    @cursorMoved()

  cursorMoved: (resetSelection=true) ->
    @selection.resetRangeOnCursor() if resetSelection
    eventObject = cursor: this
    @emitter.emit 'did-change-position', eventObject
    @tableEditor.emitter.emit 'did-change-cursor-position', eventObject
