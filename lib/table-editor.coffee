_ = require 'underscore-plus'
{Point, Range, Emitter, CompositeDisposable} = require 'atom'
Delegator = require 'delegato'
Table = require './table'
DisplayTable = require './display-table'
Cursor = require './cursor'
Selection = require './selection'

module.exports =
class TableEditor
  Delegator.includeInto(this)

  @delegatesMethods 'screenPosition', 'modelPosition', 'getValueAtPosition', 'getValueAtScreenPosition', 'getScreenRowCount', 'getScreenColumnCount', toProperty: 'displayTable'

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

  onDidAddSelection: (callback) ->
    @emitter.on 'did-add-selection', callback

  onDidRemoveSelection: (callback) ->
    @emitter.on 'did-remove-selection', callback

  ##     ######  ######## ##       ########  ######  ########
  ##    ##    ## ##       ##       ##       ##    ##    ##
  ##    ##       ##       ##       ##       ##          ##
  ##     ######  ######   ##       ######   ##          ##
  ##          ## ##       ##       ##       ##          ##
  ##    ##    ## ##       ##       ##       ##    ##    ##
  ##     ######  ######## ######## ########  ######     ##

  getSelections: ->
    @selections.slice()

  getLastSelection: ->
    @selections[@selections.length - 1]

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
    @addCursorAtPosition(@screenPosition(position))

  addCursorAtScreenPosition: (position) ->
    cursor = new Cursor({position, tableEditor: this})

    @selections.push new Selection({cursor, tableEditor: this})
    @cursors.push cursor
