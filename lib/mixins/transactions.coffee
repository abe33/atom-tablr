Mixin = require 'mixto'

module.exports =
class Transactions extends Mixin

  transaction: (commit) ->
    @commits ?= []
    @commits.shift() if @commits.length + 1 > @constructor.MAX_HISTORY_SIZE

    @rolledbackCommits = []

    @commits.push commit

  undo: ->
    return unless @commits?.length > 0

    commit = @commits.pop()
    commit.undo.call(this)
    @rolledbackCommits.push(commit)

  redo: ->
    return unless @rolledbackCommits?.length > 0

    commit = @rolledbackCommits.pop()
    commit.redo.call(this)
    @commits.push(commit)
