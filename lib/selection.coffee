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
    oldRange = @range
    @range = Range.fromObject(range)
    unless @range.containsPoint(@getCursor().getPosition())
      @getCursor().setPosition(@range.start, false)

    @rangeChanged(oldRange)

  isEmpty: -> @range.isEmpty()

  bounds: -> @range.bounds()

  getValue: ->
    return [] if @isEmpty()

    for row in [@range.start.row...@range.end.row]
      for column in [@range.start.column...@range.end.column]
        @tableEditor.getValueAtScreenPosition([row, column])

  getFlattenValue: ->
    return [] if @isEmpty()

    res = []
    for row in [@range.start.row...@range.end.row]
      for column in [@range.start.column...@range.end.column]
        res.push @tableEditor.getValueAtScreenPosition([row, column])

    res

  rowsSpan: -> @range.end.row - @range.start.row

  columnsSpan: -> @range.end.column - @range.start.column

  delete: ->
    @tableEditor.setValuesInScreenRange(@range, [[undefined]])

  fill: (text) ->
    @tableEditor.setValuesInScreenRange(@range, [[text]])

  fillValues: (values) ->
    clipboardRows = values.length
    clipboardColumns = values[0].length

    if clipboardRows > @rowsSpan()
      @range.end.row = @range.start.row + clipboardRows

    if clipboardColumns > @columnsSpan()
      @range.end.column = @range.start.column + clipboardColumns

    @tableEditor.setValuesInScreenRange(@range, values)

  copy: (maintainClipboard=false, fullLine=false) ->
    return if @isEmpty()

    values = @getValue()
    selectionText = values.map((a) -> a.join('\t')).join('\n')

    if maintainClipboard
      {text: clipboardText, metadata} = atom.clipboard.readWithMetadata()
      metadata ?= {}
      metadata.values ?= []
      metadata.selections ?= [{
        text: clipboardText
        fullLine: metadata.fullLine
        indentBasis: 0
      }]

      metadata.values.push(values)

      if atom.config.get 'tablr.treatEachCellAsASelectionWhenPastingToABuffer'
        @getFlattenValue().forEach (value) ->
          metadata.selections.push({
            text: value
            fullLine: fullLine
            indentBasis: 0
          })
      else
        metadata.selections.push({
          text: selectionText
          fullLine: fullLine
          indentBasis: 0
        })

      atom.clipboard.write([clipboardText, selectionText].join("\n"), metadata)
    else
      if atom.config.get 'tablr.treatEachCellAsASelectionWhenPastingToABuffer'
        atom.clipboard.write(selectionText, {
          values: [values]
          indentBasis: 0
          fullLine: fullLine
          selections: @getFlattenValue().map (value) ->
            {
              text: value
              fullLine: fullLine
              indentBasis: 0
            }
        })

      else
        atom.clipboard.write(selectionText, {
          values: [values]
          indentBasis: 0
          fullLine: fullLine
        })

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
    oldRange = @range.copy()
    if @expandedDown()
      newRow = @range.end.row - delta
      if newRow <= @getFirstSelectedRow()
        @range.end.row = @getFirstSelectedRow() + 1
        @range.start.row = Math.max(0, newRow)
      else
        @range.end.row = newRow
    else
      @range.start.row = Math.max(0, @range.start.row - delta)

    @rangeChanged(oldRange) unless @range.isEqual(oldRange)

  expandDown: (delta=1) ->
    oldRange = @range.copy()
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

    @rangeChanged(oldRange) unless @range.isEqual(oldRange)

  expandLeft: (delta=1) ->
    oldRange = @range.copy()
    if @expandedRight()
      newColumn = @range.end.column - delta
      if newColumn <= @getFirstSelectedColumn()
        @range.end.column = @getFirstSelectedColumn() + 1
        @range.start.column = Math.max(0, newColumn)
      else
        @range.end.column = newColumn
    else
      @range.start.column = Math.max(0, @range.start.column - delta)

    @rangeChanged(oldRange) unless @range.isEqual(oldRange)

  expandRight: (delta=1) ->
    oldRange = @range.copy()
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

    @rangeChanged(oldRange) unless @range.isEqual(oldRange)

  expandToTop: ->
    oldRange = @range.copy()

    if @expandedDown()
      end = @range.start.row + 1
      @range.start.row = 0
      @range.end.row = end
    else
      @range.start.row = 0

    @rangeChanged(oldRange) unless @range.isEqual(oldRange)

  expandToBottom: ->
    oldRange = @range.copy()

    if @expandedUp()
      start = @range.end.row - 1
      @range.start.row = start
      @range.end.row = @tableEditor.getScreenRowCount()
    else
      @range.end.row = @tableEditor.getScreenRowCount()

    @rangeChanged(oldRange) unless @range.isEqual(oldRange)

  expandToLeft: ->
    oldRange = @range.copy()

    if @expandedRight()
      end = @range.start.column + 1
      @range.start.column = 0
      @range.end.column = end
    else
      @range.start.column = 0

    @rangeChanged(oldRange) unless @range.isEqual(oldRange)

  expandToRight: ->
    oldRange = @range.copy()

    if @expandedLeft()
      start = @range.end.column - 1
      @range.start.column = start
      @range.end.column = @tableEditor.getScreenColumnCount()
    else
      @range.end.column = @tableEditor.getScreenColumnCount()

    @rangeChanged(oldRange) unless @range.isEqual(oldRange)

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
    oldRange = @range
    @range = @cursor.getRange()
    @rangeChanged(oldRange) unless @range.isEqual(oldRange)

  rangeChanged: (oldRange) ->
    eventObject = {
      selection: this
      newRange: @range
      oldRange
    }

    @emitter.emit 'did-change-range', eventObject
    @tableEditor.emitter.emit 'did-change-selection-range', eventObject

  serialize: -> @range.serialize()
