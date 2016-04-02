{registerOrUpdateElement, SpacePenDSL} = require 'atom-utils'

module.exports =
class CSVProgressElement extends HTMLElement
  SpacePenDSL.includeInto(this)

  @content: ->
    @div class: 'wrapper', =>
      @label class: 'bytes', outlet: 'bytesLabel', '---'
      @label class: 'lines', outlet: 'linesLabel', '---'
      @div class: 'block', =>
        @tag 'progress', max: '100', outlet: 'progress'

  createdCallback: ->

  attachedCallback: ->

  updateReadData: (input, lines) ->
    progressData = input.getProgress()
    @linesLabel.textContent = "#{lines} #{if lines is 1 then 'line' else 'lines'}"
    @bytesLabel.textContent = "#{progressData.length}/#{progressData.total}"
    @progress.setAttribute('value', Math.floor(progressData.ratio * 100))

  updateFillTable: (lines, ratio) ->
    @linesLabel.textContent = "#{lines} #{if lines is 1 then 'row' else 'rows'} added"
    @bytesLabel.textContent = ''
    @progress.setAttribute('value', Math.floor(ratio * 100))

module.exports =
CSVPreviewElement =
registerOrUpdateElement 'atom-csv-progress', CSVProgressElement.prototype
