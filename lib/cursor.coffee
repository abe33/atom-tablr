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
    @cursorMoved(oldPosition, resetSelection) unless @position.isEqual(oldPosition)

  getRange: ->
    new Range(@position, {
      row: Math.min(@tableEditor.getScreenRowCount(), @position.row + 1)
      column: Math.min(@tableEditor.getScreenColumnCount(), @position.column + 1)
    })

  moveUp: (delta=1) ->
    oldPosition = @position.copy()
    @moveUpInRange(delta)
    @cursorMoved(oldPosition)

  moveUpInSelection: (delta=1) ->
    return @moveUp() unless @selection.spanMoreThanOneCell()

    oldPosition = @position.copy()
    @moveUpInRange(delta, @selection.getRange())
    @cursorMoved(oldPosition, false)

  moveUpInRange: (delta=1, range=@tableEditor.getTableRange()) ->
    newRow = @position.row - delta
    newRow = range.end.row - 1 if newRow < range.start.row

    @position.row = newRow

  moveDown: (delta=1) ->
    oldPosition = @position.copy()
    @moveDownInRange(delta)
    @cursorMoved(oldPosition)

  moveDownInSelection: (delta=1) ->
    return @moveDown() unless @selection.spanMoreThanOneCell()

    oldPosition = @position.copy()
    @moveDownInRange(delta, @selection.getRange())
    @cursorMoved(oldPosition, false)

  moveDownInRange: (delta=1, range=@tableEditor.getTableRange()) ->
    newRow = @position.row + delta
    newRow = range.start.row if newRow >= range.end.row

    @position.row = newRow

  moveLeft: (delta=1) ->
    oldPosition = @position.copy()
    @moveLeftInRange(delta)
    @cursorMoved(oldPosition)

  moveLeftInSelection: (delta=1) ->
    return @moveLeft() unless @selection.spanMoreThanOneCell()

    oldPosition = @position.copy()
    @moveLeftInRange(delta, @selection.getRange())
    @cursorMoved(oldPosition, false)

  moveLeftInRange: (delta=1, range=@tableEditor.getTableRange()) ->
    newColumn = @position.column - delta

    if newColumn < range.start.column
      newColumn = range.end.column - 1
      newRow = @position.row - 1
      newRow = range.end.row - 1 if newRow < range.start.row

      @position.row = newRow

    @position.column = newColumn

  moveRight: (delta=1) ->
    oldPosition = @position.copy()
    @moveRightInRange(delta)
    @cursorMoved(oldPosition)

  moveRightInSelection: (delta=1) ->
    return @moveRight() unless @selection.spanMoreThanOneCell()

    oldPosition = @position.copy()
    @moveRightInRange(delta, @selection.getRange())
    @cursorMoved(oldPosition, false)

  moveRightInRange: (delta=1, range=@tableEditor.getTableRange()) ->
    newColumn = @position.column + delta
    if newColumn >= range.end.column
      newColumn = range.start.column
      newRow = @position.row + 1
      newRow = range.start.row if newRow >= range.end.row

      @position.row = newRow

    @position.column = newColumn

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
    newRow = @position.row - atom.config.get('tablr.pageMoveRowAmount')
    @position.row = Math.max 0, newRow
    @cursorMoved(oldPosition) unless @position.isEqual(oldPosition)

  pageDown: ->
    oldPosition = @position.copy()
    newRow = @position.row + atom.config.get('tablr.pageMoveRowAmount')
    @position.row = Math.min @tableEditor.getLastRowIndex(), newRow
    @cursorMoved(oldPosition) unless @position.isEqual(oldPosition)

  pageLeft: ->
    oldPosition = @position.copy()
    newColumn = @position.column - atom.config.get('tablr.pageMoveColumnAmount')
    @position.column = Math.max 0, newColumn
    @cursorMoved(oldPosition) unless @position.isEqual(oldPosition)

  pageRight: ->
    oldPosition = @position.copy()
    newColumn = @position.column + atom.config.get('tablr.pageMoveColumnAmount')
    @position.column = Math.min @tableEditor.getLastColumnIndex(), newColumn
    @cursorMoved(oldPosition) unless @position.isEqual(oldPosition)

  cursorMoved: (oldPosition, resetSelection=true) ->
    return if @position.isEqual(oldPosition)

    @selection.resetRangeOnCursor() if resetSelection
    eventObject = {
      cursor: this
      newPosition: @position
      oldPosition
    }
    @emitter.emit 'did-change-position', eventObject
    @tableEditor.emitter.emit 'did-change-cursor-position', eventObject

  serialize: -> @position.serialize()
