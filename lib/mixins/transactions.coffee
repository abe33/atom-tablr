Mixin = require 'mixto'

module.exports =
class Transactions extends Mixin

  transaction: (commit) ->
    @undoStack ?= []
    @undoStack.shift() if @undoStack.length + 1 > @constructor.MAX_HISTORY_SIZE

    @redoStack = []

    @undoStack.push commit

  undo: ->
    return unless @undoStack?.length > 0

    commit = @undoStack.pop()
    commit.undo.call(this)
    @redoStack.push(commit)

  redo: ->
    return unless @redoStack?.length > 0

    commit = @redoStack.pop()
    commit.redo.call(this)
    @undoStack.push(commit)

  clearUndoStack: ->
    @undoStack.length = 0

  clearRedoStack: ->
    @redoStack.length = 0
