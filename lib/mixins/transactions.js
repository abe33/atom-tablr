'use strict'

const Mixin = require('mixto')

module.exports = class Transactions extends Mixin {
  batchTransaction (block) {
    this.startBatchTransaction()
    block()
    this.endBatchTransaction()
  }

  startBatchTransaction () {
    const commits = []
    this.batchCommit = {
      appendCommit (commit) { commits.push(commit) },
      undo () { commits.reverse().forEach(c => c.undo()) },
      redo () { commits.forEach(c => c.redo()) },
      getLastCommit () { return commits[commits.length - 1] },
      replaceLastCommit (commit) { commits[commits.length - 1] = commit }
    }
  }

  endBatchTransaction () {
    this.appendCommit(this.batchCommit)
    this.batchCommit = null
  }

  transaction (commit) {
    commit.undo = commit.undo.bind(this)
    commit.redo = commit.redo.bind(this)

    this.batchCommit != null
      ? this.batchCommit.appendCommit(commit)
      : this.appendCommit(commit)
  }

  appendCommit (commit) {
    if (this.undoStack == null) { this.undoStack = [] }
    if (this.undoStack.length + 1 > this.constructor.MAX_HISTORY_SIZE) {
      this.undoStack.shift()
    }

    this.redoStack = []
    this.undoStack.push(commit)
  }

  ammendLastTransaction (commit) {
    const originalCommit = this.getLastCommit()

    this.replaceLastCommit({
      undo () { commit.undo(originalCommit) },
      redo () { commit.redo(originalCommit) }
    })
  }

  getLastCommit () {
    return this.batchCommit
      ? this.batchCommit.getLastCommit()
      : this.undoStack[this.undoStack.length - 1]
  }

  replaceLastCommit (commit) {
    if (this.batchCommit) {
      this.batchCommit.replaceLastCommit(commit)
    } else {
      this.undoStack[this.undoStack.length - 1] = commit
    }
  }

  undo () {
    if (!this.undoStack || !this.undoStack.length) { return }

    const commit = this.undoStack.pop()
    commit.undo()
    this.redoStack.push(commit)
  }

  redo () {
    if (!this.redoStack || !this.redoStack.length) { return }

    const commit = this.redoStack.pop()
    commit.redo()
    this.undoStack.push(commit)
  }

  clearUndoStack () {
    this.undoStack && (this.undoStack.length = 0)
  }

  clearRedoStack () {
    this.redoStack && (this.redoStack.length = 0)
  }
}
