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

  bind: (@binding) ->
    {@selection} = @binding
    @bindingSubscription = @binding.onDidDestroy =>
      @emitter.emit('did-destroy', this)
      @emitter.dispose()
      @bindingSubscription.dispose()
      @binding = null
      @bindingSubscription = null
      @destroyed = null

  destroy: ->
    return if @isDestroyed()
    @binding.destroy()

  isDestroyed: -> @destroyed

  getPosition: -> @position

  getValue: -> @tableEditor.getValueAtScreenPosition(@getPosition())

  setPosition: (position, resetSelection=true) ->
    oldPosition = @position
    @position = Point.fromObject(position)
    @cursorMoved(oldPosition, resetSelection)

  getRange: ->
    new Range(@position, {
      row: Math.min(@tableEditor.getScreenRowCount(), @position.row + 1)
      column: Math.min(@tableEditor.getScreenColumnCount(), @position.column + 1)
    })

  moveUp: (delta=1) ->
    oldPosition = @position.copy()
    newRow = @position.row - delta
    newRow = @tableEditor.getScreenRowCount() - 1 if newRow < 0

    @position.row = newRow
    @cursorMoved(oldPosition)

  moveDown: (delta=1) ->
    oldPosition = @position.copy()
    newRow = @position.row + delta
    newRow = 0 if newRow >= @tableEditor.getScreenRowCount()

    @position.row = newRow
    @cursorMoved(oldPosition)

  moveLeft: (delta=1) ->
    oldPosition = @position.copy()
    newColumn = @position.column - delta

    if newColumn < 0
      newColumn = @tableEditor.getScreenColumnCount() - 1
      newRow = @position.row - 1
      newRow = @tableEditor.getScreenRowCount() - 1 if newRow < 0

      @position.row = newRow

    @position.column = newColumn
    @cursorMoved(oldPosition)

  moveRight: (delta=1) ->
    oldPosition = @position.copy()
    newColumn = @position.column + delta
    if newColumn >= @tableEditor.getScreenColumnCount()
      newColumn = 0
      newRow = @position.row + 1
      newRow = 0 if newRow >= @tableEditor.getScreenRowCount()

      @position.row = newRow

    @position.column = newColumn
    @cursorMoved(oldPosition)

  moveToTop: ->
    @moveUp(@position.row)

  moveToBottom: ->
    @moveDown(@tableEditor.getScreenRowCount() - @position.row - 1)

  moveToLeft: ->
    @moveLeft(@position.column)

  moveToRight: ->
    @moveRight(@tableEditor.getScreenColumnCount() - @position.column - 1)

  pageUp: ->
    oldPosition = @position.copy()
    newRow = @position.row - atom.config.get('table-edit.pageMovesAmount')
    @position.row = Math.max 0, newRow
    @cursorMoved(oldPosition) unless @position.isEqual(oldPosition)

  pageDown: ->
    oldPosition = @position.copy()
    newRow = @position.row + atom.config.get('table-edit.pageMovesAmount')
    @position.row = Math.min @tableEditor.getLastRowIndex(), newRow
    @cursorMoved(oldPosition) unless @position.isEqual(oldPosition)

  pageLeft: ->
    oldPosition = @position.copy()
    newColumn = @position.column - atom.config.get('table-edit.pageMovesAmount')
    @position.column = Math.max 0, newColumn
    @cursorMoved(oldPosition) unless @position.isEqual(oldPosition)

  pageRight: ->
    oldPosition = @position.copy()
    newColumn = @position.column + atom.config.get('table-edit.pageMovesAmount')
    @position.column = Math.min @tableEditor.getLastColumnIndex(), newColumn
    @cursorMoved(oldPosition) unless @position.isEqual(oldPosition)

  cursorMoved: (oldPosition, resetSelection=true) ->
    @selection.resetRangeOnCursor() if resetSelection
    eventObject = {
      cursor: this
      newPosition: @position
      oldPosition
    }
    @emitter.emit 'did-change-position', eventObject
    @tableEditor.emitter.emit 'did-change-cursor-position', eventObject
