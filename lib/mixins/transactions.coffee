Mixin = require 'mixto'

module.exports =
class Transactions extends Mixin

  batchTransaction: (block) =>
    @startBatchTransaction()
    block()
    @endBatchTransaction()

  startBatchTransaction: ->
    commits = []
    @batchCommit =
      appendCommit: (commit) -> commits.push(commit)
      undo: =>
        commits[i].undo() for i in [commits.length-1..0]
      redo: =>
        commit.redo() for commit in commits

  endBatchTransaction: ->
    @appendCommit(@batchCommit)
    @batchCommit = null

  transaction: (commit) ->
    commit.undo = commit.undo.bind(this)
    commit.redo = commit.redo.bind(this)

    if @batchCommit?
      @batchCommit.appendCommit(commit)
    else
      @appendCommit(commit)

  appendCommit: (commit) ->
    @undoStack ?= []
    @undoStack.shift() if @undoStack.length + 1 > @constructor.MAX_HISTORY_SIZE

    @redoStack = []

    @undoStack.push commit

  ammendLastTransaction: (commit) ->
    originalCommit = @undoStack[@undoStack.length-1]

    @undoStack[@undoStack.length-1] =
      undo: -> commit.undo(originalCommit)
      redo: -> commit.redo(originalCommit)

  undo: ->
    return unless @undoStack?.length > 0

    commit = @undoStack.pop()
    commit.undo()
    @redoStack.push(commit)

  redo: ->
    return unless @redoStack?.length > 0

    commit = @redoStack.pop()
    commit.redo()
    @undoStack.push(commit)

  clearUndoStack: ->
    @undoStack?.length = 0

  clearRedoStack: ->
    @redoStack?.length = 0
