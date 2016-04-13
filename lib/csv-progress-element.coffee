{registerOrUpdateElement, SpacePenDSL} = require 'atom-utils'

byteUnits = ['B', 'kB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB']

module.exports =
class CSVProgressElement extends HTMLElement
  SpacePenDSL.includeInto(this)

  @content: ->
    @div class: 'wrapper', =>
      @label class: 'bytes', outlet: 'bytesLabel', '---'
      @label class: 'lines', outlet: 'linesLabel', '---'
      @div class: 'block', =>
        @tag 'progress', max: '100', outlet: 'progress'

  updateReadData: (input, lines) ->
    progressData = input.getProgress()
    @linesLabel.textContent = "#{lines} #{if lines is 1 then 'line' else 'lines'}"

    {total, length, ration} = progressData

    byteScale = @getByteScale(total)
    byteDivider = Math.max(1, Math.pow(1000, byteScale))
    unit = @getUnit(byteScale)

    @bytesLabel.textContent = "#{(length / byteDivider).toFixed(1)}/#{(total / byteDivider).toFixed(1)}#{unit}"
    @progress.setAttribute('value', Math.floor(progressData.ratio * 100))

  getByteScale: (size) ->
    i = 0

    while size > 1000
      size = size / 1000
      i++

    i

  getUnit: (scale) -> byteUnits[scale]

  updateFillTable: (lines, ratio) ->
    @linesLabel.textContent = "#{lines} #{if lines is 1 then 'row' else 'rows'} added"
    @bytesLabel.textContent = ''
    @progress.setAttribute('value', Math.floor(ratio * 100))

module.exports =
CSVPreviewElement =
registerOrUpdateElement 'atom-csv-progress', CSVProgressElement.prototype
