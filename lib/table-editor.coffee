_ = require 'underscore-plus'
{Point, Emitter, CompositeDisposable} = require 'atom'
Delegator = require 'delegato'
Table = require './table'
DisplayTable = require './display-table'
Cursor = require './cursor'
Selection = require './selection'
Range = require './range'

module.exports =
class TableEditor
  Delegator.includeInto(this)

  @delegatesProperties(
    'order', 'direction',
    toProperty: 'displayTable'
  )
  @delegatesMethods(
    'screenPosition', 'modelPosition',
    'screenRowToModelRow', 'modelRowToScreenRow',
    'getContentWidth', 'getContentHeight',
    'getValueAtPosition', 'setValueAtPosition',
    'getValueAtScreenPosition', 'setValueAtScreenPosition',
    'getRow', 'addRow', 'addRowAt', 'removeRow', 'removeRowAt', 'removeScreenRowAt', 'removeRowsInRange', 'removeRowsInScreenRange',
    'getRowHeightAt', 'getRowHeight', 'setRowHeight', 'setRowHeightAt', 'getLastRowIndex', 'getRowIndexAtPixelPosition',
    'getScreenRow','getScreenRowCount', 'getScreenRows', 'getScreenRowHeightAt', 'getScreenRowOffsetAt', 'setScreenRowHeightAt', 'getMinimumRowHeight', 'getScreenRowIndexAtPixelPosition', 'rowRangeFrom',
    'onDidAddRow', 'onDidRemoveRow', 'onDidChangeScreenRows', 'onDidChangeRowHeight',
    'getScreenColumn', 'getScreenColumns', 'getScreenColumnCount', 'getLastColumnIndex',
    'getScreenColumnWidth', 'setScreenColumnWidthAt', 'getScreenColumnWidthAt', 'getScreenColumnAlignAt', 'getScreenColumnOffsetAt', 'getScreenColumnIndexAtPixelPosition',
    'addColumn', 'addColumnAt', 'removeColumn', 'removeColumnAt',
    'onDidAddColumn','onDidRemoveColumn', 'onDidChangeColumnOption', 'onDidRenameColumn',
    'getScreenCellRect', 'getScreenCellPosition',
    'onDidChangeCellValue',
    'sortBy', 'toggleSortDirection', 'resetSort',
    'undo', 'redo', 'clearUndoStack', 'clearRedoStack',
    toProperty: 'displayTable'
  )

  constructor: (options={}) ->
    {@table} = options
    @table = new Table unless @table?
    @displayTable = new DisplayTable({@table})
    @emitter = new Emitter
    @subscriptions = new CompositeDisposable
    @cursors = []
    @selections = []

    @addCursorAtScreenPosition(new Point(0,0))

  onDidAddCursor: (callback) ->
    @emitter.on 'did-add-cursor', callback

  onDidRemoveCursor: (callback) ->
    @emitter.on 'did-remove-cursor', callback

  onDidChangeCursorPosition: (callback) ->
    @emitter.on 'did-change-cursor-position', callback

  onDidAddSelection: (callback) ->
    @emitter.on 'did-add-selection', callback

  onDidRemoveSelection: (callback) ->
    @emitter.on 'did-remove-selection', callback

  onDidChangeSelectionRange: (callback) ->
    @emitter.on 'did-change-selection-range', callback

  ##     ######  ######## ##       ########  ######  ########
  ##    ##    ## ##       ##       ##       ##    ##    ##
  ##    ##       ##       ##       ##       ##          ##
  ##     ######  ######   ##       ######   ##          ##
  ##          ## ##       ##       ##       ##          ##
  ##    ##    ## ##       ##       ##       ##    ##    ##
  ##     ######  ######## ######## ########  ######     ##

  getSelections: ->
    @selections.slice()

  hasMultipleSelections: ->
    @getSelections().length > 1

  getLastSelection: ->
    @selections[@selections.length - 1]

  getSelectedRange: -> @getLastSelection().getRange()

  setSelectedRange: (range) ->
    @modifySelections (selection) => selection.setRange(range)

  setSelectedRow: (row) ->
    range = @getRowRange(row)
    @modifySelections (selection) => selection.setRange(range)

  setSelectedRowRange: (range) ->
    range = @getRowsRange(range)
    @modifySelections (selection) => selection.setRange(range)

  getSelectedRanges: ->
    selection.getRange() for selection in @getSelections()

  setSelectedRanges: (ranges) ->
    unless ranges.length
      throw new Error("Passed an empty array to setSelectedRanges")

    selections = @getSelections()

    for range,i in ranges
      if selections.length
        selection = selections.shift()
        selection.setRange(range)
      else
        @addSelectionAtScreenRange(range)

    selection.destroy() for selection in selections
    @mergeSelections()

  addSelectionAtScreenRange: (range) ->
    range = Range.fromObject(range)

    cursor = new Cursor({position: range.start, tableEditor: this})
    selection = new Selection({cursor, range, tableEditor: this})
    @selections.push selection
    @cursors.push cursor
    @emitter.emit 'did-add-selection', {selection, tableEditor: this}
    @emitter.emit 'did-add-cursor', {cursor, tableEditor: this}

  removeSelection: (selection) ->
    @selections.splice(@selections.indexOf(selection), 1)
    @emitter.emit 'did-remove-selection', {selection, tableEditor: this}

  expandUp: (delta) ->
    @modifySelections (selection) -> selection.expandUp(delta)

  expandDown: (delta) ->
    @modifySelections (selection) -> selection.expandDown(delta)

  expandLeft: (delta) ->
    @modifySelections (selection) -> selection.expandLeft(delta)

  expandRight: (delta) ->
    @modifySelections (selection) -> selection.expandRight(delta)

  modifySelections: (fn) ->
    fn(selection) for selection in @getSelections()
    @mergeSelections()

  mergeSelections: ->
    remainingSelections = []
    for selectionA in @getSelections()
      isContained = false
      for selectionB in @getSelections()
        continue if selectionA is selectionB

        if selectionB.getRange().containsRange(selectionA.getRange())
          isContained = true
          break

      if isContained
        selectionA.destroy()
        selectionA.getCursor().destroy()
      else
        remainingSelections.push(selectionA)

    @selections = remainingSelections

  getRowRange: (row) ->
    Range.fromObject([
      [row, 0]
      [row + 1, @getScreenColumnCount()]
    ])

  getRowsRange: (range) ->
    range = @rowRangeFrom(range)
    Range.fromObject([
      [range.start, 0]
      [range.end + 1, @getScreenColumnCount()]
    ])

  ##     ######  ##     ## ########   ######   #######  ########   ######
  ##    ##    ## ##     ## ##     ## ##    ## ##     ## ##     ## ##    ##
  ##    ##       ##     ## ##     ## ##       ##     ## ##     ## ##
  ##    ##       ##     ## ########   ######  ##     ## ########   ######
  ##    ##       ##     ## ##   ##         ## ##     ## ##   ##         ##
  ##    ##    ## ##     ## ##    ##  ##    ## ##     ## ##    ##  ##    ##
  ##     ######   #######  ##     ##  ######   #######  ##     ##  ######

  getCursors: ->
    @cursors.slice()

  hasMultipleCursors: ->
    @getCursors().length > 1

  getLastCursor: ->
    @cursors[@cursors.length - 1]

  getCursorPosition: ->
    @modelPosition(@getLastCursor().getPosition())

  getCursorPositions: ->
    @modelPosition(cursor.getPosition()) for cursor in @getCursors()

  getCursorScreenPosition: ->
    @getLastCursor().getPosition()

  getCursorScreenPositions: ->
    cursor.getPosition() for cursor in @getCursors()

  getCursorValue: ->
    @getValueAtScreenPosition(@getCursorScreenPosition())

  getCursorValues: ->
    @getValueAtScreenPosition(cursor.getPosition()) for cursor in @getCursors()

  addCursorAtPosition: (position) ->
    @addCursorAtScreenPosition(@screenPosition(position))

  addCursorAtScreenPosition: (position) ->
    position = Point.fromObject(position)
    return if @cursors.some (cursor) -> cursor.getPosition().isEqual(position)

    cursor = new Cursor({position, tableEditor: this})
    selection = new Selection({cursor, tableEditor: this})
    @selections.push selection
    @cursors.push cursor
    @emitter.emit 'did-add-selection', {selection, tableEditor: this}
    @emitter.emit 'did-add-cursor', {cursor, tableEditor: this}

  setCursorAtPosition: (position) ->
    position = @screenPosition(position)
    @moveCursors (cursor) -> cursor.setPosition(position)

  setCursorAtScreenPosition: (position) ->
    @moveCursors (cursor) -> cursor.setPosition(position)

  removeCursor: (cursor) ->
    @cursors.splice(@cursors.indexOf(cursor), 1)
    @emitter.emit 'did-remove-cursor', {cursor, tableEditor: this}

  moveCursors: (fn) ->
    fn(cursor) for cursor in @getCursors()
    @mergeCursors()

  # Merge cursors that have the same screen position
  mergeCursors: ->
    positions = {}
    for cursor in @getCursors()
      position = cursor.getPosition().toString()
      if positions.hasOwnProperty(position)
        cursor.destroy()
        cursor.selection.destroy()
      else
        positions[position] = true
    return

  moveUp: (delta=1) -> @moveCursors (cursor) -> cursor.moveUp(delta)

  moveDown: (delta=1) -> @moveCursors (cursor) -> cursor.moveDown(delta)

  moveLeft: (delta=1) -> @moveCursors (cursor) -> cursor.moveLeft(delta)

  moveRight: (delta=1) -> @moveCursors (cursor) -> cursor.moveRight(delta)

  moveToTop: -> @moveCursors (cursor) -> cursor.moveToTop()

  moveToBottom: -> @moveCursors (cursor) -> cursor.moveToBottom()

  moveToLeft: -> @moveCursors (cursor) -> cursor.moveToLeft()

  moveToRight: -> @moveCursors (cursor) -> cursor.moveToRight()

  pageUp: -> @moveCursors (cursor) -> cursor.pageUp()

  pageDown: -> @moveCursors (cursor) -> cursor.pageDown()

  pageLeft: -> @moveCursors (cursor) -> cursor.pageLeft()

  pageRight: -> @moveCursors (cursor) -> cursor.pageRight()
