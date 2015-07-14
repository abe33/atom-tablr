path = require 'path'

Table = require '../lib/table'
TableEditor = require '../lib/table-editor'
TableElement = require '../lib/table-element'
Column = require '../lib/display-column'
Row = require '../lib/row'
Cell = require '../lib/cell'
{mousedown, mousemove, mouseup, scroll, click, dblclick, textInput, objectCenterCoordinates} = require './helpers/events'

stylesheetPath = path.resolve __dirname, '..', 'styles', 'table-edit.less'
stylesheet = "
  #{atom.themes.loadStylesheet(stylesheetPath)}

  atom-table-editor {
    height: 200px;
    width: 400px;
  }

  atom-table-editor::shadow .table-edit-header {
    height: 27px;
  }

  atom-table-editor::shadow atom-table-cell {
    border: none;
    padding: 0;
  }

  atom-table-editor::shadow .selection-box-handle {
    width: 1px;
    height: 1px;
    margin: 0;
  }
"

compareCloseArrays = (a,b,precision=-2) ->
  expect(a.length).toEqual(b.length)

  if a.length is b.length
    for valueA,i in a
      valueB = b[i]
      expect(valueA).toBeCloseTo(valueB, precision)

comparePixelStyles = (a,b,precision=-1) ->
  expect(parseFloat(a)).toBeCloseTo(parseFloat(b), precision)

isVisible = (node) ->
  node.offsetWidth? and
  node.offsetWidth isnt 0 and
  node.offsetHeight? and
  node.offsetHeight isnt 0

mockConfirm = (response) -> spyOn(atom, 'confirm').andCallFake -> response

describe 'tableElement', ->
  [tableElement, tableShadowRoot, tableEditor, nextAnimationFrame, noAnimationFrame, requestAnimationFrameSafe, styleNode, row, cells, jasmineContent] = []

  afterEach ->
    window.requestAnimationFrame = requestAnimationFrameSafe

  beforeEach ->
    TableElement.registerViewProvider()

    jasmineContent = document.body.querySelector('#jasmine-content')

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
    tableEditor = new TableEditor
    tableEditor.addColumn 'key'
    tableEditor.addColumn 'value'
    tableEditor.addColumn 'foo'

    for i in [0...100]
      tableEditor.addRow [
        "row#{i}"
        i * 100
        if i % 2 is 0 then 'yes' else 'no'
      ]

    atom.config.set 'table-edit.rowHeight', 20
    atom.config.set 'table-edit.columnWidth', 100
    atom.config.set 'table-edit.rowOverdraw', 10
    atom.config.set 'table-edit.columnOverdraw', 2
    atom.config.set 'table-edit.minimumRowHeight', 10

    tableElement = atom.views.getView(tableEditor)
    tableShadowRoot = tableElement.shadowRoot

    styleNode = document.createElement('style')
    styleNode.textContent = stylesheet

    firstChild = jasmineContent.firstChild

    jasmineContent.insertBefore(styleNode, firstChild)
    jasmineContent.insertBefore(tableElement, firstChild)

    nextAnimationFrame()

  it 'holds a table', ->
    expect(tableElement.getModel()).toEqual(tableEditor)

  describe "instantiation", ->
    [element, container] = []

    beforeEach ->
      container = document.createElement('div')
      jasmineContent.appendChild(container)

    describe 'by putting an atom-table-editor tag in the DOM', ->
      beforeEach ->
        container.innerHTML = "<atom-table-editor>"
        element = container.firstChild
        nextAnimationFrame()

      it 'creates a default model to boot the table', ->
        model = element.getModel()
        expect(model).toBeDefined()
        expect(model.getScreenColumnCount()).toEqual(1)
        expect(model.getScreenRowCount()).toEqual(1)

      it 'renders the default model', ->
        cell = element.shadowRoot.querySelectorAll('atom-table-cell')
        expect(cell.length).toEqual(1)

  #     ######   #######  ##    ## ######## ######## ##    ## ########
  #    ##    ## ##     ## ###   ##    ##    ##       ###   ##    ##
  #    ##       ##     ## ####  ##    ##    ##       ####  ##    ##
  #    ##       ##     ## ## ## ##    ##    ######   ## ## ##    ##
  #    ##       ##     ## ##  ####    ##    ##       ##  ####    ##
  #    ##    ## ##     ## ##   ###    ##    ##       ##   ###    ##
  #     ######   #######  ##    ##    ##    ######## ##    ##    ##

  it 'has a body', ->
    expect(tableShadowRoot.querySelector('.table-edit-body')).toExist()

  describe 'when not scrolled yet', ->
    it 'renders the lines at the top of the table', ->
      cells = tableShadowRoot.querySelectorAll('atom-table-cell')
      expect(cells.length).toEqual(18 * 3)
      expect(cells[0].dataset.row).toEqual('0')
      expect(cells[cells.length - 1].dataset.row).toEqual('17')

    describe '::getFirstVisibleRow', ->
      it 'returns 0', ->
        expect(tableElement.getFirstVisibleRow()).toEqual(0)

    describe '::getLastVisibleRow', ->
      it 'returns 8', ->
        expect(tableElement.getLastVisibleRow()).toEqual(8)

  describe 'once rendered', ->
    beforeEach ->
      cells = tableShadowRoot.querySelectorAll('atom-table-cell[data-row="0"]')

    it 'has as many columns as the model row', ->
      expect(cells.length).toEqual(3)

    it 'renders undefined cells based on a config', ->
      atom.config.set('table-edit.undefinedDisplay', 'foo')

      tableEditor.setValueAtPosition([0,0], undefined)
      nextAnimationFrame()
      expect(tableElement.getScreenCellAtPosition([0,0]).textContent).toEqual('foo')

    it 'renders undefined cells based on the view property', ->
      tableElement.undefinedDisplay = 'bar'
      atom.config.set('table-edit.undefinedDisplay', 'foo')

      tableEditor.setValueAtPosition([0,0], undefined)
      nextAnimationFrame()
      expect(tableElement.getScreenCellAtPosition([0,0]).textContent).toEqual('bar')

    it 'sets the proper width and height on the table rows container', ->
      bodyContent = tableShadowRoot.querySelector('.table-edit-rows-wrapper')

      expect(bodyContent.offsetHeight).toBeCloseTo(2000)
      expect(bodyContent.offsetWidth).toBeCloseTo(tableElement.clientWidth - tableElement.tableGutter.offsetWidth, -2)

    describe 'when resized', ->
      beforeEach ->
        tableElement.style.width = '800px'
        tableElement.style.height = '600px'

      it 'repaints the table', ->
        tableElement.pollDOM()
        nextAnimationFrame()
        expect(tableShadowRoot.querySelectorAll('.table-edit-rows')).not.toEqual(18)
    describe 'the columns widths', ->
      beforeEach ->
        cells = tableShadowRoot.querySelectorAll('atom-table-cell[data-row="0"]')

      describe 'without any columns layout data', ->
        it 'has cells that all have the same width', ->
          expect(cell.offsetWidth).toEqual(100) for cell,i in cells

      describe 'with a columns layout defined', ->
        beforeEach ->
          tableEditor.setScreenColumnWidthAt(0, 100)
          tableEditor.setScreenColumnWidthAt(1, 200)
          tableEditor.setScreenColumnWidthAt(2, 300)
          nextAnimationFrame()

        it 'modifies the columns width', ->
          widths = [100,200,300]
          expect(cell.offsetWidth).toEqual(widths[i]) for cell,i in cells

        it 'sets the proper width and height on the table rows container', ->
          bodyContent = tableShadowRoot.querySelector('.table-edit-rows-wrapper')

          expect(bodyContent.offsetHeight).toEqual(2000)
          expect(bodyContent.offsetWidth).toEqual(600)

        it 'sets the proper widths on the cells', ->
          widths = [100,200,300]
          expect(cell.offsetWidth).toEqual(widths[i]) for cell,i in cells

        it 'sets the proper widths on the header cells', ->
          cells = tableShadowRoot.querySelectorAll('atom-table-header-cell')
          widths = [100,200,300]
          expect(cell.offsetWidth).toEqual(widths[i]) for cell,i in cells

        describe 'when the content is scroll horizontally', ->
          beforeEach ->
            tableElement.getColumnsScrollContainer().scrollLeft = 100
            scroll(tableElement.getRowsContainer())
            nextAnimationFrame()

          it 'scrolls the header by the same amount', ->
            expect(tableElement.getColumnsContainer().scrollLeft).toEqual(100)

      describe 'with alignments defined in the columns models', ->
        it 'sets the cells text-alignement using the model data', ->
          tableEditor.getScreenColumn(0).align = 'right'
          tableEditor.getScreenColumn(1).align = 'center'

          nextAnimationFrame()

          expect(tableElement.getScreenCellAtPosition([0,0]).style.textAlign).toEqual('right')
          expect(tableElement.getScreenCellAtPosition([0,1]).style.textAlign).toEqual('center')
          expect(tableElement.getScreenCellAtPosition([0,2]).style.textAlign).toEqual('left')

    describe 'with a custom cell renderer defined on a column', ->
      it 'uses the provided renderer to render the columns cells', ->
        tableEditor.getScreenColumn(2).cellRender = (cell) -> "foo: #{cell.value}"

        nextAnimationFrame()

        expect(tableElement.getScreenCellAtPosition([0,2]).textContent).toEqual('foo: yes')

  describe 'when scrolled by 100px', ->
    beforeEach ->
      tableElement.setScrollTop 100
      nextAnimationFrame()

    describe '::getFirstVisibleRow', ->
      it 'returns 5', ->
        expect(tableElement.getFirstVisibleRow()).toEqual(5)

    describe '::getLastVisibleRow', ->
      it 'returns 13', ->
        expect(tableElement.getLastVisibleRow()).toEqual(13)

    it 'translates the content by the amount of scroll', ->
      expect(tableElement.getRowsContainer().scrollTop).toEqual(100)

    it 'renders new rows', ->
      cells = tableShadowRoot.querySelectorAll('atom-table-cell')
      expect(cells.length).toEqual(23 * 3)

  describe 'when scrolled by 300px', ->
    beforeEach ->
      tableElement.setScrollTop(300)
      nextAnimationFrame()

    describe '::getFirstVisibleRow', ->
      it 'returns 15', ->
        expect(tableElement.getFirstVisibleRow()).toEqual(15)

    describe '::getLastVisibleRow', ->
      it 'returns 23', ->
        expect(tableElement.getLastVisibleRow()).toEqual(23)

    it 'renders new rows', ->
      cells = tableShadowRoot.querySelectorAll('atom-table-cell')
      expect(cells.length).toEqual(28 * 3)

  describe 'when the table rows are modified', ->
    describe 'by adding one at the end', ->
      it 'does not render new rows', ->
        tableEditor.addRow ['foo', 'bar', 'baz']

        nextAnimationFrame()

        cells = tableShadowRoot.querySelectorAll('atom-table-cell')
        expect(cells.length).toEqual(18 * 3)

    describe 'by adding one at the begining', ->
      it 'updates the rows', ->
        expect(tableShadowRoot.querySelector('atom-table-cell').textContent).toEqual('row0')

        tableEditor.addRowAt 0, ['foo', 'bar', 'baz']

        nextAnimationFrame()

        cells = tableShadowRoot.querySelectorAll('atom-table-cell')
        cell = tableElement.getScreenCellAtPosition([0,0])
        expect(cells.length).toEqual(18 * 3)
        expect(cell.dataset.row).toEqual('0')
        expect(cell.textContent).toEqual('foo')

    describe 'by adding one in the middle', ->
      it 'updates the rows', ->
        cell = tableShadowRoot.querySelector('atom-table-cell[data-row="6"]')
        expect(cell.textContent).toEqual('row6')

        tableEditor.addRowAt 6, ['foo', 'bar', 'baz']

        nextAnimationFrame()

        cells = tableShadowRoot.querySelectorAll('atom-table-cell')
        cell = tableElement.getScreenCellAtPosition([6,0])
        expect(cells.length).toEqual(18 * 3)
        expect(cell.textContent).toEqual('foo')

    describe 'by updating the content of a row', ->
      it 'update the rows', ->
        cell = tableElement.getScreenCellAtPosition([6,0])
        expect(cell.textContent).toEqual('row6')

        tableEditor.setValueAtScreenPosition([6,0], 'foo')

        nextAnimationFrame()

        expect(cell.textContent).toEqual('foo')

  describe 'setting a custom height for a row', ->
    beforeEach ->
      tableEditor.setRowHeightAt(2, 100)
      nextAnimationFrame()

    it 'sets the proper height on the table body content', ->
      bodyContent = tableShadowRoot.querySelector('.table-edit-rows-wrapper')

      expect(bodyContent.offsetHeight).toBeCloseTo(2080)

    it "renders the row's cells with the provided height", ->
      cell = tableShadowRoot.querySelector('atom-table-cell[data-row="2"]')

      expect(cell.offsetHeight).toEqual(100)

    it 'offsets the cells after the modified one', ->
      cell = tableShadowRoot.querySelector('atom-table-cell[data-row="3"]')

      expect(cell.style.top).toEqual('140px')

    it 'activates the cell under the mouse when pressed', ->
      cell = tableShadowRoot.querySelectorAll('atom-table-cell[data-row="3"]')[1]
      mousedown(cell)

      expect(tableEditor.getLastCursor().getValue()).toEqual(300)

    it 'gives the size of the cell to the editor when starting an edit', ->
      tableEditor.setCursorAtScreenPosition([2, 0])
      nextAnimationFrame()
      tableElement.startCellEdit()

      expect(tableElement.querySelector('atom-text-editor').offsetHeight).toEqual(100)

    it 'uses the offset to position the editor', ->
      tableEditor.setCursorAtScreenPosition([3, 0])
      nextAnimationFrame()
      tableElement.startCellEdit()

      editorBounds = tableElement.querySelector('atom-text-editor').getBoundingClientRect()
      cellBounds = tableShadowRoot.querySelector('atom-table-cell.active').getBoundingClientRect()
      expect(editorBounds.top).toBeCloseTo(cellBounds.top)
      expect(editorBounds.left).toBeCloseTo(cellBounds.left)
      expect(editorBounds.width).toBeCloseTo(cellBounds.width)
      expect(editorBounds.height).toBeCloseTo(cellBounds.height)

    describe 'by changing the option on the row itself', ->
      beforeEach ->
        tableEditor.setScreenRowHeightAt(2, 50)
        nextAnimationFrame()

      it 'sets the proper height on the table body content', ->
        bodyContent = tableShadowRoot.querySelector('.table-edit-rows-wrapper')

        expect(bodyContent.offsetHeight).toBeCloseTo(2030)

      it "renders the row's cells with the provided height", ->
        cell = tableShadowRoot.querySelector('atom-table-cell[data-row="2"]')

        expect(cell.offsetHeight).toEqual(50)

      it 'offsets the cells after the modified one', ->
        cell = tableShadowRoot.querySelector('atom-table-cell[data-row="3"]')

        expect(cell.style.top).toEqual('90px')

    describe 'when scrolled by 300px', ->
      beforeEach ->
        tableElement.setScrollTop(300)
        nextAnimationFrame()

      it 'activates the cell under the mouse when pressed', ->
        cell = tableShadowRoot.querySelectorAll('atom-table-cell[data-row="14"] ')[1]
        mousedown(cell)

        expect(tableEditor.getLastCursor().getValue()).toEqual(1400)

    describe 'when scrolled all way down to the bottom edge', ->
      beforeEach ->
        tableElement.setScrollTop(2000)
        nextAnimationFrame()

      it 'activates the cell under the mouse when pressed', ->
        cell = tableShadowRoot.querySelector('atom-table-cell:nth-last-child(2)')
        mousedown(cell)

        expect(tableEditor.getLastCursor().getValue()).toEqual(9900)

  #    ##     ## ########    ###    ########  ######## ########
  #    ##     ## ##         ## ##   ##     ## ##       ##     ##
  #    ##     ## ##        ##   ##  ##     ## ##       ##     ##
  #    ######### ######   ##     ## ##     ## ######   ########
  #    ##     ## ##       ######### ##     ## ##       ##   ##
  #    ##     ## ##       ##     ## ##     ## ##       ##    ##
  #    ##     ## ######## ##     ## ########  ######## ##     ##

  it 'has a header', ->
    expect(tableShadowRoot.querySelector('.table-edit-header')).toExist()

  describe 'header', ->
    header = null

    beforeEach ->
      header = tableElement.head

    it 'has as many cells as there is columns in the table', ->
      cells = tableShadowRoot.querySelectorAll('atom-table-header-cell')
      expect(cells.length).toEqual(3)
      expect(cells[0].textContent).toEqual('key')
      expect(cells[1].textContent).toEqual('value')
      expect(cells[2].textContent).toEqual('foo')

    it 'has cells that contains a resize handle', ->
      expect(tableShadowRoot.querySelectorAll('.column-resize-handle').length).toEqual(tableShadowRoot.querySelectorAll('atom-table-header-cell').length)

    it 'has cells that contains an edit button', ->
      expect(tableShadowRoot.querySelectorAll('.column-edit-action').length).toEqual(tableShadowRoot.querySelectorAll('atom-table-header-cell').length)

    it 'has cells that have the same width as the body cells', ->
      tableElement.setColumnsWidths([0.2, 0.3, 0.5])
      nextAnimationFrame()

      cells = tableShadowRoot.querySelectorAll('atom-table-header-cell')
      rowCells = tableShadowRoot.querySelectorAll('atom-table-cell[data-row="0"]')

      expect(cells[0].offsetWidth).toBeCloseTo(rowCells[0].offsetWidth, -2)
      expect(cells[1].offsetWidth).toBeCloseTo(rowCells[1].offsetWidth, -2)
      expect(cells[2].offsetWidth).toBeCloseTo(rowCells[rowCells.length-1].offsetWidth, -2)

    it 'contains a filler div to figurate the gutter width', ->
      expect(header.querySelector('.table-edit-header-filler')).toExist()

    describe 'clicking on a header cell', ->
      [column] = []

      beforeEach ->
        column = tableShadowRoot.querySelector('atom-table-header-cell:last-child')
        mousedown(column)

      it 'changes the sort order to use the clicked column', ->
        expect(tableEditor.order).toEqual('foo')
        expect(tableEditor.direction).toEqual(1)

      describe 'a second time', ->
        beforeEach ->
          mousedown(column)

        it 'toggles the sort direction', ->
          expect(tableEditor.order).toEqual('foo')
          expect(tableEditor.direction).toEqual(-1)

      describe 'a third time', ->
        beforeEach ->
          mousedown(column)
          mousedown(column)

        it 'removes the sorting order', ->
          expect(tableEditor.order).toBeNull()

      describe 'when the columns size have been changed', ->
        beforeEach ->
          tableElement.setColumnsWidths([100, 200, 300])
          nextAnimationFrame()

          column = tableShadowRoot.querySelector('atom-table-header-cell:nth-child(2)')
          mousedown(column)

        it 'changes the sort order to use the clicked column', ->
          expect(tableEditor.order).toEqual('value')
          expect(tableEditor.direction).toEqual(1)

    describe 'dragging a resize handle', ->
      beforeEach ->
        tableElement.absoluteColumnsWidths = true
        tableElement.setColumnsWidths([100,100,100])

      it 'resizes the columns', ->
        handle = header.querySelectorAll('.column-resize-handle')[1]
        {x, y} = objectCenterCoordinates(handle)

        mousedown(handle)
        mouseup(handle, x + 50, y)

        expect(tableEditor.getScreenColumn(0).width).toBeCloseTo(100)
        expect(tableEditor.getScreenColumn(1).width).toBeCloseTo(150)
        expect(tableEditor.getScreenColumn(2).width).toBeCloseTo(100)

    describe 'clicking on a header cell edit action button', ->
      [editor, editorElement, cell, cellOffset] = []

      beforeEach ->
        cell = header.querySelector('atom-table-header-cell')
        action = cell.querySelector('.column-edit-action')
        cellOffset = cell.getBoundingClientRect()

        click(action)

        editorElement = tableElement.querySelector('atom-text-editor')
        editor = editorElement.model

      it 'starts the edition of the column name', ->
        editorOffset = editorElement.getBoundingClientRect()

        expect(editorElement).toExist(1)
        expect(editorOffset.top).toBeCloseTo(cellOffset.top, -2)
        expect(editorOffset.left).toBeCloseTo(cellOffset.left, -2)
        expect(editorElement.offsetWidth).toBeCloseTo(cell.offsetWidth, -2)
        expect(editorElement.offsetHeight).toBeCloseTo(cell.offsetHeight, -2)

      it 'gives the focus to the editor', ->
        expect(editorElement.matches('.is-focused')).toBeTruthy()

      it 'fills the editor with the cell value', ->
        expect(editor.getText()).toEqual('key')

      it 'cleans the buffer history', ->
        expect(editor.getBuffer().history.undoStack.length).toEqual(0)
        expect(editor.getBuffer().history.redoStack.length).toEqual(0)

      describe 'core:cancel', ->
        it 'closes the editor', ->
          atom.commands.dispatch(editorElement, 'core:cancel')
          expect(tableElement.isEditing()).toBeFalsy()

      describe 'core:confirm', ->
        beforeEach ->
          editor.setText('foobar')
          atom.commands.dispatch(editorElement, 'core:confirm')

        it 'closes the editor', ->
          expect(isVisible(editorElement)).toBeFalsy()

        it 'gives the focus back to the table view', ->
          expect(tableElement.hiddenInput.matches(':focus')).toBeTruthy()

        it 'changes the cell value', ->
          expect(tableEditor.getScreenColumn(0).name).toEqual('foobar')

      describe 'table-edit:move-right', ->
        it 'confirms the current edit and moves the active cursor to the right', ->
          spyOn(tableElement, 'moveRight')
          editor.setText('Foo Bar')
          atom.commands.dispatch(editorElement, 'table-edit:move-right')

          expect(tableElement.isEditing()).toBeFalsy()
          expect(tableElement.moveRight).toHaveBeenCalled()
          expect(tableEditor.getScreenColumn(0).name).toEqual('Foo Bar')

      describe 'table-edit:move-left', ->
        it 'confirms the current edit and moves the active cursor to the left', ->
          spyOn(tableElement, 'moveLeft')
          editor.setText('Foo Bar')
          atom.commands.dispatch(editorElement, 'table-edit:move-left')

          expect(tableElement.isEditing()).toBeFalsy()
          expect(tableElement.moveLeft).toHaveBeenCalled()
          expect(tableEditor.getScreenColumn(0).name).toEqual('Foo Bar')

  #     ######   ##     ## ######## ######## ######## ########
  #    ##    ##  ##     ##    ##       ##    ##       ##     ##
  #    ##        ##     ##    ##       ##    ##       ##     ##
  #    ##   #### ##     ##    ##       ##    ######   ########
  #    ##    ##  ##     ##    ##       ##    ##       ##   ##
  #    ##    ##  ##     ##    ##       ##    ##       ##    ##
  #     ######    #######     ##       ##    ######## ##     ##

  describe 'gutter', ->
    describe 'when scrolled', ->
      beforeEach ->
        tableElement.setScrollTop(300)
        nextAnimationFrame()

      it 'scrolls the header by the same amount', ->
        expect(tableElement.getGutter().scrollTop).toEqual(300)

    describe 'rows numbers', ->
      [content, gutter] = []

      beforeEach ->
        content = tableShadowRoot.querySelector('.table-edit-content')
        gutter = tableShadowRoot.querySelector('.table-edit-gutter')

      it 'contains a filler div to set the gutter width', ->
        expect(gutter.querySelector('.table-edit-gutter-filler')).toExist()

      it 'matches the count of rows in the body', ->
        expect(gutter.querySelectorAll('atom-table-gutter-cell').length)
        .toEqual(18)

      it 'contains resize handlers for each row', ->
        expect(gutter.querySelectorAll('atom-table-gutter-cell .row-resize-handle').length)
        .toEqual(18)

      xdescribe 'pressing the mouse on a gutter cell', ->
        beforeEach ->
          cell = gutter.querySelectorAll('atom-table-gutter-cell')[2]
          mousedown(cell)
          nextAnimationFrame()

        it 'selects the whole line', ->
          expect(tableEditor.getLastCursor().getPosition()).toEqual([2,0])
          expect(tableEditor.getLastSelection().getRange()).toEqual([[2,0],[2,2]])

        describe 'then dragging the mouse down', ->
          beforeEach ->
            cell = gutter.querySelectorAll('atom-table-gutter-cell')[4]
            mousemove(cell)
            nextAnimationFrame()

          it 'expands the selection with the covered rows', ->
            expect(tableEditor.getLastCursor().getPosition()).toEqual([2,0])
            expect(tableElement.getLastSelection().getRange()).toEqual([[2,0],[4,2]])

          describe 'until reaching the bottom of the view', ->
            beforeEach ->
              cell = gutter.querySelectorAll('atom-table-gutter-cell')[10]
              mousemove(cell)
              nextAnimationFrame()

            it 'scrolls the view', ->
              expect(tableElement.getRowsContainer().scrollTop).toBeGreaterThan(0)

          describe 'then dragging the mouse up', ->
            beforeEach ->
              cell = gutter.querySelectorAll('atom-table-gutter-cell')[0]
              mousemove(cell)
              nextAnimationFrame()

            it 'changes the selection using the active cell as pivot', ->
              expect(tableEditor.getLastCursor().getPosition()).toEqual([2,0])
              expect(tableEditor.getLastSelection().getRange()).toEqual([[0,0],[2,2]])

      xdescribe 'dragging the mouse over gutter cells and reaching the top of the view', ->
        it 'scrolls the view', ->
          tableElement.setScrollTop(300)
          nextAnimationFrame()

          startCell = tableShadowRoot.querySelector('atom-table-gutter-cell:nth-child(12)')
          endCell = tableShadowRoot.querySelector('atom-table-gutter-cell:nth-child(9)')

          mousedown(startCell)
          mousemove(endCell)

          expect(tableElement.getRowsContainer().scrollTop).toBeLessThan(300)

      describe 'dragging the resize handler of a row number', ->
        it 'resize the row on mouse up', ->
          handle = tableShadowRoot.querySelectorAll('atom-table-gutter-cell .row-resize-handle')[2]
          {x, y} = objectCenterCoordinates(handle)

          mousedown(handle)
          mouseup(handle, x, y + 50)

          expect(tableEditor.getRowHeightAt(2)).toEqual(70)

        it 'displays a ruler when the drag have begun', ->
          ruler = tableShadowRoot.querySelector('.row-resize-ruler')

          expect(isVisible(ruler)).toBeFalsy()

          handle = tableShadowRoot.querySelectorAll('atom-table-gutter-cell .row-resize-handle')[2]
          mousedown(handle)

          expect(isVisible(ruler)).toBeTruthy()
          expect(ruler.getBoundingClientRect().top).toEqual(handle.getBoundingClientRect().top + handle.offsetHeight)

        it 'moves the handle during the drag', ->
          ruler = tableShadowRoot.querySelector('.row-resize-ruler')
          handle = tableShadowRoot.querySelectorAll('atom-table-gutter-cell .row-resize-handle')[2]
          {x, y} = objectCenterCoordinates(handle)

          mousedown(handle)
          mousemove(handle, x, y + 50)

          expect(ruler.getBoundingClientRect().top).toEqual(handle.getBoundingClientRect().top + handle.offsetHeight + 50)

        it 'hides the ruler on drag end', ->
          ruler = tableShadowRoot.querySelector('.row-resize-ruler')
          handle = tableShadowRoot.querySelectorAll('atom-table-gutter-cell .row-resize-handle')[2]
          mousedown(handle)
          mouseup(handle)

          expect(isVisible(ruler)).toBeFalsy()

        it 'stops the resize when the height is lower than the minimum row height', ->
          ruler = tableShadowRoot.querySelector('.row-resize-ruler')
          handle = tableShadowRoot.querySelectorAll('atom-table-gutter-cell .row-resize-handle')[2]
          {x, y} = objectCenterCoordinates(handle)

          mousedown(handle)
          mousemove(handle, x, y - 20)

          expect(ruler.getBoundingClientRect().top).toEqual(handle.getBoundingClientRect().top + handle.offsetHeight - 20)

          mouseup(handle, x, y - 20)

          expect(tableEditor.getRowHeightAt(2)).toEqual(10)

      describe 'when an editor is opened', ->
        [editor, editorElement] = []

        beforeEach ->
          tableElement.startCellEdit()
          editorElement = tableElement.querySelector('atom-text-editor')
          editor = editorElement.model

        it 'opens a text editor above the active cell', ->
          cell = tableShadowRoot.querySelector('atom-table-cell')
          cellOffset = cell.getBoundingClientRect()

          editorOffset = editorElement.getBoundingClientRect()

          expect(editorElement).toExist()
          expect(editorOffset.top).toBeCloseTo(cellOffset.top, -2)
          expect(editorOffset.left).toBeCloseTo(cellOffset.left, -2)
          expect(editorElement.offsetWidth).toBeCloseTo(cell.offsetWidth, -2)
          expect(editorElement.offsetHeight).toBeCloseTo(cell.offsetHeight, -2)

  #     ######   #######  ##    ## ######## ########   #######  ##
  #    ##    ## ##     ## ###   ##    ##    ##     ## ##     ## ##
  #    ##       ##     ## ####  ##    ##    ##     ## ##     ## ##
  #    ##       ##     ## ## ## ##    ##    ########  ##     ## ##
  #    ##       ##     ## ##  ####    ##    ##   ##   ##     ## ##
  #    ##    ## ##     ## ##   ###    ##    ##    ##  ##     ## ##
  #     ######   #######  ##    ##    ##    ##     ##  #######  ########

  ###
  it 'gains focus when mouse is pressed on the table view', ->
    mousedown(tableElement)

    expect(tableElement.hiddenInput.matches(':focus')).toBeTruthy()

  it 'activates the cell under the mouse when pressed', ->
    cell = tableShadowRoot.querySelector('atom-table-cell[data-row="3"][data-column="2"]')
    mousedown(cell)

    expect(tableElement.getLastActiveCell().getValue()).toEqual('no')

  it 'does not focus the hidden input twice when multiple press occurs', ->
    spyOn(tableElement.hiddenInput, 'focus').andCallThrough()

    mousedown(tableElement)
    mousedown(tableElement)

    expect(tableElement.hiddenInput.focus).toHaveBeenCalled()
    expect(tableElement.hiddenInput.focus.calls.length).toEqual(1)
    expect(tableElement.hiddenInput.matches(':focus')).toBeTruthy()

  it 'has an active cell', ->
    activeCell = tableElement.getLastActiveCell()
    expect(activeCell).toBeDefined()
    expect(activeCell.getValue()).toEqual('row0')

  it 'renders the active cell using a class', ->
    expect(tableShadowRoot.querySelectorAll('atom-table-header-cell.active-column').length).toEqual(1)
    expect(tableShadowRoot.querySelectorAll('atom-table-cell.active-row').length).toEqual(2)
    expect(tableShadowRoot.querySelectorAll('atom-table-cell.active').length).toEqual(1)
    expect(tableShadowRoot.querySelectorAll('atom-table-cell.active-column').length)
    .toBeGreaterThan(1)

  describe '::moveRight', ->
    it 'requests an update', ->
      spyOn(tableElement, 'requestUpdate')
      tableElement.moveRight()

      expect(tableElement.requestUpdate).toHaveBeenCalled()

    it 'attempts to make the active row visible', ->
      spyOn(tableElement, 'makeRowVisible')
      tableElement.moveRight()

      expect(tableElement.makeRowVisible).toHaveBeenCalled()

    it 'is triggered on core:move-right', ->
      spyOn(tableElement, 'moveRight')

      atom.commands.dispatch(tableElement, 'core:move-right')

      expect(tableElement.moveRight).toHaveBeenCalled()

    it 'moves the active cell cursor to the right', ->
      tableElement.moveRight()

      expect(tableElement.getLastActiveCell().getValue()).toEqual(0)

      tableElement.moveRight()

      expect(tableElement.getLastActiveCell().getValue()).toEqual('yes')

    it 'moves the active cell to the next row when on last cell of a row', ->
      tableElement.moveRight()
      tableElement.moveRight()
      tableElement.moveRight()
      expect(tableElement.getLastActiveCell().getValue()).toEqual('row1')

    it 'moves the active cell to the first row when on last cell of last row', ->
      tableElement.activeCellPosition.row = 99
      tableElement.activeCellPosition.column = 2

      tableElement.moveRight()
      expect(tableElement.getLastActiveCell().getValue()).toEqual('row0')

    xdescribe 'when the absoluteColumnsWidths setting is enabled', ->
      describe 'and the last column is partially hidden', ->
        beforeEach ->
          tableElement.setColumnsWidths([100, 200, 300])

          tableElement.moveRight()
          tableElement.moveRight()

        it 'scrolls the view to the right', ->
          rows = tableShadowRoot.querySelector('.table-edit-rows')
          expect(rows.scrollLeft).not.toEqual(0)

  describe '::moveLeft', ->
    it 'requests an update', ->
      spyOn(tableElement, 'requestUpdate')
      tableElement.moveLeft()

      expect(tableElement.requestUpdate).toHaveBeenCalled()

    it 'attempts to make the active row visible', ->
      spyOn(tableElement, 'makeRowVisible')
      tableElement.moveLeft()

      expect(tableElement.makeRowVisible).toHaveBeenCalled()

    it 'is triggered on core:move-left', ->
      spyOn(tableElement, 'moveLeft')

      atom.commands.dispatch(tableElement, 'core:move-left')

      expect(tableElement.moveLeft).toHaveBeenCalled()

    it 'moves the active cell to the last cell when on the first cell', ->
      tableElement.moveLeft()
      expect(tableElement.getLastActiveCell().getValue()).toEqual('no')

    it 'moves the active cell cursor to the left', ->
      tableElement.moveRight()
      tableElement.moveLeft()
      expect(tableElement.getLastActiveCell().getValue()).toEqual('row0')

    it 'moves the active cell cursor to the upper row', ->
      tableElement.moveRight()
      tableElement.moveRight()
      tableElement.moveRight()
      tableElement.moveLeft()
      expect(tableElement.getLastActiveCell().getValue()).toEqual('yes')

  describe '::moveUp', ->
    it 'requests an update', ->
      spyOn(tableElement, 'requestUpdate')
      tableElement.moveUp()

      expect(tableElement.requestUpdate).toHaveBeenCalled()

    it 'attempts to make the active row visible', ->
      spyOn(tableElement, 'makeRowVisible')
      tableElement.moveUp()

      expect(tableElement.makeRowVisible).toHaveBeenCalled()

    it 'is triggered on core:move-up', ->
      spyOn(tableElement, 'moveUp')

      atom.commands.dispatch(tableElement, 'core:move-up')

      expect(tableElement.moveUp).toHaveBeenCalled()

    it 'moves the active cell to the last row when on the first row', ->
      tableElement.moveUp()
      expect(tableElement.getLastActiveCell().getValue()).toEqual('row99')

    it 'moves the active cell on the upper row', ->
      tableElement.activeCellPosition.row = 10

      tableElement.moveUp()
      expect(tableElement.getLastActiveCell().getValue()).toEqual('row9')

  describe '::moveDown', ->
    it 'requests an update', ->
      spyOn(tableElement, 'requestUpdate')
      tableElement.moveDown()

      expect(tableElement.requestUpdate).toHaveBeenCalled()

    it 'attempts to make the active row visible', ->
      spyOn(tableElement, 'makeRowVisible')
      tableElement.moveDown()

      expect(tableElement.makeRowVisible).toHaveBeenCalled()

    it 'is triggered on core:move-down', ->
      spyOn(tableElement, 'moveDown')

      atom.commands.dispatch(tableElement, 'core:move-down')

      expect(tableElement.moveDown).toHaveBeenCalled()

    it 'moves the active cell to the row below', ->
      tableElement.moveDown()
      expect(tableElement.getLastActiveCell().getValue()).toEqual('row1')

    it 'moves the active cell to the first row when on the last row', ->
      tableElement.activeCellPosition.row = 99

      tableElement.moveDown()
      expect(tableElement.getLastActiveCell().getValue()).toEqual('row0')

  describe '::makeRowVisible', ->
    it 'scrolls the view until the passed-on row become visible', ->
      tableElement.makeRowVisible(50)

      expect(tableElement.getRowsContainer().scrollTop).toEqual(849)

  describe 'core:undo', ->
    it 'triggers an undo on the table', ->
      spyOn(table, 'undo')

      atom.commands.dispatch(tableElement, 'core:undo')

      expect(tableEditor.undo).toHaveBeenCalled()

  describe 'core:redo', ->
    it 'triggers an redo on the table', ->
      spyOn(table, 'redo')

      atom.commands.dispatch(tableElement, 'core:redo')

      expect(tableEditor.redo).toHaveBeenCalled()

  describe 'core:page-down', ->
    beforeEach ->
      atom.config.set 'table-edit.pageMovesAmount', 20

    it 'moves the active cell 20 rows below', ->
      atom.commands.dispatch(tableElement, 'core:page-down')

      expect(tableElement.activeCellPosition.row).toEqual(20)

    it 'stops to the last row without looping', ->
      tableElement.activeCellPosition.row = 90

      atom.commands.dispatch(tableElement, 'core:page-down')

      expect(tableElement.activeCellPosition.row).toEqual(99)

    describe 'with a custom amount on the instance', ->
      it 'moves the active cell 30 rows below', ->
        tableElement.pageMovesAmount = 30

        atom.commands.dispatch(tableElement, 'core:page-down')

        expect(tableElement.activeCellPosition.row).toEqual(30)

      it 'keeps using its own amount even when the config change', ->
        tableElement.pageMovesAmount = 30
        atom.config.set 'table-edit.pageMovesAmount', 50

        atom.commands.dispatch(tableElement, 'core:page-down')

        expect(tableElement.activeCellPosition.row).toEqual(30)

  describe 'core:page-up', ->
    beforeEach ->
      atom.config.set 'table-edit.pageMovesAmount', 20

    it 'moves the active cell 20 rows up', ->
      tableElement.activeCellPosition.row = 20

      atom.commands.dispatch(tableElement, 'core:page-up')

      expect(tableElement.activeCellPosition.row).toEqual(0)

    it 'stops to the first cell without looping', ->
      tableElement.activeCellPosition.row = 10

      atom.commands.dispatch(tableElement, 'core:page-up')

      expect(tableElement.activeCellPosition.row).toEqual(0)

  describe 'core:move-to-top', ->
    beforeEach ->
      atom.config.set 'table-edit.pageMovesAmount', 20

    it 'moves the active cell to the first row', ->
      tableElement.activeCellPosition.row = 50

      atom.commands.dispatch(tableElement, 'core:move-to-top')

      expect(tableElement.activeCellPosition.row).toEqual(0)

  describe 'core:move-to-bottom', ->
    beforeEach ->
      atom.config.set 'table-edit.pageMovesAmount', 20

    it 'moves the active cell to the first row', ->
      tableElement.activeCellPosition.row = 50

      atom.commands.dispatch(tableElement, 'core:move-to-bottom')

      expect(tableElement.activeCellPosition.row).toEqual(99)

  describe 'table-edit:insert-row-before', ->
    it 'inserts a new row before the active row', ->
      atom.commands.dispatch(tableElement, 'table-edit:insert-row-before')

      expect(tableEditor.getRow(0).getValues()).toEqual([null, null, null])

    it 'refreshes the rows offsets', ->
      tableElement.setRowHeightAt(0, 60)
      atom.commands.dispatch(tableElement, 'table-edit:insert-row-before')

      expect(tableElement.getRowHeightAt(0)).toEqual(tableElement.getRowHeight())
      expect(tableElement.getRowHeightAt(1)).toEqual(60)
      expect(tableElement.getRowOffsetAt(1)).toEqual(tableElement.getRowHeight())

    describe "when there's no rows in the table yet", ->
      beforeEach ->
        tableEditor.removeRowsInRange([0, Infinity])

      it 'creates a new row', ->
        atom.commands.dispatch(tableElement, 'table-edit:insert-row-before')

        expect(tableElement.getRowHeightAt(0)).toEqual(tableElement.getRowHeight())

  describe 'table-edit:insert-row-after', ->
    it 'inserts a new row after the active row', ->
      atom.commands.dispatch(tableElement, 'table-edit:insert-row-after')

      expect(tableEditor.getRow(1).getValues()).toEqual([null, null, null])

  describe 'table-edit:delete-row', ->
    it 'deletes the current active row', ->
      mockConfirm(0)
      atom.commands.dispatch(tableElement, 'table-edit:delete-row')

      expect(tableEditor.getRow(0).getValues()).toEqual(['row1', 100, 'no'])

    it 'asks for a confirmation', ->
      mockConfirm(0)
      atom.commands.dispatch(tableElement, 'table-edit:delete-row')

      expect(atom.confirm).toHaveBeenCalled()

    it 'does not remove the row when cancelled', ->
      mockConfirm(1)
      atom.commands.dispatch(tableElement, 'table-edit:delete-row')

      expect(tableEditor.getRow(0).getValues()).toEqual(['row0', 0, 'yes'])

    describe 'when the deleted row has a custom height', ->
      beforeEach ->
        spyOn(tableElement, 'computeRowOffsets')
        tableElement.setRowHeightAt(0, 100)
        mockConfirm(0)

      it 'removes the height entry', ->
        atom.commands.dispatch(tableElement, 'table-edit:delete-row')

        expect(tableElement.getRowHeightAt(0)).toEqual(20)

      it 'updates the rows offsets', ->
        expect(tableElement.computeRowOffsets).toHaveBeenCalled()

  describe 'table-edit:insert-column-before', ->
    it 'inserts a new column before the active column', ->
      atom.commands.dispatch(tableElement, 'table-edit:insert-column-before')

      expect(tableEditor.getRow(0).getValues()).toEqual([null, 'row0', 0, 'yes'])

    describe 'called several times', ->
      it 'creates incremental names for columns', ->
        atom.commands.dispatch(tableElement, 'table-edit:insert-column-before')
        atom.commands.dispatch(tableElement, 'table-edit:insert-column-before')

        expect(tableEditor.getColumn(0).name).toEqual('untitled_1')
        expect(tableEditor.getColumn(1).name).toEqual('untitled_0')

  describe 'table-edit:insert-column-after', ->
    it 'inserts a new column after the active column', ->
      atom.commands.dispatch(tableElement, 'table-edit:insert-column-after')

      expect(tableEditor.getRow(0).getValues()).toEqual(['row0', null, 0, 'yes'])

    describe 'called several times', ->
      it 'creates incremental names for columns', ->
        atom.commands.dispatch(tableElement, 'table-edit:insert-column-after')
        atom.commands.dispatch(tableElement, 'table-edit:insert-column-after')

        expect(tableEditor.getColumn(1).name).toEqual('untitled_1')
        expect(tableEditor.getColumn(2).name).toEqual('untitled_0')

  describe 'table-edit:delete-column', ->
    it 'deletes the current active column', ->
      mockConfirm(0)
      atom.commands.dispatch(tableElement, 'table-edit:delete-column')

      expect(tableEditor.getRow(0).getValues()).toEqual([0, 'yes'])

    it 'asks for a confirmation', ->
      mockConfirm(0)
      atom.commands.dispatch(tableElement, 'table-edit:delete-column')

      expect(atom.confirm).toHaveBeenCalled()

    it 'does not remove the column when cancelled', ->
      mockConfirm(1)
      atom.commands.dispatch(tableElement, 'table-edit:delete-column')

      expect(tableEditor.getRow(0).getValues()).toEqual(['row0', 0, 'yes'])

  ###
  #    ######## ########  #### ########
  #    ##       ##     ##  ##     ##
  #    ##       ##     ##  ##     ##
  #    ######   ##     ##  ##     ##
  #    ##       ##     ##  ##     ##
  #    ##       ##     ##  ##     ##
  #    ######## ########  ####    ##

  ###
  describe 'pressing a key when the table view has focus', ->
    beforeEach ->
      textInput(tableElement.hiddenInput, 'x')

    it 'starts the edition of the active cell', ->
      expect(tableElement.isEditing()).toBeTruthy()

    it 'fills the editor with the input data', ->
      editor = tableElement.querySelector('atom-text-editor').model
      expect(editor.getText()).toEqual('x')

  describe 'double clicking on a cell', ->
    beforeEach ->
      cell = tableShadowRoot.querySelector('atom-table-cell:last-child')
      dblclick(cell)

    it 'starts the edition of the cell', ->
      expect(tableElement.isEditing()).toBeTruthy()

  describe '::startCellEdit', ->
    [editor, editorElement] = []

    beforeEach ->
      tableElement.startCellEdit()
      editorElement = tableElement.querySelector('atom-text-editor')
      editor = editorElement.model

    it 'opens a text editor above the active cell', ->
      cell = tableShadowRoot.querySelector('atom-table-cell')
      cellOffset = cell.getBoundingClientRect()

      editorOffset = editorElement.getBoundingClientRect()

      expect(editorElement).toExist()
      expect(editorOffset.top).toBeCloseTo(cellOffset.top, -2)
      expect(editorOffset.left).toBeCloseTo(cellOffset.left, -2)
      expect(editorElement.offsetWidth).toBeCloseTo(cell.offsetWidth, -2)
      expect(editorElement.offsetHeight).toBeCloseTo(cell.offsetHeight, -2)

    it 'gives the focus to the editor', ->
      expect(editorElement.matches('.is-focused')).toBeTruthy()

    it 'fills the editor with the cell value', ->
      expect(editor.getText()).toEqual('row0')

    it 'cleans the buffer history', ->
      expect(editor.getBuffer().history.undoStack.length).toEqual(0)
      expect(editor.getBuffer().history.redoStack.length).toEqual(0)

  describe '::stopEdit', ->
    beforeEach ->
      tableElement.startCellEdit()
      tableElement.stopEdit()

    it 'closes the editor', ->
      expect(tableElement.isEditing()).toBeFalsy()
      expect(isVisible(tableElement.querySelector('atom-text-editor'))).toBeFalsy()

    it 'gives the focus back to the table view', ->
      expect(tableElement.hiddenInput.matches(':focus')).toBeTruthy()

    it 'leaves the cell value as is', ->
      expect(tableElement.getLastActiveCell().getValue()).toEqual('row0')

  describe 'with an editor opened', ->
    [editor, editorElement] = []

    beforeEach ->
      tableElement.startCellEdit()
      editorElement = tableElement.querySelector('atom-text-editor')
      editor = editorElement.model

    describe 'core:cancel', ->
      it 'closes the editor', ->
        atom.commands.dispatch(editorElement, 'core:cancel')
        expect(tableElement.isEditing()).toBeFalsy()

    describe 'table-edit:move-right', ->
      it 'confirms the current edit and moves the active cursor to the right', ->
        previousActiveCell = tableElement.getLastActiveCell()
        spyOn(tableElement, 'moveRight')
        editor.setText('Foo Bar')
        atom.commands.dispatch(editorElement, 'table-edit:move-right')

        expect(tableElement.isEditing()).toBeFalsy()
        expect(previousActiveCell.getValue()).toEqual('Foo Bar')
        expect(tableElement.moveRight).toHaveBeenCalled()

    describe 'table-edit:move-left', ->
      it 'confirms the current edit and moves the active cursor to the left', ->
        previousActiveCell = tableElement.getLastActiveCell()
        spyOn(tableElement, 'moveLeft')
        editor.setText('Foo Bar')
        atom.commands.dispatch(editorElement, 'table-edit:move-left')

        expect(tableElement.isEditing()).toBeFalsy()
        expect(previousActiveCell.getValue()).toEqual('Foo Bar')
        expect(tableElement.moveLeft).toHaveBeenCalled()

    describe 'core:confirm', ->
      describe 'when the content of the editor has changed', ->
        beforeEach ->
          editor.setText('foobar')
          atom.commands.dispatch(editorElement, 'core:confirm')

        it 'closes the editor', ->
          expect(tableShadowRoot.querySelectorAll('atom-text-editor').length).toEqual(0)

        it 'gives the focus back to the table view', ->
          expect(tableElement.hiddenInput.matches(':focus')).toBeTruthy()

        it 'changes the cell value', ->
          expect(tableElement.getLastActiveCell().getValue()).toEqual('foobar')

      describe 'when the content of the editor did not changed', ->
        beforeEach ->
          spyOn(tableElement.getLastActiveCell(), 'setValue').andCallThrough()
          atom.commands.dispatch(editorElement, 'core:confirm')

        it 'closes the editor', ->
          expect(isVisible(tableElement.querySelector('atom-text-editor'))).toBeFalsy()

        it 'gives the focus back to the table view', ->
          expect(tableElement.hiddenInput.matches(':focus')).toBeTruthy()

        it 'leaves the cell value as is', ->
          expect(tableElement.getLastActiveCell().getValue()).toEqual('row0')
          expect(tableElement.getLastActiveCell().setValue).not.toHaveBeenCalled()

    describe 'clicking on another cell', ->
      beforeEach ->
        cell = tableShadowRoot.querySelector('atom-table-cell[data-row="3"][data-column="2"]')
        mousedown(cell)

      it 'closes the editor', ->
        expect(tableElement.isEditing()).toBeFalsy()
  ###

  #     ######  ######## ##       ########  ######  ########
  #    ##    ## ##       ##       ##       ##    ##    ##
  #    ##       ##       ##       ##       ##          ##
  #     ######  ######   ##       ######   ##          ##
  #          ## ##       ##       ##       ##          ##
  #    ##    ## ##       ##       ##       ##    ##    ##
  #     ######  ######## ######## ########  ######     ##
  ###
  it 'has a selection', ->
    expect(tableElement.getSelection()).toEqual([[0,0], [0,0]])

  describe 'selection', ->
    it 'follows the active cell when it moves', ->
      tableElement.pageMovesAmount = 10
      tableElement.pageDown()
      tableElement.moveRight()

      expect(tableElement.getSelection()).toEqual([[10,1], [10,1]])

    it 'can spans on several rows and columns', ->
      tableElement.setSelection([[2,0],[3,2]])

      expect(tableElement.getSelection()).toEqual([[2,0],[3,2]])

    it 'marks the cells covered by the selection with a selected class', ->
      tableElement.setSelection([[2,0],[3,2]])

      nextAnimationFrame()

      expect(tableShadowRoot.querySelectorAll('atom-table-cell.selected').length).toEqual(6)

    it 'marks the row number with a selected class', ->
      tableElement.setSelection([[2,0],[3,2]])

      nextAnimationFrame()

      expect(tableShadowRoot.querySelectorAll('atom-table-gutter-cell.selected').length).toEqual(2)
  describe 'when the selection spans only one cell', ->
    it 'does not render the selection box', ->
      expect(tableShadowRoot.querySelector('.selection-box').style.display).toEqual('none')
      expect(tableShadowRoot.querySelector('.selection-box-handle').style.display).toEqual('none')

  describe 'when the selection spans many cells', ->
    [selectionBox, selectionBoxHandle] = []

    beforeEach ->
      tableElement.setSelection([[2,0],[3,2]])
      nextAnimationFrame()
      selectionBox = tableShadowRoot.querySelector('.selection-box')
      selectionBoxHandle = tableShadowRoot.querySelector('.selection-box-handle')

    it 'renders the selection box', ->
      expect(selectionBox).toExist()
      expect(selectionBoxHandle).toExist()

    it 'positions the selection box over the cells', ->
      cells = tableShadowRoot.querySelectorAll('atom-table-cell.selected')
      firstCell = tableElement.getScreenCellAtPosition([2,0])
      lastCell = tableElement.getScreenCellAtPosition([3,2])

      selectionBoxOffset = selectionBox.getBoundingClientRect()
      firstCellOffset = firstCell.getBoundingClientRect()

      expect(selectionBoxOffset.top).toEqual(firstCellOffset.top)
      expect(selectionBoxOffset.left).toEqual(firstCellOffset.left)
      expect(selectionBox.offsetWidth).toEqual(300)
      expect(selectionBox.offsetHeight).toEqual(firstCell.offsetHeight + lastCell.offsetHeight)

    it 'positions the selection box handle at the bottom right corner', ->
      cells = tableShadowRoot.querySelectorAll('atom-table-cell.selected')
      lastCell = tableElement.getScreenCellAtPosition([3,2])
      lastCellOffset = lastCell.getBoundingClientRect()
      selectionBoxHandleOffset = selectionBoxHandle.getBoundingClientRect()

      expect(selectionBoxHandleOffset.top).toBeCloseTo(lastCellOffset.bottom, -1)
      expect(selectionBoxHandleOffset.left).toBeCloseTo(lastCellOffset.right, -1)

    it 'positions the selection box over the cells', ->
      tableElement.setSelection([[2,1],[3,2]])
      nextAnimationFrame()

      selectionBox = tableShadowRoot.querySelector('.selection-box')
      cells = tableShadowRoot.querySelectorAll('atom-table-cell.selected')
      firstCell = tableElement.getScreenCellAtPosition([2,1])
      lastCell = tableElement.getScreenCellAtPosition([3,2])

      selectionBoxOffset = selectionBox.getBoundingClientRect()
      firstCellOffset = firstCell.getBoundingClientRect()
      lastCellOffset = lastCell.getBoundingClientRect()

      expect(selectionBoxOffset.top).toBeCloseTo(firstCellOffset.top, 0)
      expect(selectionBoxOffset.left).toBeCloseTo(firstCellOffset.left, 0)
      expect(selectionBox.offsetWidth).toBeCloseTo(lastCellOffset.right - firstCellOffset.left, -1)
      expect(selectionBox.offsetHeight).toBeCloseTo(firstCell.offsetHeight + lastCell.offsetHeight, 0)

    describe 'when the columns widths have been changed', ->
      beforeEach ->
        tableElement.setColumnsWidths([0.1, 0.1, 0.8])
        tableElement.setSelection([[2,0],[3,1]])
        nextAnimationFrame()

      it 'positions the selection box over the cells', ->
        cells = tableShadowRoot.querySelectorAll('atom-table-cell.selected')
        firstCell = tableElement.getScreenCellAtPosition([2,0])
        lastCell = tableElement.getScreenCellAtPosition([3,1])

        selectionBoxOffset = selectionBox.getBoundingClientRect()
        firstCellOffset = firstCell.getBoundingClientRect()

        expect(selectionBoxOffset.top).toBeCloseTo(firstCellOffset.top, -1)
        expect(selectionBoxOffset.left).toBeCloseTo(firstCellOffset.left, -1)
        expect(selectionBox.offsetWidth).toBeCloseTo(firstCell.offsetWidth + lastCell.offsetWidth, -1)
        expect(selectionBox.offsetHeight).toBeCloseTo(firstCell.offsetHeight + lastCell.offsetHeight, -1)

  describe '::setSelection', ->
    it 'change the active cell so that the upper left cell is active', ->
      tableElement.setSelection([[4,0],[6,2]])

      expect(tableElement.activeCellPosition).toEqual([4,0])

  describe '::selectionSpansManyCells', ->
    it 'returns true when the selection as at least two cells', ->
      tableElement.setSelection([[4,0],[6,2]])

      expect(tableElement.selectionSpansManyCells()).toBeTruthy()

  describe 'core:select-right', ->
    it 'expands the selection by one cell on the right', ->
      atom.commands.dispatch(tableElement, 'core:select-right')
      expect(tableElement.getSelection()).toEqual([[0,0],[0,1]])

    it 'stops at the last column', ->
      atom.commands.dispatch(tableElement, 'core:select-right')
      atom.commands.dispatch(tableElement, 'core:select-right')
      atom.commands.dispatch(tableElement, 'core:select-right')

      expect(tableElement.getSelection()).toEqual([[0,0],[0,2]])

    describe 'then triggering core:select-left', ->
      it 'collapse the selection back to the left', ->
        tableElement.activateCellAtPosition([0,1])

        atom.commands.dispatch(tableElement, 'core:select-right')
        atom.commands.dispatch(tableElement, 'core:select-left')

        expect(tableElement.getSelection()).toEqual([[0,1],[0,1]])

  describe 'core:select-left', ->
    beforeEach ->
      tableElement.activateCellAtPosition([0,2])

    it 'expands the selection by one cell on the left', ->
      atom.commands.dispatch(tableElement, 'core:select-left')
      expect(tableElement.getSelection()).toEqual([[0,1],[0,2]])

    it 'stops at the first column', ->
      atom.commands.dispatch(tableElement, 'core:select-left')
      atom.commands.dispatch(tableElement, 'core:select-left')
      atom.commands.dispatch(tableElement, 'core:select-left')
      expect(tableElement.getSelection()).toEqual([[0,0],[0,2]])

    describe 'then triggering core:select-right', ->
      it 'collapse the selection back to the right', ->
        tableElement.activateCellAtPosition([0,1])

        atom.commands.dispatch(tableElement, 'core:select-left')
        atom.commands.dispatch(tableElement, 'core:select-right')

        expect(tableElement.getSelection()).toEqual([[0,1],[0,1]])

  describe 'core:select-up', ->
    beforeEach ->
      tableElement.activateCellAtPosition([2,0])

    it 'expands the selection by one cell to the top', ->
      atom.commands.dispatch(tableElement, 'core:select-up')
      expect(tableElement.getSelection()).toEqual([[1,0],[2,0]])

    it 'stops at the first row', ->
      atom.commands.dispatch(tableElement, 'core:select-up')
      atom.commands.dispatch(tableElement, 'core:select-up')
      atom.commands.dispatch(tableElement, 'core:select-up')
      expect(tableElement.getSelection()).toEqual([[0,0],[2,0]])

    it 'scrolls the view to make the added row visible', ->
      tableElement.setScrollTop(200)
      tableElement.activateCellAtPosition([10,0])

      atom.commands.dispatch(tableElement, 'core:select-up')

      expect(tableElement.getRowsContainer().scrollTop).toEqual(180)

    describe 'then triggering core:select-down', ->
      it 'collapse the selection back to the bottom', ->
        tableElement.activateCellAtPosition([1,0])

        atom.commands.dispatch(tableElement, 'core:select-up')
        atom.commands.dispatch(tableElement, 'core:select-down')

        expect(tableElement.getSelection()).toEqual([[1,0],[1,0]])

  describe 'core:select-down', ->
    beforeEach ->
      tableElement.activateCellAtPosition([97,0])

    it 'expands the selection by one cell to the bottom', ->
      atom.commands.dispatch(tableElement, 'core:select-down')
      expect(tableElement.getSelection()).toEqual([[97,0],[98,0]])

    it 'stops at the last row', ->
      atom.commands.dispatch(tableElement, 'core:select-down')
      atom.commands.dispatch(tableElement, 'core:select-down')
      atom.commands.dispatch(tableElement, 'core:select-down')
      expect(tableElement.getSelection()).toEqual([[97,0],[99,0]])

    it 'scrolls the view to make the added row visible', ->
      tableElement.activateCellAtPosition([8,0])

      atom.commands.dispatch(tableElement, 'core:select-down')

      expect(tableElement.getRowsContainer().scrollTop).not.toEqual(0)

    describe 'then triggering core:select-up', ->
      it 'collapse the selection back to the bottom', ->
        tableElement.activateCellAtPosition([1,0])

        atom.commands.dispatch(tableElement, 'core:select-down')
        atom.commands.dispatch(tableElement, 'core:select-up')

        expect(tableElement.getSelection()).toEqual([[1,0],[1,0]])

  describe 'table-edit:select-to-end-of-line', ->
    it 'expands the selection to the end of the current row', ->
      atom.commands.dispatch(tableElement, 'table-edit:select-to-end-of-line')

      expect(tableElement.getSelection()).toEqual([[0,0],[0,2]])

    describe 'then triggering table-edit:select-to-beginning-of-line', ->
      it 'expands the selection to the beginning of the current row', ->
        tableElement.activateCellAtPosition([0,1])

        atom.commands.dispatch(tableElement, 'table-edit:select-to-end-of-line')
        atom.commands.dispatch(tableElement, 'table-edit:select-to-beginning-of-line')

        expect(tableElement.getSelection()).toEqual([[0,0],[0,1]])

  describe 'table-edit:select-to-beginning-of-line', ->
    it 'expands the selection to the beginning of the current row', ->
      tableElement.activateCellAtPosition([0,2])

      atom.commands.dispatch(tableElement, 'table-edit:select-to-beginning-of-line')

      expect(tableElement.getSelection()).toEqual([[0,0],[0,2]])

    describe 'table-edit:select-to-end-of-line', ->
      it 'expands the selection to the end of the current row', ->
        tableElement.activateCellAtPosition([0,1])

        atom.commands.dispatch(tableElement, 'table-edit:select-to-beginning-of-line')
        atom.commands.dispatch(tableElement, 'table-edit:select-to-end-of-line')

        expect(tableElement.getSelection()).toEqual([[0,1],[0,2]])

  describe 'table-edit:select-to-end-of-table', ->
    it 'expands the selection to the end of the table', ->
      atom.commands.dispatch(tableElement, 'table-edit:select-to-end-of-table')

      expect(tableElement.getSelection()).toEqual([[0,0],[99,0]])

    it 'scrolls the view to make the added row visible', ->
      atom.commands.dispatch(tableElement, 'table-edit:select-to-end-of-table')

      expect(tableElement.getRowsContainer().scrollTop).not.toEqual(0)

    describe 'then triggering table-edit:select-to-beginning-of-table', ->
      it 'expands the selection to the beginning of the table', ->
        tableElement.activateCellAtPosition([1,0])

        atom.commands.dispatch(tableElement, 'table-edit:select-to-end-of-table')
        atom.commands.dispatch(tableElement, 'table-edit:select-to-beginning-of-table')

        expect(tableElement.getSelection()).toEqual([[0,0],[1,0]])

  describe 'table-edit:select-to-beginning-of-table', ->
    it 'expands the selection to the beginning of the table', ->
      tableElement.activateCellAtPosition([2,0])

      atom.commands.dispatch(tableElement, 'table-edit:select-to-beginning-of-table')

      expect(tableElement.getSelection()).toEqual([[0,0],[2,0]])

    it 'scrolls the view to make the added row visible', ->
      tableElement.activateCellAtPosition([99,0])

      atom.commands.dispatch(tableElement, 'table-edit:select-to-beginning-of-table')

      expect(tableElement.getRowsContainer().scrollTop).toEqual(0)

    describe 'table-edit:select-to-end-of-table', ->
      it 'expands the selection to the end of the table', ->
        tableElement.activateCellAtPosition([1,0])

        atom.commands.dispatch(tableElement, 'table-edit:select-to-beginning-of-table')
        atom.commands.dispatch(tableElement, 'table-edit:select-to-end-of-table')

        expect(tableElement.getSelection()).toEqual([[1,0],[99,0]])

  describe 'dragging the mouse pressed over cell', ->
    it 'creates a selection with the cells from the mouse movements', ->
      startCell = tableShadowRoot.querySelector('atom-table-cell[data-row="3"][data-column="0"]')
      endCell = tableShadowRoot.querySelector('atom-table-cell[data-row="6"][data-column="2"]')

      mousedown(startCell)
      mousemove(endCell)

      expect(tableElement.getSelection()).toEqual([[3,0],[6,2]])

      mousedown(endCell)
      mousemove(startCell)

      expect(tableElement.getSelection()).toEqual([[3,0],[6,2]])

    it 'scrolls the view when the selection reach the last row', ->
      startCell = tableShadowRoot.querySelector('atom-table-cell[data-row="6"][data-column="0"]')
      endCell = tableShadowRoot.querySelector('atom-table-cell[data-row="9"][data-column="2"]')

      mousedown(startCell)
      mousemove(endCell)

      expect(tableElement.getRowsContainer().scrollTop).toBeGreaterThan(0)

    it 'scrolls the view when the selection reach the first row', ->
      tableElement.setScrollTop(300)
      nextAnimationFrame()

      startCell = tableShadowRoot.querySelector('atom-table-cell[data-row="11"][data-column="0"]')
      endCell = tableShadowRoot.querySelector('atom-table-cell[data-row="8"][data-column="2"]')

      mousedown(startCell)
      mousemove(endCell)

      expect(tableElement.getRowsContainer().scrollTop).toBeLessThan(300)

  describe 'when the columns widths have been changed', ->
    beforeEach ->
      tableElement.setColumnsWidths([100, 200, 300])
      nextAnimationFrame()

    it 'creates a selection with the cells from the mouse movements', ->
      startCell = tableShadowRoot.querySelector('atom-table-cell[data-row="3"][data-column="0"]')
      endCell = tableShadowRoot.querySelector('atom-table-cell[data-row="6"][data-column="1"]')

      mousedown(startCell)
      mousemove(endCell)

      expect(tableElement.getSelection()).toEqual([[3,0],[6,1]])

  describe 'dragging the selection box handle', ->
    [handle, handleOffset] = []

    beforeEach ->
      tableElement.setSelection([[2,0],[2,1]])
      nextAnimationFrame()
      handle = tableShadowRoot.querySelector('.selection-box-handle')

      mousedown(handle)

    describe 'to the right', ->
      beforeEach ->
        handleOffset = handle.getBoundingClientRect()
        mousemove(handle, handleOffset.left + 50, handleOffset.top-2)

      it 'expands the selection to the right', ->
        expect(tableElement.getSelection()).toEqual([[2,0],[2,2]])
  ###

  #     ######   #######  ########  ######## #### ##    ##  ######
  #    ##    ## ##     ## ##     ##    ##     ##  ###   ## ##    ##
  #    ##       ##     ## ##     ##    ##     ##  ####  ## ##
  #     ######  ##     ## ########     ##     ##  ## ## ## ##   ####
  #          ## ##     ## ##   ##      ##     ##  ##  #### ##    ##
  #    ##    ## ##     ## ##    ##     ##     ##  ##   ### ##    ##
  #     ######   #######  ##     ##    ##    #### ##    ##  ######

  ###
  describe 'sorting', ->
    describe 'when a column have been set as the table order', ->
      beforeEach ->
        tableElement.sortBy 'value', -1
        nextAnimationFrame()

      it 'sorts the rows accordingly', ->
        expect(tableShadowRoot.querySelector('atom-table-cell').textContent).toEqual('row99')

      it 'leaves the active cell position as it was before', ->
        expect(tableElement.activeCellPosition).toEqual([0,0])
        expect(tableElement.getLastActiveCell()).toEqual(tableEditor.getValueAtPosition([99,0]))

      it 'sets the proper height on the table rows container', ->
        expect(tableShadowRoot.querySelector('.table-edit-rows-wrapper').offsetHeight).toEqual(2000)

      it 'decorates the table cells with a class', ->
        expect(tableShadowRoot.querySelectorAll('atom-table-cell.order').length).toBeGreaterThan(1)

      it 'decorates the table header cell with a class', ->
        expect(tableShadowRoot.querySelectorAll('atom-table-header-cell.order.descending').length).toEqual(1)

        tableElement.toggleSortDirection()
        nextAnimationFrame()

        expect(tableShadowRoot.querySelectorAll('atom-table-header-cell.order.ascending').length).toEqual(1)

      describe 'opening an editor', ->
        beforeEach ->
          tableElement.startCellEdit()

        it 'opens the editor at the cell position', ->
          editorOffset = tableElement.querySelector('atom-text-editor').getBoundingClientRect()
          cellOffset = tableElement.getScreenCellAtPosition([0,0]).getBoundingClientRect()

          expect(editorOffset.top).toBeCloseTo(cellOffset.top, -1)
          expect(editorOffset.left).toBeCloseTo(cellOffset.left, -1)

      describe '::toggleSortDirection', ->
        it 'changes the direction of the table sort', ->
          tableElement.toggleSortDirection()
          nextAnimationFrame()

          expect(tableElement.direction).toEqual(1)
          expect(tableShadowRoot.querySelector('atom-table-cell').textContent).toEqual('row0')

      describe '::resetSort', ->
        beforeEach ->
          tableElement.resetSort()
          nextAnimationFrame()

        it 'clears the value for table order', ->
          expect(tableElement.order).toBeNull()

        it 'reorder the table in its initial order', ->
          expect(tableShadowRoot.querySelector('atom-table-cell').textContent).toEqual('row0')
  ###
