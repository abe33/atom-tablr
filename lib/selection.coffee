{Emitter} = require 'atom'
Range = require './range'
CursorSelectionBinding = require './cursor-selection-binding'

module.exports =
class Selection
  constructor: ({@range, @cursor, @tableEditor}) ->
    @binding = new CursorSelectionBinding({@cursor, selection: this})
    @cursor.bind(@binding)
    @range = @cursor.getRange() unless @range?
    @emitter = new Emitter

    @bindingSubscription = @binding.onDidDestroy =>
      @emitter.emit('did-destroy', this)
      @emitter.dispose()
      @bindingSubscription.dispose()
      @binding = null
      @cursor = null
      @bindingSubscription = null
      @destroyed = true

  onDidDestroy: (callback) ->
    @emitter.on 'did-destroy', callback

  onDidChangeRange: (callback) ->
    @emitter.on 'did-change-range', callback

  destroy: ->
    return if @isDestroyed()
    
    @binding.destroy()

  isDestroyed: -> @destroyed

  getCursor: -> @cursor

  setCursor: (@cursor) ->

  getRange: -> @range

  setRange: (range) ->
    @range = Range.fromObject(range)
    unless @range.containsPoint(@getCursor().getPosition())
      @getCursor().setPosition(@range.start, false)

    @rangeChanged()

  isEmpty: -> @range.isEmpty()

  bounds: -> @range.bounds()

  getFirstSelectedRow: -> @range.start.row

  getLastSelectedRow: -> @range.end.row - 1

  getFirstSelectedColumn: -> @range.start.column

  getLastSelectedColumn: -> @range.end.column - 1

  selectAll: ->
    @range.start.row = 0
    @range.start.column = 0

    @range.end.row = @tableEditor.getScreenRowCount()
    @range.end.column = @tableEditor.getScreenColumnCount()

  selectNone: ->
    @range = @cursor.getRange()

  expandUp: (delta=1) ->
    if @expandedDown()
      newRow = @range.end.row - delta
      if newRow <= @getFirstSelectedRow()
        @range.end.row = @getFirstSelectedRow() + 1
        @range.start.row = Math.max(0, newRow)
      else
        @range.end.row = newRow
    else
      @range.start.row = Math.max(0, @range.start.row - delta)

  expandDown: (delta=1) ->
    rowCount = @tableEditor.getScreenRowCount()
    if @expandedUp()
      newRow = @range.start.row + delta
      if newRow > @range.end.row
        @range.start.row = @getLastSelectedRow()
        @range.end.row = Math.min(rowCount, newRow)
      else
        @range.start.row = newRow
    else
      @range.end.row = Math.min(@tableEditor.getScreenRowCount(), @range.end.row + delta)

  expandLeft: (delta=1) ->
    if @expandedRight()
      newColumn = @range.end.column - delta
      if newColumn <= @getFirstSelectedColumn()
        @range.end.column = @getFirstSelectedColumn() + 1
        @range.start.column = Math.max(0, newColumn)
      else
        @range.end.column = newColumn
    else
      @range.start.column = Math.max(0, @range.start.column - delta)

  expandRight: (delta=1) ->
    columnCount = @tableEditor.getScreenColumnCount()
    if @expandedLeft()
      newColumn = @range.start.column + delta
      if newColumn > @range.end.column
        @range.start.column = @getLastSelectedColumn()
        @range.end.column = Math.min(columnCount, newColumn)
      else
        @range.start.column = newColumn
    else
      @range.end.column = Math.min(columnCount, @range.end.column + delta)

  expandToTop: ->
    if @expandedDown()
      end = @range.start.row + 1
      @range.start.row = 0
      @range.end.row = end
    else
      @range.start.row = 0

  expandToBottom: ->
    if @expandedUp()
      start = @range.end.row - 1
      @range.start.row = start
      @range.end.row = @tableEditor.getScreenRowCount()
    else
      @range.end.row = @tableEditor.getScreenRowCount()

  expandToLeft: ->
    if @expandedRight()
      end = @range.start.column + 1
      @range.start.column = 0
      @range.end.column = end
    else
      @range.start.column = 0

  expandToRight: ->
    if @expandedLeft()
      start = @range.end.column - 1
      @range.start.column = start
      @range.end.column = @tableEditor.getScreenColumnCount()
    else
      @range.end.column = @tableEditor.getScreenColumnCount()

  expandedUp: ->
    @getCursor().getPosition().row is @getLastSelectedRow() and
    @getCursor().getPosition().row isnt @getFirstSelectedRow()

  expandedDown: ->
    @getCursor().getPosition().row is @getFirstSelectedRow() and
    @getCursor().getPosition().row isnt @getLastSelectedRow()

  expandedRight: ->
    @getCursor().getPosition().column is @getFirstSelectedColumn() and
    @getCursor().getPosition().column isnt @getLastSelectedColumn()

  expandedLeft: ->
    @getCursor().getPosition().column is @getLastSelectedColumn() and
    @getCursor().getPosition().column isnt @getFirstSelectedColumn()

  spanMoreThanOneCell: -> @range.spanMoreThanOneCell()

  resetRangeOnCursor: ->
    @range = @cursor.getRange()
    @rangeChanged()

  rangeChanged: ->
    eventObject = selection: this

    @emitter.emit 'did-change-range', eventObject
    @tableEditor.emitter.emit 'did-change-selection-range', eventObject
