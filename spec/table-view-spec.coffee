{$} = require 'atom'

path = require 'path'

Table = require '../lib/table'
TableView = require '../lib/table-view'
Column = require '../lib/column'
Row = require '../lib/row'
Cell = require '../lib/cell'
CustomCellComponent = require './fixtures/custom-cell-component'

stylesheetPath = path.resolve __dirname, '..', 'stylesheets', 'table-edit.less'
stylesheet = atom.themes.loadStylesheet(stylesheetPath)

describe 'TableView', ->
  [tableView, table, nextAnimationFrame, noAnimationFrame, requestAnimationFrameSafe, styleNode, row, cells] = []

  beforeEach ->
    spyOn(window, "setInterval").andCallFake window.fakeSetInterval
    spyOn(window, "clearInterval").andCallFake window.fakeClearInterval

    noAnimationFrame = -> throw new Error('No animation frame requested')
    nextAnimationFrame = noAnimationFrame

    requestAnimationFrameSafe = window.requestAnimationFrame
    spyOn(window, 'requestAnimationFrame').andCallFake (fn) ->
      nextAnimationFrame = ->
        nextAnimationFrame = noAnimationFrame
        fn()

  beforeEach ->
    table = new Table
    table.addColumn 'key'
    table.addColumn 'value'
    table.addColumn 'foo'

    for i in [0...100]
      table.addRow [
        "row#{i}"
        i * 100
        if i % 2 is 0 then 'yes' else 'no'
      ]

    tableView = new TableView(table)
    tableView.setRowHeight 20
    tableView.setRowOverdraw 10

    styleNode = $('body').append("<style>
      #{stylesheet}

      .table-edit {
        height: 200px;
        width: 400px;
      }

      .table-edit-header {
        height: 27px;
      }
    </style>").find('style')

    $('body').append(tableView)

    nextAnimationFrame()

  it 'holds a table', ->
    expect(tableView.table).toEqual(table)

  #     ######   #######  ##    ## ######## ######## ##    ## ########
  #    ##    ## ##     ## ###   ##    ##    ##       ###   ##    ##
  #    ##       ##     ## ####  ##    ##    ##       ####  ##    ##
  #    ##       ##     ## ## ## ##    ##    ######   ## ## ##    ##
  #    ##       ##     ## ##  ####    ##    ##       ##  ####    ##
  #    ##    ## ##     ## ##   ###    ##    ##       ##   ###    ##
  #     ######   #######  ##    ##    ##    ######## ##    ##    ##

  it 'has a scroll-view', ->
    expect(tableView.find('.scroll-view').length).toEqual(1)

  describe 'when not scrolled yet', ->
    it 'renders the lines at the top of the table', ->
      rows = tableView.find('.table-edit-row')
      expect(rows.length).toEqual(18)
      expect(rows.first().data('row-id')).toEqual(1)
      expect(rows.last().data('row-id')).toEqual(18)

    describe '::getFirstVisibleRow', ->
      it 'returns 0', ->
        expect(tableView.getFirstVisibleRow()).toEqual(0)

    describe '::getLastVisibleRow', ->
      it 'returns 8', ->
        expect(tableView.getLastVisibleRow()).toEqual(8)

  describe 'the rendered rows', ->
    beforeEach ->
      row = tableView.find('.table-edit-row').first()
      cells = row.find('.table-edit-cell')

    it 'has as many columns as the model row', ->
      expect(cells.length).toEqual(3)

    describe 'without any columns layout data', ->
      it 'have cells that all have the same width', ->
        cells.each ->
          expect(@clientWidth).toBeCloseTo(tableView.width() / 3, -2)

    describe 'with a columns layout defined', ->
      describe 'with an array with enough values', ->
        it 'modifies the columns widths', ->
          tableView.setColumnsWidths([0.2, 0.3, 0.5])
          nextAnimationFrame()

          expect(cells.first().width()).toBeCloseTo(tableView.width() * 0.2, -2)
          expect(cells.eq(1).width()).toBeCloseTo(tableView.width() * 0.3, -2)
          expect(cells.last().width()).toBeCloseTo(tableView.width() * 0.5, -2)

      describe 'with an array with sparse values', ->
        it 'computes the other columns width', ->
          tableView.setColumnsWidths([0.2, null, 0.5])
          nextAnimationFrame()

          expect(cells.first().width()).toBeCloseTo(tableView.width() * 0.2, -2)
          expect(cells.eq(1).width()).toBeCloseTo(tableView.width() * 0.3, -2)
          expect(cells.last().width()).toBeCloseTo(tableView.width() * 0.5, -2)

      describe 'with an array with more than one missing value', ->
        it 'divides the rest width between the missing columns', ->
          tableView.setColumnsWidths([0.2])
          nextAnimationFrame()

          expect(cells.first().width()).toBeCloseTo(tableView.width() * 0.2, -2)
          expect(cells.eq(1).width()).toBeCloseTo(tableView.width() * 0.4, -2)
          expect(cells.last().width()).toBeCloseTo(tableView.width() * 0.4, -2)

      describe 'with an array whose sum is greater than 1', ->
        it 'divides the rest width between the missing columns', ->
          tableView.setColumnsWidths([0.5, 0.5, 1])
          nextAnimationFrame()

          expect(cells.first().width()).toBeCloseTo(tableView.width() * 0.25, -2)
          expect(cells.eq(1).width()).toBeCloseTo(tableView.width() * 0.25, -2)
          expect(cells.last().width()).toBeCloseTo(tableView.width() * 0.5, -2)

      describe 'with a sparse array whose sum is greater or equal than 1', ->
        it 'divides the rest width between the missing columns', ->
          tableView.setColumnsWidths([0.5, 0.5])
          nextAnimationFrame()

          expect(cells.first().width()).toBeCloseTo(tableView.width() * 0.25, -2)
          expect(cells.eq(1).width()).toBeCloseTo(tableView.width() * 0.25, -2)
          expect(cells.last().width()).toBeCloseTo(tableView.width() * 0.5, -2)

      describe "by setting the width on model's columns", ->
        it 'uses the columns data', ->
          table.getColumn(0).width = 0.2
          table.getColumn(1).width = 0.3

          nextAnimationFrame()

          expect(cells.first().width()).toBeCloseTo(tableView.width() * 0.2, -2)
          expect(cells.eq(1).width()).toBeCloseTo(tableView.width() * 0.3, -2)
          expect(cells.last().width()).toBeCloseTo(tableView.width() * 0.5, -2)

      describe "from both the model's columns and in the view", ->
        it 'uses the view data and fallback to the columns data if available', ->
          table.getColumn(0).width = 0.2
          table.getColumn(1).width = 0.3

          tableView.setColumnsWidths([0.8])
          nextAnimationFrame()

          expect(cells.first().width()).toBeCloseTo(tableView.width() * 0.8, -2)
          expect(cells.eq(1).width()).toBeCloseTo(tableView.width() * 0.1, -2)
          expect(cells.last().width()).toBeCloseTo(tableView.width() * 0.1, -2)

      describe 'with alignements defined in the columns models', ->
        it 'sets the cells text-alignement using the model data', ->
          table.getColumn(0).align = 'right'
          table.getColumn(1).align = 'center'

          nextAnimationFrame()

          expect(cells.first().css('text-align')).toEqual('right')
          expect(cells.eq(1).css('text-align')).toEqual('center')
          expect(cells.last().css('text-align')).toEqual('left')

      describe 'with alignements defined in the view', ->
        it 'sets the cells text-alignement with the view data', ->
          tableView.setColumnsAligns(['right', 'center'])
          nextAnimationFrame()

          expect(cells.first().css('text-align')).toEqual('right')
          expect(cells.eq(1).css('text-align')).toEqual('center')
          expect(cells.last().css('text-align')).toEqual('left')

      describe 'with both alignements defined on the view and models', ->
        it 'sets the cells text-alignement with the view data', ->
          table.getColumn(0).align = 'left'
          table.getColumn(1).align = 'right'
          table.getColumn(2).align = 'center'

          tableView.setColumnsAligns(['right', 'center'])
          nextAnimationFrame()

          expect(cells.first().css('text-align')).toEqual('right')
          expect(cells.eq(1).css('text-align')).toEqual('center')
          expect(cells.last().css('text-align')).toEqual('center')

    describe 'with a custom cell renderer defined on a column', ->
      it 'uses the provided renderer to render the columns cells', ->
        table.getColumn(2).componentClass = CustomCellComponent

        nextAnimationFrame()

        expect(tableView.find('.table-edit-row:first-child .table-edit-cell:last-child').text()).toEqual('foo: yes')

  describe 'when scrolled by 100px', ->
    beforeEach ->
      tableView.scrollTop(100)
      nextAnimationFrame()

    describe '::getFirstVisibleRow', ->
      it 'returns 5', ->
        expect(tableView.getFirstVisibleRow()).toEqual(5)

    describe '::getLastVisibleRow', ->
      it 'returns 13', ->
        expect(tableView.getLastVisibleRow()).toEqual(13)

    it 'translates the content by the amount of scroll', ->
      expect(tableView.find('.scroll-view').scrollTop()).toEqual(100)

    it 'does not render new rows', ->
      rows = tableView.find('.table-edit-row')
      expect(rows.length).toEqual(18)
      expect(rows.first().data('row-id')).toEqual(1)
      expect(rows.last().data('row-id')).toEqual(18)

  describe 'when scrolled by 300px', ->
    beforeEach ->
      tableView.scrollTop(300)
      nextAnimationFrame()

    describe '::getFirstVisibleRow', ->
      it 'returns 15', ->
        expect(tableView.getFirstVisibleRow()).toEqual(15)

    describe '::getLastVisibleRow', ->
      it 'returns 23', ->
        expect(tableView.getLastVisibleRow()).toEqual(23)

    it 'renders new rows', ->
      rows = tableView.find('.table-edit-row')
      expect(rows.length).toEqual(28)
      expect(rows.first().data('row-id')).toEqual(6)
      expect(rows.last().data('row-id')).toEqual(33)

  describe 'when the table rows are modified', ->
    describe 'by adding one at the end', ->
      it 'does not render new rows', ->
        table.addRow ['foo', 'bar', 'baz']

        nextAnimationFrame()

        rows = tableView.find('.table-edit-row')
        expect(rows.length).toEqual(18)
        expect(rows.first().data('row-id')).toEqual(1)
        expect(rows.last().data('row-id')).toEqual(18)

    describe 'by adding one at the begining', ->
      it 'updates the rows', ->
        rows = tableView.find('.table-edit-row')
        expect(rows.first().find('.table-edit-cell').first().text()).toEqual('row0')

        table.addRowAt 0, ['foo', 'bar', 'baz']

        nextAnimationFrame()

        rows = tableView.find('.table-edit-row')
        expect(rows.length).toEqual(18)
        expect(rows.first().data('row-id')).toEqual(1)
        expect(rows.first().find('.table-edit-cell').first().text()).toEqual('foo')
        expect(rows.last().data('row-id')).toEqual(18)

    describe 'by adding one in the middle', ->
      it 'updates the rows', ->
        rows = tableView.find('.table-edit-row')
        expect(rows.eq(6).find('.table-edit-cell').first().text()).toEqual('row6')

        table.addRowAt 6, ['foo', 'bar', 'baz']

        nextAnimationFrame()

        rows = tableView.find('.table-edit-row')
        expect(rows.length).toEqual(18)
        expect(rows.first().data('row-id')).toEqual(1)
        expect(rows.eq(6).find('.table-edit-cell').first().text()).toEqual('foo')
        expect(rows.last().data('row-id')).toEqual(18)

    describe 'by updating the content of a row', ->
      it 'update the rows', ->
        rows = tableView.find('.table-edit-row')
        expect(rows.eq(6).find('.table-edit-cell').first().text()).toEqual('row6')

        table.getRow(6).key = 'foo'

        nextAnimationFrame()

        rows = tableView.find('.table-edit-row')
        expect(rows.eq(6).find('.table-edit-cell').first().text()).toEqual('foo')

  #    ##     ## ########    ###    ########  ######## ########
  #    ##     ## ##         ## ##   ##     ## ##       ##     ##
  #    ##     ## ##        ##   ##  ##     ## ##       ##     ##
  #    ######### ######   ##     ## ##     ## ######   ########
  #    ##     ## ##       ######### ##     ## ##       ##   ##
  #    ##     ## ##       ##     ## ##     ## ##       ##    ##
  #    ##     ## ######## ##     ## ########  ######## ##     ##

  it 'has a header', ->
    expect(tableView.find('.table-edit-header').length).toEqual(1)

  describe 'header', ->
    it 'has as many cell as there is columns in the table', ->
      cells = tableView.find('.table-edit-header-cell')
      expect(cells.length).toEqual(3)
      expect(cells.first().text()).toEqual('key')
      expect(cells.eq(1).text()).toEqual('value')
      expect(cells.last().text()).toEqual('foo')

    it 'has cells that have the same width as the body cells', ->
      tableView.setColumnsWidths([0.2, 0.3, 0.5])
      nextAnimationFrame()

      cells = tableView.find('.table-edit-header-cell')
      rowCells = tableView.find('.table-edit-row:first-child .table-edit-cell')

      expect(cells.first().width()).toBeCloseTo(rowCells.first().width(), -2)
      expect(cells.eq(1).width()).toBeCloseTo(rowCells.eq(1).width(), -2)
      expect(cells.last().width()).toBeCloseTo(rowCells.last().width(), -2)

  #     ######   #######  ##    ## ######## ########   #######  ##
  #    ##    ## ##     ## ###   ##    ##    ##     ## ##     ## ##
  #    ##       ##     ## ####  ##    ##    ##     ## ##     ## ##
  #    ##       ##     ## ## ## ##    ##    ########  ##     ## ##
  #    ##       ##     ## ##  ####    ##    ##   ##   ##     ## ##
  #    ##    ## ##     ## ##   ###    ##    ##    ##  ##     ## ##
  #     ######   #######  ##    ##    ##    ##     ##  #######  ########

  it 'gains focus when mouse is pressed on the table view', ->
    tableView.mousedown()

    expect(tableView.hiddenInput.is(':focus')).toBeTruthy()

  it 'activates the cell under the mouse when pressed', ->
    cell = tableView.find('.table-edit-row:nth-child(4) .table-edit-cell:last-child')
    offset = cell.offset()
    event = $.Event "mousedown", {
      which: 1
      pageX: offset.left + 50
      pageY: offset.top + 5
    }

    cell.trigger(event)

    expect(tableView.getActiveCell().getValue()).toEqual('no')

  it 'does not focus the hidden input twice when multiple press occurs', ->
    spyOn(tableView.hiddenInput, 'focus').andCallThrough()

    tableView.mousedown()
    tableView.mousedown()

    expect(tableView.hiddenInput.focus).toHaveBeenCalled()
    expect(tableView.hiddenInput.focus.calls.length).toEqual(1)
    expect(tableView.hiddenInput.is(':focus')).toBeTruthy()

  it 'has an active cell', ->
    activeCell = tableView.getActiveCell()
    expect(activeCell).toBeDefined()
    expect(activeCell.getValue()).toEqual('row0')

  it 'renders the active cell using a class', ->
    expect(tableView.find('.table-edit-header-cell.active-column').length).toEqual(1)
    expect(tableView.find('.table-edit-row.active-row').length).toEqual(1)
    expect(tableView.find('.table-edit-cell.active').length).toEqual(1)
    expect(tableView.find('.table-edit-cell.active-column').length)
    .toBeGreaterThan(1)

  describe '::moveRight', ->
    it 'requests an update', ->
      spyOn(tableView, 'requestUpdate')
      tableView.moveRight()

      expect(tableView.requestUpdate).toHaveBeenCalled()
      expect(tableView.requestUpdate.calls[0].args[0]).toBeTruthy()

    it 'attempts to make the active row visible', ->
      spyOn(tableView, 'makeRowVisible')
      tableView.moveRight()

      expect(tableView.makeRowVisible).toHaveBeenCalled()

    it 'is triggered on core:move-right', ->
      spyOn(tableView, 'moveRight')

      tableView.trigger('core:move-right')

      expect(tableView.moveRight).toHaveBeenCalled()

    it 'moves the active cell cursor to the right', ->
      tableView.moveRight()

      expect(tableView.getActiveCell().getValue()).toEqual(0)

      tableView.moveRight()

      expect(tableView.getActiveCell().getValue()).toEqual('yes')

    it 'moves the active cell to the next row when on last cell of a row', ->
      tableView.moveRight()
      tableView.moveRight()
      tableView.moveRight()
      expect(tableView.getActiveCell().getValue()).toEqual('row1')

    it 'moves the active cell to the first row when on last cell of last row', ->
      tableView.activeCellPosition.row = 99
      tableView.activeCellPosition.column = 2

      tableView.moveRight()
      expect(tableView.getActiveCell().getValue()).toEqual('row0')

  describe '::moveLeft', ->
    it 'requests an update', ->
      spyOn(tableView, 'requestUpdate')
      tableView.moveLeft()

      expect(tableView.requestUpdate).toHaveBeenCalled()
      expect(tableView.requestUpdate.calls[0].args[0]).toBeTruthy()

    it 'attempts to make the active row visible', ->
      spyOn(tableView, 'makeRowVisible')
      tableView.moveLeft()

      expect(tableView.makeRowVisible).toHaveBeenCalled()

    it 'is triggered on core:move-left', ->
      spyOn(tableView, 'moveLeft')

      tableView.trigger('core:move-left')

      expect(tableView.moveLeft).toHaveBeenCalled()

    it 'moves the active cell to the last cell when on the first cell', ->
      tableView.moveLeft()
      expect(tableView.getActiveCell().getValue()).toEqual('no')

    it 'moves the active cell cursor to the left', ->
      tableView.moveRight()
      tableView.moveLeft()
      expect(tableView.getActiveCell().getValue()).toEqual('row0')

    it 'moves the active cell cursor to the upper row', ->
      tableView.moveRight()
      tableView.moveRight()
      tableView.moveRight()
      tableView.moveLeft()
      expect(tableView.getActiveCell().getValue()).toEqual('yes')

  describe '::moveUp', ->
    it 'requests an update', ->
      spyOn(tableView, 'requestUpdate')
      tableView.moveUp()

      expect(tableView.requestUpdate).toHaveBeenCalled()
      expect(tableView.requestUpdate.calls[0].args[0]).toBeTruthy()

    it 'attempts to make the active row visible', ->
      spyOn(tableView, 'makeRowVisible')
      tableView.moveUp()

      expect(tableView.makeRowVisible).toHaveBeenCalled()

    it 'is triggered on core:move-up', ->
      spyOn(tableView, 'moveUp')

      tableView.trigger('core:move-up')

      expect(tableView.moveUp).toHaveBeenCalled()

    it 'moves the active cell to the last row when on the first row', ->
      tableView.moveUp()
      expect(tableView.getActiveCell().getValue()).toEqual('row99')

    it 'moves the active cell on the upper row', ->
      tableView.activeCellPosition.row = 10

      tableView.moveUp()
      expect(tableView.getActiveCell().getValue()).toEqual('row9')

  describe '::moveDown', ->
    it 'requests an update', ->
      spyOn(tableView, 'requestUpdate')
      tableView.moveDown()

      expect(tableView.requestUpdate).toHaveBeenCalled()
      expect(tableView.requestUpdate.calls[0].args[0]).toBeTruthy()

    it 'attempts to make the active row visible', ->
      spyOn(tableView, 'makeRowVisible')
      tableView.moveDown()

      expect(tableView.makeRowVisible).toHaveBeenCalled()

    it 'is triggered on core:move-down', ->
      spyOn(tableView, 'moveDown')

      tableView.trigger('core:move-down')

      expect(tableView.moveDown).toHaveBeenCalled()

    it 'moves the active cell to the row below', ->
      tableView.moveDown()
      expect(tableView.getActiveCell().getValue()).toEqual('row1')

    it 'moves the active cell to the first row when on the last row', ->
      tableView.activeCellPosition.row = 99

      tableView.moveDown()
      expect(tableView.getActiveCell().getValue()).toEqual('row0')

  describe '::makeRowVisible', ->
    it 'scrolls the view until the passed-on row become visible', ->
      tableView.makeRowVisible(50)

      expect(tableView.body.scrollTop()).toEqual(849)

  #    ######## ########  #### ########
  #    ##       ##     ##  ##     ##
  #    ##       ##     ##  ##     ##
  #    ######   ##     ##  ##     ##
  #    ##       ##     ##  ##     ##
  #    ##       ##     ##  ##     ##
  #    ######## ########  ####    ##

  describe '::startEdit', ->
    [editor] = []

    beforeEach ->
      tableView.startEdit()
      editor = tableView.find('.editor')

    it 'opens a text editor above the active cell', ->
      cell = tableView.find('.table-edit-row:first-child .table-edit-cell:first-child')
      cellOffset = cell.offset()

      editorOffset = editor.offset()

      expect(editor.length).toEqual(1)
      expect(editorOffset.top).toBeCloseTo(cellOffset.top, -2)
      expect(editorOffset.left).toBeCloseTo(cellOffset.left, -2)
      expect(editor.outerWidth()).toEqual(cell.outerWidth())
      expect(editor.outerHeight()).toEqual(cell.outerHeight())

    it 'gives the focus to the editor', ->
      expect(editor.is('.is-focused')).toBeTruthy()

    it 'fills the editor with the cell value', ->
      expect(editor.element.getModel().getBuffer().getText()).toEqual('row0')

  describe 'with an editor opened', ->
    [editor] = []

    beforeEach ->
      tableView.startEdit()
      editor = tableView.find('.editor')

    describe 'core:cancel', ->
      beforeEach ->
        editor.trigger('core:cancel')

      it 'closes the editor', ->
        expect(tableView.find('.editor:visible').length).toEqual(0)

      it 'gives the focus back to the table view', ->
        expect(tableView.hiddenInput.is(':focus')).toBeTruthy()

  afterEach ->
    window.requestAnimationFrame = requestAnimationFrameSafe
    styleNode.remove()
    tableView.destroy()
