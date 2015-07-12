{Emitter} = require 'atom'
Range = require './range'

module.exports =
class Selection
  constructor: ({@range, @cursor, @tableEditor}) ->
    @cursor.selection = this
    @range = @cursor.getRange() unless @range?
    @emitter = new Emitter

  onDidChangeRange: (callback) ->
    @emitter.on 'did-change-range', callback

  onDidDestroy: (callback) ->
    @emitter.on 'did-destroy', callback

  destroy: ->
    @tableEditor.removeSelection(this)
    @emitter.emit('did-destroy', this)

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

  expandedRight: ->
    @getCursor().getPosition().column is @getFirstSelectedColumn() and
    @getCursor().getPosition().column isnt @getLastSelectedColumn()

  expandedLeft: ->
    @getCursor().getPosition().column is @getLastSelectedColumn() and
    @getCursor().getPosition().column isnt @getFirstSelectedColumn()

  expandedUp: ->
    @getCursor().getPosition().row is @getLastSelectedRow() and
    @getCursor().getPosition().row isnt @getFirstSelectedRow()

  expandedDown: ->
    @getCursor().getPosition().row is @getFirstSelectedRow() and
    @getCursor().getPosition().row isnt @getLastSelectedRow()

  spanMoreThanOneCell: -> @range.spanMoreThanOneCell()

  resetRangeOnCursor: ->
    @range = @cursor.getRange()
    @rangeChanged()

  rangeChanged: ->
    eventObject = selection: this

    @emitter.emit 'did-change-range', eventObject
    @tableEditor.emitter.emit 'did-change-selection-range', eventObject
