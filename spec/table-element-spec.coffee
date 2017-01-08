require './helpers/spec-helper'

path = require 'path'

Table = require '../lib/table'
TableEditor = require '../lib/table-editor'
TableElement = require '../lib/table-element'
TableCellElement = require '../lib/table-cell-element'
TableSelectionElement = require '../lib/table-selection-element'
Column = require '../lib/display-column'
{mousedown, mousemove, mouseup, scroll, click, dblclick, textInput, objectCenterCoordinates} = require './helpers/events'

stylesheetPath = path.resolve __dirname, '..', 'styles', 'tablr.less'
stylesheet = "
  #{atom.themes.loadStylesheet(stylesheetPath)}

  tablr-editor {
    z-index: 100000;
    height: 200px;
    width: 400px;
  }

  tablr-editor .tablr-header {
    height: 27px;
    border: 1px solid black;
  }

  tablr-editor .tablr-body {
    border: 1px solid black;
  }

  tablr-editor tablr-cell {
    border: none;
    padding: 0;
  }

  tablr-editor .measuring-cell {
    border-bottom: none;
  }

  tablr-editor tablr-gutter-cell {
    border: none;
    padding: 0;
  }

  tablr-editor .selection-box-handle {
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

describe 'tableElement', ->
  [tableElement, tableEditor, nextAnimationFrame, noAnimationFrame, requestAnimationFrameSafe, styleNode, row, cells, jasmineContent] = []

  afterEach ->
    window.requestAnimationFrame = requestAnimationFrameSafe

  beforeEach ->
    jasmineContent = document.body.querySelector('#jasmine-content')

    atom.config.set('tablr.defaultColumnNamingMethod', 'alphabetic')

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

    atom.config.set 'editor.useShadowDom', false
    atom.config.set 'tablr.tableEditor.rowHeight', 20
    atom.config.set 'tablr.tableEditor.columnWidth', 100
    atom.config.set 'tablr.tableEditor.rowOverdraw', 10
    atom.config.set 'tablr.tableEditor.columnOverdraw', 2
    atom.config.set 'tablr.tableEditor.minimumRowHeight', 10
    atom.config.set 'tablr.tableEditor.minimumColumnWidth', 40
    atom.config.set 'tablr.tableEditor.scrollSpeedDuringDrag', 20

    tableElement = atom.views.getView(tableEditor)

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

    describe 'by putting an tablr-editor tag in the DOM', ->
      beforeEach ->
        container.innerHTML = "<tablr-editor>"
        element = container.firstChild
        nextAnimationFrame()

      it 'creates a default model to boot the table', ->
        model = element.getModel()
        expect(model).toBeDefined()
        expect(model.getScreenColumnCount()).toEqual(1)
        expect(model.getScreenRowCount()).toEqual(1)

      it 'renders the default model', ->
        cell = element.querySelectorAll('tablr-cell')
        expect(cell.length).toEqual(1)

  describe 'when the table is destroyed', ->
    beforeEach ->
      tableEditor.destroy()

    it 'is destroyed', ->
      expect(tableElement.isDestroyed()).toBeTruthy()

    it 'removes its model', ->
      expect(tableElement.getModel()).toBeNull()

    it 'clears its cell pools', ->
      expect(tableElement.totalCellCount()).toEqual(0)
      expect(tableElement.totalGutterCellCount()).toEqual(0)
      expect(tableElement.totalHeaderCellCount()).toEqual(0)

    it 'no longer accepts update request', ->
      tableElement.updateRequested = false
      tableElement.requestUpdate()

      expect(tableElement.updateRequested).toBeFalsy()

    it 'throws an exception if an attempt is made to set its model again', ->
      expect(-> tableElement.setModel(tableEditor)).toThrow()

  #     ######   #######  ##    ## ######## ######## ##    ## ########
  #    ##    ## ##     ## ###   ##    ##    ##       ###   ##    ##
  #    ##       ##     ## ####  ##    ##    ##       ####  ##    ##
  #    ##       ##     ## ## ## ##    ##    ######   ## ## ##    ##
  #    ##       ##     ## ##  ####    ##    ##       ##  ####    ##
  #    ##    ## ##     ## ##   ###    ##    ##       ##   ###    ##
  #     ######   #######  ##    ##    ##    ######## ##    ##    ##

  it 'has a body', ->
    expect(tableElement.querySelector('.tablr-body')).toExist()

  describe 'when not scrolled yet', ->
    it 'renders the lines at the top of the table', ->
      cells = tableElement.querySelectorAll('tablr-cell')
      expect(cells.length).toEqual(18 * 3)
      expect(cells[0].dataset.row).toEqual('0')
      expect(cells[cells.length - 1].dataset.row).toEqual('17')

    describe '::getFirstVisibleRow', ->
      it 'returns 0', ->
        expect(tableElement.getFirstVisibleRow()).toEqual(0)

    describe '::getLastVisibleRow', ->
      it 'returns 8', ->
        expect(tableElement.getLastVisibleRow()).toEqual(8)

  describe 'when the scrollPastEnd setting is enabled', ->
    beforeEach ->
      atom.config.set('tablr.tableEditor.scrollPastEnd', true)
      nextAnimationFrame()

    it 'increases the dimensions of the cells container', ->
      expect(tableElement.tableCells.offsetHeight).toBeCloseTo(2000 + tableElement.tableRows.offsetHeight - 60)
      expect(tableElement.tableCells.offsetWidth).toBeCloseTo(300 + tableElement.tableRows.offsetWidth - 100)

  describe 'once rendered', ->
    beforeEach ->
      cells = tableElement.querySelectorAll('tablr-cell[data-row="0"]')

    it 'has as many columns as the model row', ->
      expect(cells.length).toEqual(3)

    it 'renders undefined cells based on a config', ->
      atom.config.set('tablr.tableEditor.undefinedDisplay', 'foo')

      tableEditor.setValueAtPosition([0,0], undefined)
      nextAnimationFrame()
      expect(tableElement.getScreenCellAtPosition([0,0]).textContent).toEqual('foo')

    it 'renders undefined cells based on the view property', ->
      tableElement.undefinedDisplay = 'bar'
      atom.config.set('tablr.tableEditor.undefinedDisplay', 'foo')

      tableEditor.setValueAtPosition([0,0], undefined)
      nextAnimationFrame()
      expect(tableElement.getScreenCellAtPosition([0,0]).textContent).toEqual('bar')

    describe 'when the cell content is bigger than the available space', ->
      beforeEach ->
        tableEditor.setValueAtPosition([0,0], "some really long text")
        nextAnimationFrame()

    it 'sets the proper width and height on the table rows container', ->
      bodyContent = tableElement.querySelector('.tablr-rows-wrapper')

      expect(bodyContent.offsetHeight).toBeCloseTo(2000)
      expect(bodyContent.offsetWidth).toBeCloseTo(tableElement.clientWidth - tableElement.tableGutter.offsetWidth, -2)

    describe 'when resized', ->
      beforeEach ->
        tableElement.style.width = '800px'
        tableElement.style.height = '600px'

      it 'repaints the table', ->
        tableElement.pollDOM()
        nextAnimationFrame()
        expect(tableElement.querySelectorAll('.tablr-rows')).not.toEqual(18)
    describe 'the columns widths', ->
      beforeEach ->
        cells = tableElement.querySelectorAll('tablr-cell[data-row="0"]')

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
          bodyContent = tableElement.querySelector('.tablr-rows-wrapper')

          expect(bodyContent.offsetHeight).toEqual(2000)
          expect(bodyContent.offsetWidth).toEqual(600)

        it 'sets the proper widths on the cells', ->
          widths = [100,200,300]
          expect(cell.offsetWidth).toEqual(widths[i]) for cell,i in cells

        it 'sets the proper widths on the header cells', ->
          cells = tableElement.querySelectorAll('tablr-header-cell')
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
      cells = tableElement.querySelectorAll('tablr-cell')
      expect(cells.length).toEqual(18 * 3)

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
      cells = tableElement.querySelectorAll('tablr-cell')
      expect(cells.length).toEqual(28 * 3)

  describe 'when the table rows are modified', ->
    describe 'by adding one at the end', ->
      it 'does not render new rows', ->
        tableEditor.addRow ['foo', 'bar', 'baz']

        nextAnimationFrame()

        cells = tableElement.querySelectorAll('tablr-cell')
        expect(cells.length).toEqual(18 * 3)

    describe 'by adding one at the begining', ->
      it 'updates the rows', ->
        expect(tableElement.querySelector('tablr-cell').textContent).toEqual('row0')

        tableEditor.addRowAt 0, ['foo', 'bar', 'baz']

        nextAnimationFrame()

        cells = tableElement.querySelectorAll('tablr-cell')
        cell = tableElement.getScreenCellAtPosition([0,0])
        expect(cells.length).toEqual(18 * 3)
        expect(cell.dataset.row).toEqual('0')
        expect(cell.textContent).toEqual('foo')

    describe 'by adding one in the middle', ->
      it 'updates the rows', ->
        cell = tableElement.querySelector('tablr-cell[data-row="6"]')
        expect(cell.textContent).toEqual('row6')

        tableEditor.addRowAt 6, ['foo', 'bar', 'baz']

        nextAnimationFrame()

        cells = tableElement.querySelectorAll('tablr-cell')
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
      bodyContent = tableElement.querySelector('.tablr-rows-wrapper')

      expect(bodyContent.offsetHeight).toBeCloseTo(2080)

    it "renders the row's cells with the provided height", ->
      cell = tableElement.querySelector('tablr-cell[data-row="2"]')

      expect(cell.offsetHeight).toEqual(100)

    it 'offsets the cells after the modified one', ->
      cell = tableElement.querySelector('tablr-cell[data-row="3"]')

      expect(cell.style.top).toEqual('140px')

    it 'activates the cell under the mouse when pressed', ->
      cell = tableElement.querySelectorAll('tablr-cell[data-row="3"]')[1]
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
      cellBounds = tableElement.querySelector('tablr-cell.active').getBoundingClientRect()
      expect(editorBounds.top).toBeCloseTo(cellBounds.top)
      expect(editorBounds.left).toBeCloseTo(cellBounds.left)
      expect(editorBounds.width).toBeCloseTo(cellBounds.width)
      expect(editorBounds.height).toBeCloseTo(cellBounds.height)

    describe 'by changing the option on the row itself', ->
      beforeEach ->
        tableEditor.setScreenRowHeightAt(2, 50)
        nextAnimationFrame()

      it 'sets the proper height on the table body content', ->
        bodyContent = tableElement.querySelector('.tablr-rows-wrapper')

        expect(bodyContent.offsetHeight).toBeCloseTo(2030)

      it "renders the row's cells with the provided height", ->
        cell = tableElement.querySelector('tablr-cell[data-row="2"]')

        expect(cell.offsetHeight).toEqual(50)

      it 'offsets the cells after the modified one', ->
        cell = tableElement.querySelector('tablr-cell[data-row="3"]')

        expect(cell.style.top).toEqual('90px')

    describe 'when scrolled by 300px', ->
      beforeEach ->
        tableElement.setScrollTop(300)
        nextAnimationFrame()

      it 'activates the cell under the mouse when pressed', ->
        cell = tableElement.querySelectorAll('tablr-cell[data-row="14"] ')[1]
        mousedown(cell)

        expect(tableEditor.getLastCursor().getValue()).toEqual(1400)

    describe 'when scrolled all way down to the bottom edge', ->
      beforeEach ->
        tableElement.setScrollTop(2000)
        nextAnimationFrame()

      it 'activates the cell under the mouse when pressed', ->
        cell = tableElement.querySelector('tablr-cell[data-row="99"][data-column="1"]')
        mousedown(cell)

        expect(tableEditor.getLastCursor().getValue()).toEqual(9900)

  describe '::measureColumnWidth', ->
    [dummyCell] = []
    beforeEach ->
      content = 'abcdefghijklmnopqrstuvwxyz'
      tableEditor.setValueAtPosition([50,1], content)
      dummyCell = document.createElement('d')
      dummyCell.className = 'tablr-cell'
      dummyCell.textContent = content
      jasmineContent.appendChild(dummyCell)

    it 'measures the column cells and returns the biggest width', ->
      expect(tableElement.measureColumnWidth(1)).toEqual(dummyCell.offsetWidth)

  describe '::measureRowHeight', ->
    [dummyCell] = []
    beforeEach ->
      content = 'abcdef\nghijklmn\nopqrst\nuvwxyz'
      tableEditor.setValueAtPosition([50,1], content)
      dummyCell = document.createElement('d')
      dummyCell.className = 'tablr-cell'
      dummyCell.textContent = content
      dummyCell.style.height = 'auto'
      jasmineContent.appendChild(dummyCell)

    it 'measures the column cells and returns the biggest width', ->
      expect(tableElement.measureRowHeight(50)).toEqual(dummyCell.offsetHeight)

  #    ##     ## ########    ###    ########  ######## ########
  #    ##     ## ##         ## ##   ##     ## ##       ##     ##
  #    ##     ## ##        ##   ##  ##     ## ##       ##     ##
  #    ######### ######   ##     ## ##     ## ######   ########
  #    ##     ## ##       ######### ##     ## ##       ##   ##
  #    ##     ## ##       ##     ## ##     ## ##       ##    ##
  #    ##     ## ######## ##     ## ########  ######## ##     ##

  it 'has a header', ->
    expect(tableElement.querySelector('.tablr-header')).toExist()

  describe 'header', ->
    header = null

    beforeEach ->
      header = tableElement.head

    it 'has as many cells as there is columns in the table', ->
      cells = tableElement.querySelectorAll('tablr-header-cell')
      expect(cells.length).toEqual(3)
      expect(cells[0].textContent).toEqual('key')
      expect(cells[1].textContent).toEqual('value')
      expect(cells[2].textContent).toEqual('foo')

    it 'has cells that contains a resize handle', ->
      expect(tableElement.querySelectorAll('.column-resize-handle').length).toEqual(tableElement.querySelectorAll('tablr-header-cell').length)

    it 'has cells that contains an edit button', ->
      expect(tableElement.querySelectorAll('.column-edit-action').length).toEqual(tableElement.querySelectorAll('tablr-header-cell').length)

    it 'has cells that have the same width as the body cells', ->
      tableElement.setColumnsWidths([0.2, 0.3, 0.5])
      nextAnimationFrame()

      cells = tableElement.querySelectorAll('tablr-header-cell')
      rowCells = tableElement.querySelectorAll('tablr-cell[data-row="0"]')

      expect(cells[0].offsetWidth).toBeCloseTo(rowCells[0].offsetWidth, -2)
      expect(cells[1].offsetWidth).toBeCloseTo(rowCells[1].offsetWidth, -2)
      expect(cells[2].offsetWidth).toBeCloseTo(rowCells[rowCells.length-1].offsetWidth, -2)

    it 'contains a filler div to figurate the gutter width', ->
      expect(header.querySelector('.tablr-header-filler')).toExist()

    describe 'clicking on a header cell', ->
      [column] = []

      beforeEach ->
        column = tableElement.querySelector('tablr-header-cell:last-child')
        mousedown(column)

      it 'changes the sort order to use the clicked column', ->
        expect(tableEditor.order).toEqual(2)
        expect(tableEditor.direction).toEqual(1)

      describe 'a second time', ->
        beforeEach ->
          mousedown(column)

        it 'toggles the sort direction', ->
          expect(tableEditor.order).toEqual(2)
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

          column = tableElement.querySelector('tablr-header-cell:nth-child(2)')
          mousedown(column)

        it 'changes the sort order to use the clicked column', ->
          expect(tableEditor.order).toEqual(1)
          expect(tableEditor.direction).toEqual(1)

      describe 'clicking on a header cell apply sort action', ->
        [cell] = []

        beforeEach ->
          cell = header.querySelector('tablr-header-cell .column-apply-sort-action')

          spyOn(tableElement, 'applySort')

          click(cell)

        it 'invokes the applySort method', ->
          expect(tableElement.applySort).toHaveBeenCalled()

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

      it 'displays a ruler when the drag have begun', ->
        ruler = tableElement.querySelector('.column-resize-ruler')

        expect(isVisible(ruler)).toBeFalsy()

        handle = tableElement.querySelectorAll('tablr-header-cell .column-resize-handle')[2]
        mousedown(handle)

        expect(isVisible(ruler)).toBeTruthy()
        expect(ruler.getBoundingClientRect().left).toEqual(Math.floor(handle.getBoundingClientRect().left + handle.offsetWidth - 1))

      it 'moves the handle during the drag', ->
        ruler = tableElement.querySelector('.column-resize-ruler')
        handle = tableElement.querySelectorAll('tablr-header-cell .column-resize-handle')[2]
        {x, y} = objectCenterCoordinates(handle)

        mousedown(handle)
        mousemove(handle, x + 50, y)

        expect(ruler.getBoundingClientRect().left).toEqual(handle.getBoundingClientRect().left + 50)

      it 'hides the ruler on drag end', ->
        ruler = tableElement.querySelector('.column-resize-ruler')
        handle = tableElement.querySelectorAll('tablr-header-cell .column-resize-handle')[2]
        mousedown(handle)
        mouseup(handle)

        expect(isVisible(ruler)).toBeFalsy()

      it 'stops the resize when the height is lower than the minimum column height', ->
        ruler = tableElement.querySelector('.column-resize-ruler')
        handle = tableElement.querySelectorAll('tablr-header-cell .column-resize-handle')[2]
        {x, y} = objectCenterCoordinates(handle)

        mousedown(handle)
        mousemove(handle, x - 100, y)

        expect(ruler.getBoundingClientRect().left).toEqual(handle.getBoundingClientRect().left - 58 + handle.offsetWidth)

        mouseup(handle, x - 100, y)

        expect(tableEditor.getScreenColumnWidthAt(2)).toEqual(atom.config.get('tablr.tableEditor.minimumColumnWidth'))

    describe 'clicking on a header cell fit column action', ->
      [cell] = []

      beforeEach ->
        cell = header.querySelector('tablr-header-cell .column-fit-action')

        spyOn(tableElement, 'fitColumnToContent')

        click(cell)

      it 'invokes the fitColumnToContent method', ->
        expect(tableElement.fitColumnToContent).toHaveBeenCalledWith(0)

    describe 'clicking on a header cell edit action button', ->
      [editor, editorElement, cell, cellOffset] = []

      startHeaderCellEdit = (selector) ->
        cell = header.querySelector(selector)
        action = cell.querySelector('.column-edit-action')
        cellOffset = cell.getBoundingClientRect()

        click(action)

        editorElement = tableElement.querySelector('atom-text-editor')
        editor = editorElement.model

      confirmHeaderCellEdit = (value='') ->
        editor.setText(value)
        atom.commands.dispatch(editorElement, 'core:confirm')

      editHeaderCell = (selector, value) ->
        startHeaderCellEdit(selector)
        confirmHeaderCellEdit(value)

      describe 'that does not have a name', ->
        beforeEach ->
          tableEditor.insertColumnBefore()
          tableEditor.insertColumnBefore()
          tableEditor.insertColumnBefore()
          nextAnimationFrame()

          startHeaderCellEdit('tablr-header-cell')

        it 'opens the editor with the dynamic name as content', ->
          expect(editor.getText()).toEqual('A')

        describe 'core:confirm', ->
          describe 'when the editor is still on the dynamic name', ->
            it 'does not changes the cell value', ->
              atom.commands.dispatch(editorElement, 'core:confirm')
              expect(tableEditor.getScreenColumn(0).name).toEqual(undefined)

          describe 'when the editor is empty', ->
            it 'does not changes the cell value', ->
              confirmHeaderCellEdit()
              expect(tableEditor.getScreenColumn(0).name).toEqual(undefined)

          describe 'when the editor is not empty', ->
            it 'changes the column name', ->
              confirmHeaderCellEdit('oof')
              expect(tableEditor.getScreenColumn(0).name).toEqual('oof')

          describe 'when several header cells are edited consecutively', ->
            beforeEach ->
              confirmHeaderCellEdit('oof')
              editHeaderCell('tablr-header-cell:nth-child(2)', 'FFF')
              editHeaderCell('tablr-header-cell:nth-child(3)', 'GGG')

            it 'changes each column name accordingly', ->
              expect(tableEditor.getScreenColumn(0).name).toEqual('oof')
              expect(tableEditor.getScreenColumn(1).name).toEqual('FFF')
              expect(tableEditor.getScreenColumn(2).name).toEqual('GGG')

            it 'updates the header cells', ->
              nextAnimationFrame()

              expect(header.querySelector('tablr-header-cell').textContent).toEqual('oof')
              expect(header.querySelector('tablr-header-cell:nth-child(2)').textContent).toEqual('FFF')
              expect(header.querySelector('tablr-header-cell:nth-child(3)').textContent).toEqual('GGG')

      describe 'that have a name', ->
        beforeEach ->
          cell = header.querySelector('tablr-header-cell')
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
          if parseFloat(atom.getVersion()) >= 1.13 and process.platform is 'darwin'
            expect(document.activeElement).toBe(editorElement.querySelector('input'))
          else
            expect(document.activeElement).toBe(editorElement)

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
            expect(document.activeElement).toBe(tableElement.hiddenInput)
            expect(tableElement.hasFocus()).toBeTruthy()

          it 'changes the cell value', ->
            expect(tableEditor.getScreenColumn(0).name).toEqual('foobar')

        describe 'tablr:move-right-in-selection', ->
          it 'confirms the current edit and moves the active cursor to the right', ->
            spyOn(tableElement, 'moveRightInSelection')
            editor.setText('Foo Bar')
            atom.commands.dispatch(editorElement, 'tablr:move-right-in-selection')

            expect(tableElement.isEditing()).toBeFalsy()
            expect(tableElement.moveRightInSelection).toHaveBeenCalled()
            expect(tableEditor.getScreenColumn(0).name).toEqual('Foo Bar')

        describe 'tablr:move-left-in-selection', ->
          it 'confirms the current edit and moves the active cursor to the left', ->
            spyOn(tableElement, 'moveLeftInSelection')
            editor.setText('Foo Bar')
            atom.commands.dispatch(editorElement, 'tablr:move-left-in-selection')

            expect(tableElement.isEditing()).toBeFalsy()
            expect(tableElement.moveLeftInSelection).toHaveBeenCalled()
            expect(tableEditor.getScreenColumn(0).name).toEqual('Foo Bar')

    describe 'when the element has the read-only attribute', ->
      beforeEach ->
        tableElement.setAttribute('read-only', true)

      describe 'clicking on a header cell edit action button', ->
        beforeEach ->
          cell = header.querySelector('tablr-header-cell')
          action = cell.querySelector('.column-edit-action')

          click(action)

        it 'starts the edition of the column name', ->
          expect(tableElement.isEditing()).toBeFalsy()
          expect(tableElement.querySelector('atom-text-editor')).not.toExist()

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
        content = tableElement.querySelector('.tablr-content')
        gutter = tableElement.querySelector('.tablr-gutter')

      it 'contains a filler div to set the gutter width', ->
        expect(gutter.querySelector('.tablr-gutter-filler')).toExist()

      it 'matches the count of rows in the body', ->
        expect(gutter.querySelectorAll('tablr-gutter-cell').length)
        .toEqual(18)

      it 'contains resize handlers for each row', ->
        expect(gutter.querySelectorAll('tablr-gutter-cell .row-resize-handle').length)
        .toEqual(18)

      describe 'pressing the mouse on a gutter cell', ->
        beforeEach ->
          cell = tableElement.gutterCells[2]
          mousedown(cell)
          nextAnimationFrame()

        it 'selects the whole line', ->
          expect(tableEditor.getLastCursor().getPosition()).toEqual([2,0])
          expect(tableEditor.getLastSelection().getRange()).toEqual([[2,0],[3,3]])

        describe 'then dragging the mouse down', ->
          beforeEach ->
            cell = gutter.querySelectorAll('tablr-gutter-cell')[4]
            mousemove(cell)
            nextAnimationFrame()

          it 'expands the selection with the covered rows', ->
            expect(tableEditor.getLastCursor().getPosition()).toEqual([2,0])
            expect(tableEditor.getLastSelection().getRange()).toEqual([[2,0],[5,3]])

          describe 'until reaching the bottom of the view', ->
            beforeEach ->
              cell = gutter.querySelectorAll('tablr-gutter-cell')[10]
              mousemove(cell)
              nextAnimationFrame()

            it 'scrolls the view', ->
              expect(tableElement.getRowsContainer().scrollTop).toBeGreaterThan(0)

          describe 'then starting a new one with the cmd key pressed', ->
            beforeEach ->
              cell = gutter.querySelectorAll('tablr-gutter-cell')[4]
              mouseup(cell)


              cellStart = tableElement.gutterCells[6]
              cellEnd = tableElement.gutterCells[8]
              mousedown(cellStart, metaKey: true)
              mousemove(cellEnd, metaKey: true)
              nextAnimationFrame()

            it 'adds a new selection', ->
              expect(tableEditor.getSelections().length).toEqual(2)

          describe 'then dragging the mouse up', ->
            beforeEach ->
              cell = gutter.querySelectorAll('tablr-gutter-cell')[0]
              mousemove(cell)
              nextAnimationFrame()

            it 'changes the selection using the cursor as pivot', ->
              expect(tableEditor.getLastCursor().getPosition()).toEqual([2,0])
              expect(tableEditor.getLastSelection().getRange()).toEqual([[0,0],[3,3]])

      describe 'dragging the mouse over gutter cells and reaching the top of the view', ->
        it 'scrolls the view', ->
          tableElement.setScrollTop(300)
          nextAnimationFrame()

          startCell = tableElement.querySelector('tablr-gutter-cell:nth-child(12)')
          endCell = tableElement.querySelector('tablr-gutter-cell:nth-child(9)')

          mousedown(startCell)
          mousemove(endCell)

          expect(tableElement.getRowsContainer().scrollTop).toBeLessThan(300)

      describe 'dragging the resize handler of a row number', ->
        it 'resize the row on mouse up', ->
          handle = tableElement.querySelectorAll('tablr-gutter-cell .row-resize-handle')[2]
          {x, y} = objectCenterCoordinates(handle)

          mousedown(handle)
          mouseup(handle, x, y + 50)

          expect(tableEditor.getRowHeightAt(2)).toEqual(70)

        it 'displays a ruler when the drag have begun', ->
          ruler = tableElement.querySelector('.row-resize-ruler')

          expect(isVisible(ruler)).toBeFalsy()

          handle = tableElement.querySelectorAll('tablr-gutter-cell .row-resize-handle')[2]
          mousedown(handle)

          expect(isVisible(ruler)).toBeTruthy()
          expect(ruler.getBoundingClientRect().top).toEqual(handle.getBoundingClientRect().top + handle.offsetHeight)

        it 'moves the handle during the drag', ->
          ruler = tableElement.querySelector('.row-resize-ruler')
          handle = tableElement.querySelectorAll('tablr-gutter-cell .row-resize-handle')[2]
          {x, y} = objectCenterCoordinates(handle)

          mousedown(handle)
          mousemove(handle, x, y + 50)

          expect(ruler.getBoundingClientRect().top).toEqual(y + 50 - ruler.offsetHeight)

        it 'hides the ruler on drag end', ->
          ruler = tableElement.querySelector('.row-resize-ruler')
          handle = tableElement.querySelectorAll('tablr-gutter-cell .row-resize-handle')[2]
          mousedown(handle)
          mouseup(handle)

          expect(isVisible(ruler)).toBeFalsy()

        it 'stops the resize when the height is lower than the minimum row height', ->
          ruler = tableElement.querySelector('.row-resize-ruler')
          handle = tableElement.querySelectorAll('tablr-gutter-cell .row-resize-handle')[2]
          {x, y} = objectCenterCoordinates(handle)

          mousedown(handle)
          mousemove(handle, x, y - 20)

          expect(ruler.getBoundingClientRect().top).toEqual(y - 10 + handle.offsetHeight / 2)

          mouseup(handle, x, y - 20)

          expect(tableEditor.getRowHeightAt(2)).toEqual(10)

      describe 'when an editor is opened', ->
        [editor, editorElement] = []

        beforeEach ->
          tableElement.startCellEdit()
          editorElement = tableElement.querySelector('atom-text-editor')
          editor = editorElement.model

        it 'opens a text editor above the cursor', ->
          cell = tableElement.querySelector('tablr-cell')
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

  it 'gains focus when mouse is pressed on the table view', ->
    mousedown(tableElement)

    expect(document.activeElement).toBe(tableElement.hiddenInput)
    expect(tableElement.hasFocus()).toBeTruthy()

  it 'activates the cell under the mouse when pressed', ->
    cell = tableElement.querySelector('tablr-cell[data-row="3"][data-column="2"]')
    mousedown(cell)

    expect(tableEditor.getLastCursor().getValue()).toEqual('no')

  it 'does not focus the hidden input twice when multiple press occurs', ->
    spyOn(tableElement.hiddenInput, 'focus').andCallThrough()

    mousedown(tableElement)
    mousedown(tableElement)

    expect(tableElement.hiddenInput.focus).toHaveBeenCalled()
    expect(tableElement.hiddenInput.focus.calls.length).toEqual(1)
    expect(document.activeElement).toBe(tableElement.hiddenInput)
    expect(tableElement.hasFocus()).toBeTruthy()

  it 'has an cursor', ->
    cursor = tableEditor.getLastCursor()
    expect(cursor).toBeDefined()
    expect(cursor.getValue()).toEqual('row0')

  it 'renders the cursor using a class', ->
    expect(tableElement.querySelectorAll('tablr-header-cell.active-column').length).toEqual(1)
    expect(tableElement.querySelectorAll('tablr-gutter-cell.active-row').length).toEqual(1)
    expect(tableElement.querySelectorAll('tablr-cell.active').length).toEqual(1)

  describe 'core:move-right', ->
    it 'requests an update', ->
      spyOn(tableElement, 'requestUpdate')
      atom.commands.dispatch(tableElement, 'core:move-right')

      expect(tableElement.requestUpdate).toHaveBeenCalled()

    it 'attempts to make the active row visible', ->
      spyOn(tableElement, 'makeRowVisible')
      atom.commands.dispatch(tableElement, 'core:move-right')

      expect(tableElement.makeRowVisible).toHaveBeenCalled()

    it 'moves the cursor cursor to the right', ->
      atom.commands.dispatch(tableElement, 'core:move-right')

      expect(tableEditor.getLastCursor().getValue()).toEqual(0)

      atom.commands.dispatch(tableElement, 'core:move-right')

      expect(tableEditor.getLastCursor().getValue()).toEqual('yes')

    it 'moves the cursor to the next row when on last cell of a row', ->
      atom.commands.dispatch(tableElement, 'core:move-right')
      atom.commands.dispatch(tableElement, 'core:move-right')
      atom.commands.dispatch(tableElement, 'core:move-right')
      expect(tableEditor.getLastCursor().getValue()).toEqual('row1')

    it 'moves the cursor to the first row when on last cell of last row', ->
      tableEditor.setCursorAtScreenPosition([99, 2])

      atom.commands.dispatch(tableElement, 'core:move-right')
      expect(tableEditor.getLastCursor().getValue()).toEqual('row0')

  describe 'core:move-left', ->
    it 'requests an update', ->
      spyOn(tableElement, 'requestUpdate')
      atom.commands.dispatch(tableElement, 'core:move-left')

      expect(tableElement.requestUpdate).toHaveBeenCalled()

    it 'attempts to make the active row visible', ->
      spyOn(tableElement, 'makeRowVisible')
      atom.commands.dispatch(tableElement, 'core:move-left')

      expect(tableElement.makeRowVisible).toHaveBeenCalled()

    it 'moves the cursor to the last cell when on the first cell', ->
      atom.commands.dispatch(tableElement, 'core:move-left')
      expect(tableEditor.getLastCursor().getValue()).toEqual('no')

    it 'moves the cursor cursor to the left', ->
      atom.commands.dispatch(tableElement, 'core:move-right')
      atom.commands.dispatch(tableElement, 'core:move-left')
      expect(tableEditor.getLastCursor().getValue()).toEqual('row0')

    it 'moves the cursor cursor to the upper row', ->
      atom.commands.dispatch(tableElement, 'core:move-right')
      atom.commands.dispatch(tableElement, 'core:move-right')
      atom.commands.dispatch(tableElement, 'core:move-right')
      atom.commands.dispatch(tableElement, 'core:move-left')
      expect(tableEditor.getLastCursor().getValue()).toEqual('yes')

  describe 'core:move-up', ->
    it 'requests an update', ->
      spyOn(tableElement, 'requestUpdate')
      atom.commands.dispatch(tableElement, 'core:move-up')

      expect(tableElement.requestUpdate).toHaveBeenCalled()

    it 'attempts to make the active row visible', ->
      spyOn(tableElement, 'makeRowVisible')
      atom.commands.dispatch(tableElement, 'core:move-up')

      expect(tableElement.makeRowVisible).toHaveBeenCalled()

    it 'moves the cursor to the last row when on the first row', ->
      atom.commands.dispatch(tableElement, 'core:move-up')
      expect(tableEditor.getLastCursor().getValue()).toEqual('row99')

    it 'moves the cursor on the upper row', ->
      tableEditor.setCursorAtScreenPosition([10, 0])

      atom.commands.dispatch(tableElement, 'core:move-up')
      expect(tableEditor.getLastCursor().getValue()).toEqual('row9')

  describe 'core:move-down', ->
    it 'requests an update', ->
      spyOn(tableElement, 'requestUpdate')
      atom.commands.dispatch(tableElement, 'core:move-down')

      expect(tableElement.requestUpdate).toHaveBeenCalled()

    it 'attempts to make the active row visible', ->
      spyOn(tableElement, 'makeRowVisible')
      atom.commands.dispatch(tableElement, 'core:move-down')

      expect(tableElement.makeRowVisible).toHaveBeenCalled()

    it 'moves the cursor to the row below', ->
      atom.commands.dispatch(tableElement, 'core:move-down')
      expect(tableEditor.getLastCursor().getValue()).toEqual('row1')

    it 'moves the cursor to the first row when on the last row', ->
      tableEditor.setCursorAtScreenPosition([99, 0])

      atom.commands.dispatch(tableElement, 'core:move-down')
      expect(tableEditor.getLastCursor().getValue()).toEqual('row0')

  describe '::makeRowVisible', ->
    it 'scrolls the view until the passed-on row become visible', ->
      tableElement.makeRowVisible(50)

      expect(tableElement.getRowsContainer().scrollTop).toEqual(849)

  describe 'core:page-down', ->
    beforeEach ->
      atom.config.set 'tablr.tableEditor.pageMoveRowAmount', 20

    it 'moves the cursor 20 rows below', ->
      atom.commands.dispatch(tableElement, 'core:page-down')

      expect(tableEditor.getCursorPosition().row).toEqual(20)

    it 'stops to the last row without looping', ->
      tableEditor.setCursorAtScreenPosition([90, 0])

      atom.commands.dispatch(tableElement, 'core:page-down')

      expect(tableEditor.getCursorPosition().row).toEqual(99)

    describe 'with a custom amount on the instance', ->
      it 'moves the cursor 30 rows below', ->
        atom.config.set 'tablr.tableEditor.pageMoveRowAmount', 30

        atom.commands.dispatch(tableElement, 'core:page-down')

        expect(tableEditor.getCursorPosition().row).toEqual(30)

  describe 'core:page-up', ->
    beforeEach ->
      atom.config.set 'tablr.tableEditor.pageMoveRowAmount', 20

    it 'moves the cursor 20 rows up', ->
      tableEditor.setCursorAtScreenPosition([20, 0])

      atom.commands.dispatch(tableElement, 'core:page-up')

      expect(tableEditor.getCursorPosition().row).toEqual(0)

    it 'stops to the first cell without looping', ->
      tableEditor.setCursorAtScreenPosition([10, 0])

      atom.commands.dispatch(tableElement, 'core:page-up')

      expect(tableEditor.getCursorPosition().row).toEqual(0)

  describe 'tablr:page-left', ->
    beforeEach ->
      tableEditor.addColumn()
      tableEditor.addColumn()
      tableEditor.addColumn()
      tableEditor.addColumn()
      tableEditor.addColumn()
      tableEditor.addColumn()
      tableEditor.addColumn()
      atom.config.set 'tablr.tableEditor.pageMoveColumnAmount', 4

    it 'moves the cursor 4 cells left', ->
      tableEditor.setCursorAtScreenPosition([0, 5])

      atom.commands.dispatch(tableElement, 'tablr:page-left')

      expect(tableEditor.getCursorPosition().column).toEqual(1)

    it 'stops to the first cell without looping', ->
      tableEditor.setCursorAtScreenPosition([0, 2])

      atom.commands.dispatch(tableElement, 'tablr:page-left')

      expect(tableEditor.getCursorPosition().column).toEqual(0)

  describe 'tablr:page-right', ->
    beforeEach ->
      tableEditor.addColumn()
      tableEditor.addColumn()
      tableEditor.addColumn()
      tableEditor.addColumn()
      tableEditor.addColumn()
      tableEditor.addColumn()
      tableEditor.addColumn()
      atom.config.set 'tablr.tableEditor.pageMoveColumnAmount', 4

    it 'moves the cursor 4 cells right', ->
      atom.commands.dispatch(tableElement, 'tablr:page-right')

      expect(tableEditor.getCursorPosition().column).toEqual(4)

    it 'stops to the first cell without looping', ->
      tableEditor.setCursorAtScreenPosition([0,6])

      atom.commands.dispatch(tableElement, 'tablr:page-right')

      expect(tableEditor.getCursorPosition().column).toEqual(9)

  describe 'core:move-to-top', ->
    it 'moves the cursor to the first row', ->
      tableEditor.setCursorAtScreenPosition([50, 0])

      atom.commands.dispatch(tableElement, 'core:move-to-top')

      expect(tableEditor.getCursorPosition().row).toEqual(0)

  describe 'core:move-to-bottom', ->
    it 'moves the cursor to the first row', ->
      tableEditor.setCursorAtScreenPosition([50, 0])

      atom.commands.dispatch(tableElement, 'core:move-to-bottom')

      expect(tableEditor.getCursorPosition().row).toEqual(99)

  describe 'tablr:insert-row-before', ->
    it 'inserts a new row before the active row', ->
      atom.commands.dispatch(tableElement, 'core:move-down')
      atom.commands.dispatch(tableElement, 'core:move-down')
      atom.commands.dispatch(tableElement, 'core:move-down')
      atom.commands.dispatch(tableElement, 'tablr:insert-row-before')

      expect(tableEditor.getScreenRow(3)).toEqual([undefined, undefined, undefined])

    it 'refreshes the rows offsets', ->
      tableEditor.setScreenRowHeightAt(0, 60)
      atom.commands.dispatch(tableElement, 'tablr:insert-row-before')

      expect(tableEditor.getScreenRowHeightAt(0)).toEqual(tableEditor.getRowHeight())
      expect(tableEditor.getScreenRowHeightAt(1)).toEqual(60)
      expect(tableEditor.getScreenRowOffsetAt(1)).toEqual(tableEditor.getRowHeight())

    describe "when there's no rows in the table yet", ->
      beforeEach ->
        tableEditor.removeRowsInRange([0, Infinity])

      it 'creates a new row', ->
        atom.commands.dispatch(tableElement, 'tablr:insert-row-before')

        expect(tableEditor.getScreenRowHeightAt(0)).toEqual(tableEditor.getRowHeight())

    describe 'when the read-only attribute is set', ->
      it 'does insert a new row before the active row', ->
        tableElement.setAttribute('read-only', true)
        atom.commands.dispatch(tableElement, 'tablr:insert-row-before')

        expect(tableEditor.getScreenRow(0)).not.toEqual([undefined, undefined, undefined])

  describe 'tablr:insert-row-after', ->
    it 'inserts a new row after the active row', ->
      atom.commands.dispatch(tableElement, 'tablr:insert-row-after')

      expect(tableEditor.getScreenRow(1)).toEqual([undefined, undefined, undefined])

    it 'inserts a new row at the end of the table when on the last row', ->
      atom.commands.dispatch(tableElement, 'core:move-to-bottom')
      atom.commands.dispatch(tableElement, 'tablr:insert-row-after')

      expect(tableEditor.getScreenRow(tableEditor.getLastRowIndex())).toEqual([undefined, undefined, undefined])

    it 'moves the cursor to the new row on the same column', ->
      tableEditor.setCursorAtScreenPosition([1,1])
      atom.commands.dispatch(tableElement, 'tablr:insert-row-after')
      expect(tableEditor.getCursorPosition()).toEqual([2,1])

    describe 'when the read-only attribute is set', ->
      it 'does insert a new row after the active row', ->
        tableElement.setAttribute('read-only', true)
        atom.commands.dispatch(tableElement, 'tablr:insert-row-after')

        expect(tableEditor.getScreenRowCount()).toEqual(100)

  describe 'tablr:delete-row', ->
    spy = null

    beforeEach ->
      spy = jasmine.createSpy('did-change')
      tableEditor.onDidChange(spy)

    it 'deletes the current active row', ->
      atom.commands.dispatch(tableElement, 'tablr:delete-row')

      waitsFor -> spy.callCount > 0
      runs ->
        expect(tableEditor.getScreenRow(0)).toEqual(['row1', 100, 'no'])

    it 'moves the cursor on the remaining first row', ->
      atom.commands.dispatch(tableElement, 'tablr:delete-row')

      waitsFor -> spy.callCount > 0
      runs ->
        expect(tableEditor.getCursorScreenPosition()).toEqual([0,0])

    describe 'when the cursor is on the last row', ->
      it 'moves the cursor on row above', ->
        spy = jasmine.createSpy('did-change')
        tableEditor.onDidChange(spy)

        atom.commands.dispatch(tableElement, 'core:move-to-bottom')
        atom.commands.dispatch(tableElement, 'tablr:delete-row')

        waitsFor -> spy.callCount > 0
        runs ->
          expect(tableEditor.getCursorScreenPosition()).toEqual([98,0])

    describe 'when the seletion spans several rows', ->
      it 'removes all the rows', ->
        tableEditor.setSelectedRange([[0, 0], [2, 2]])

        atom.commands.dispatch(tableElement, 'tablr:delete-row')

        waitsFor -> spy.callCount > 0
        runs ->
          expect(tableEditor.getScreenRow(0)).toEqual(['row2', 200, 'yes'])

    describe 'when the read-only attribute is set', ->
      it 'does not delete the active row', ->
        tableElement.setAttribute('read-only', true)
        atom.commands.dispatch(tableElement, 'tablr:delete-row')

        expect(tableEditor.getScreenRowCount()).toEqual(100)

  describe 'tablr:insert-column-before', ->
    it 'inserts a new column before the active column', ->
      atom.commands.dispatch(tableElement, 'tablr:insert-column-before')

      expect(tableEditor.getScreenRow(0)).toEqual([undefined, 'row0', 0, 'yes'])

    describe 'called several times', ->
      it 'uses incremental placeholders for column names', ->
        atom.commands.dispatch(tableElement, 'tablr:insert-column-before')
        atom.commands.dispatch(tableElement, 'tablr:insert-column-before')

        nextAnimationFrame()

        expect(tableElement.querySelector('tablr-header-cell[data-column="0"] span').textContent).toEqual('A')
        expect(tableElement.querySelector('tablr-header-cell[data-column="1"] span').textContent).toEqual('B')

    describe 'when the read-only attribute is set', ->
      it 'does not insert the column', ->
        tableElement.setAttribute('read-only', true)
        atom.commands.dispatch(tableElement, 'tablr:insert-column-before')

        expect(tableEditor.getScreenColumnCount()).toEqual(3)

  describe 'tablr:insert-column-after', ->
    it 'inserts a new column after the active column', ->
      atom.commands.dispatch(tableElement, 'tablr:insert-column-after')

      expect(tableEditor.getScreenRow(0)).toEqual(['row0', undefined, 0, 'yes'])

    describe 'called several times', ->
      it 'uses incremental placeholders for column names', ->
        atom.commands.dispatch(tableElement, 'tablr:insert-column-after')
        atom.commands.dispatch(tableElement, 'tablr:insert-column-after')

        nextAnimationFrame()

        expect(tableElement.querySelector('tablr-header-cell[data-column="1"] span').textContent).toEqual('B')
        expect(tableElement.querySelector('tablr-header-cell[data-column="2"] span').textContent).toEqual('C')

    describe 'when the read-only attribute is set', ->
      it 'does not insert the column', ->
        tableElement.setAttribute('read-only', true)
        atom.commands.dispatch(tableElement, 'tablr:insert-column-after')

        expect(tableEditor.getScreenColumnCount()).toEqual(3)

  describe 'tablr:delete-column', ->
    spy = null

    beforeEach ->
      spy = jasmine.createSpy('did-change')
      tableEditor.onDidRemoveColumn(spy)

    it 'deletes the current active column', ->
      atom.commands.dispatch(tableElement, 'tablr:delete-column')

      waitsFor -> spy.callCount > 0
      runs ->
        expect(tableEditor.getScreenRow(0)).toEqual([0, 'yes'])

    describe 'when the seletion spans several columns', ->
      it 'removes all the columns', ->
        tableEditor.setSelectedRange([[0, 0], [2, 2]])

        atom.commands.dispatch(tableElement, 'tablr:delete-column')

        waitsFor -> spy.callCount > 0
        runs ->
          expect(tableEditor.getScreenRow(0)).toEqual(['yes'])

    describe 'when the read-only attribute is set', ->
      it 'does not delete the column', ->
        tableElement.setAttribute('read-only', true)
        atom.commands.dispatch(tableElement, 'tablr:delete-column')

        expect(tableEditor.getScreenColumnCount()).toEqual(3)

  describe 'core:paste', ->
    beforeEach ->
      atom.clipboard.write('foo')

    it 'pastes the clipboard content', ->
      atom.commands.dispatch(tableElement, 'core:paste')

      expect(tableEditor.getScreenRow(0)).toEqual(['foo', 0, 'yes'])

    describe 'when the read-only attribute is set', ->
      it 'does not paste the content', ->
        tableElement.setAttribute('read-only', true)
        atom.commands.dispatch(tableElement, 'core:paste')

        expect(tableEditor.getScreenRow(0)).toEqual(['row0', 0, 'yes'])

  describe 'core:cut', ->
    beforeEach ->
      atom.clipboard.write('foo')

    it 'copies and then deletes the selected cells', ->
      atom.commands.dispatch(tableElement, 'core:cut')

      expect(tableEditor.getScreenRow(0)).toEqual([undefined, 0, 'yes'])

    describe 'when the read-only attribute is set', ->
      it 'copies but does not delete the selected cells', ->
        tableElement.setAttribute('read-only', true)
        atom.commands.dispatch(tableElement, 'core:cut')

        expect(tableEditor.getScreenRow(0)).toEqual(['row0', 0, 'yes'])
        expect(atom.clipboard.read()).toEqual('row0')

  describe 'tablr:align-left', ->
    describe 'when there is no target column', ->
      it 'changes the alignment of the active column', ->
        tableEditor.getScreenColumn(tableEditor.getCursorPosition().column).align = 'right'

        atom.commands.dispatch(tableElement, 'tablr:align-left')

        expect(tableEditor.getScreenColumn(tableEditor.getCursorPosition().column).align).toEqual('left')

    describe 'when there is a target column', ->
      it 'changes the alignment of the target column', ->
        tableElement.contextMenuColumn = 2
        tableEditor.getScreenColumn(2).align = 'right'

        atom.commands.dispatch(tableElement, 'tablr:align-left')

        expect(tableEditor.getScreenColumn(2).align).toEqual('left')

  describe 'tablr:align-center', ->
    describe 'when there is no target column', ->
      it 'changes the alignment of the active column', ->
        atom.commands.dispatch(tableElement, 'tablr:align-center')

        expect(tableEditor.getScreenColumn(tableEditor.getCursorPosition().column).align).toEqual('center')

    describe 'when there is a target column', ->
      it 'changes the alignment of the target column', ->
        tableElement.contextMenuColumn = 2

        atom.commands.dispatch(tableElement, 'tablr:align-center')

        expect(tableEditor.getScreenColumn(2).align).toEqual('center')

  describe 'tablr:align-right', ->
    describe 'when there is no target column', ->
      it 'changes the alignment of the active column', ->
        atom.commands.dispatch(tableElement, 'tablr:align-right')

        expect(tableEditor.getScreenColumn(tableEditor.getCursorPosition().column).align).toEqual('right')

    describe 'when there is a target column', ->
      it 'changes the alignment of the target column', ->
        tableElement.contextMenuColumn = 2

        atom.commands.dispatch(tableElement, 'tablr:align-right')

        expect(tableEditor.getScreenColumn(2).align).toEqual('right')

  describe 'tablr:expand-column', ->
    it 'increases the column at cursors by the amount defined in the settings', ->
      atom.config.set('tablr.tableEditor.columnWidthIncrement', 20)

      atom.commands.dispatch(tableElement, 'tablr:expand-column')

      expect(tableEditor.getScreenColumnWidthAt(0)).toEqual(120)

  describe 'tablr:shrink-column', ->
    it 'shrinks the column at cursors by the amount defined in the settings', ->
      atom.config.set('tablr.tableEditor.columnWidthIncrement', 20)

      atom.commands.dispatch(tableElement, 'tablr:shrink-column')

      expect(tableEditor.getScreenColumnWidthAt(0)).toEqual(80)

  describe 'tablr:expand-row', ->
    it 'increases the row at cursors by the amount defined in the settings', ->
      atom.config.set('tablr.tableEditor.rowHeightIncrement', 20)

      atom.commands.dispatch(tableElement, 'tablr:expand-row')

      expect(tableEditor.getScreenRowHeightAt(0)).toEqual(40)

  describe 'tablr:shrink-row', ->
    it 'shrinks the row at cursors by the amount defined in the settings', ->
      atom.config.set('tablr.tableEditor.rowHeightIncrement', 20)

      atom.commands.dispatch(tableElement, 'tablr:shrink-row')

      expect(tableEditor.getScreenRowHeightAt(0)).toEqual(10)

  describe 'tablr:go-to-line', ->
    [goToLineElement] = []

    beforeEach ->
      jasmineContent.appendChild(atom.views.getView(atom.workspace))
      atom.commands.dispatch(tableElement, 'tablr:go-to-line')

      waitsFor ->
        goToLineElement = document.querySelector('tablr-go-to-line')

    it 'adds a modal panel', ->
      expect(goToLineElement).toExist()

  describe '::goToLine', ->
    describe 'with only a row', ->
      it 'selects the first cell of the specified line', ->
        tableElement.goToLine([10])

        expect(tableEditor.getCursorPosition()).toEqual([9,0])

    describe 'with a row and a column index', ->
      it 'selects the cell at the specified position', ->
        tableElement.goToLine([10, 2])

        expect(tableEditor.getCursorPosition()).toEqual([9,1])

    describe 'with a row and a column name', ->
      it 'selects the cell at the specified position', ->
        tableElement.goToLine([10, 'value'])

        expect(tableEditor.getCursorPosition()).toEqual([9,1])

  describe 'tablr:move-line-down', ->
    it 'calls tableEditor::moveLineDown', ->
      spyOn(tableEditor, 'moveLineDown')

      atom.commands.dispatch(tableElement, 'tablr:move-line-down')

      expect(tableEditor.moveLineDown).toHaveBeenCalled()

  describe 'tablr:move-line-up', ->
    it 'calls tableEditor::moveLineUp', ->
      spyOn(tableEditor, 'moveLineUp')

      atom.commands.dispatch(tableElement, 'tablr:move-line-up')

      expect(tableEditor.moveLineUp).toHaveBeenCalled()

  describe 'tablr:move-column-left', ->
    it 'calls tableEditor::moveColumnLeft', ->
      spyOn(tableEditor, 'moveColumnLeft')

      atom.commands.dispatch(tableElement, 'tablr:move-column-left')

      expect(tableEditor.moveColumnLeft).toHaveBeenCalled()

  describe 'tablr:move-column-right', ->
    it 'calls tableEditor::moveColumnRight', ->
      spyOn(tableEditor, 'moveColumnRight')

      atom.commands.dispatch(tableElement, 'tablr:move-column-right')

      expect(tableEditor.moveColumnRight).toHaveBeenCalled()

  describe 'tablr:move-right-in-selection', ->
    describe 'when there is no selection and the cursor is on the last cell', ->
      beforeEach ->
        spyOn(tableEditor, 'moveRightInSelection')
        spyOn(tableEditor, 'insertRowAfter').andCallThrough()

        tableElement.moveToBottom()
        tableElement.moveToRight()

        tableElement.moveRightInSelection()

      it 'does not moves the cursor', ->
        expect(tableEditor.moveRightInSelection).not.toHaveBeenCalled()

      it 'inserts a new row', ->
        expect(tableEditor.insertRowAfter).toHaveBeenCalled()
        expect(tableEditor.getCursorPosition()).toEqual([100,0])


  describe 'tablr:apply-sort', ->
    it 'calls tableEditor::applySort', ->
      spyOn(tableEditor, 'applySort')

      atom.commands.dispatch(tableElement, 'tablr:apply-sort')

      expect(tableEditor.applySort).toHaveBeenCalled()

  describe 'tablr:fit-column-to-content', ->
    [dummyCell] = []
    beforeEach ->
      content = 'abcdefghijklmnopqrstuvwxyz'
      tableEditor.setValueAtPosition([5,1], content)
      dummyCell = document.createElement('d')
      dummyCell.className = 'tablr-cell'
      dummyCell.textContent = content
      dummyCell.style.height = 'auto'
      jasmineContent.appendChild(dummyCell)

    it 'sets the width of the screen column to the width of its biggest content', ->
      tableElement.moveRight()

      atom.commands.dispatch(tableElement, 'tablr:fit-column-to-content')

      expect(tableEditor.getScreenColumnWidthAt(1)).toEqual(dummyCell.offsetWidth)

    describe 'when there is a target column', ->
      it 'change sets the width of the target column', ->
        tableElement.contextMenuColumn = 1

        atom.commands.dispatch(tableElement, 'tablr:fit-column-to-content')

        expect(tableEditor.getScreenColumnWidthAt(1)).toEqual(dummyCell.offsetWidth)

  describe 'tablr:fit-row-to-content', ->
    [dummyCell] = []
    beforeEach ->
      content = 'abcdef\nghijkl\nmnopqr\nstuvwxyz'
      tableEditor.setValueAtPosition([1,1], content)
      dummyCell = document.createElement('d')
      dummyCell.className = 'tablr-cell'
      dummyCell.textContent = content
      dummyCell.style.height = 'auto'
      jasmineContent.appendChild(dummyCell)

    it 'sets the width of the screen row to the width of its biggest content', ->
      tableElement.moveDown()

      atom.commands.dispatch(tableElement, 'tablr:fit-row-to-content')

      expect(tableEditor.getScreenRowHeightAt(1)).toEqual(dummyCell.offsetHeight)

    describe 'when there is a target row', ->
      it 'sets the width of the target row', ->
        tableElement.contextMenuRow = 1

        atom.commands.dispatch(tableElement, 'tablr:fit-row-to-content')

        expect(tableEditor.getScreenRowHeightAt(1)).toEqual(dummyCell.offsetHeight)

  #    ######## ########  #### ########
  #    ##       ##     ##  ##     ##
  #    ##       ##     ##  ##     ##
  #    ######   ##     ##  ##     ##
  #    ##       ##     ##  ##     ##
  #    ##       ##     ##  ##     ##
  #    ######## ########  ####    ##

  describe 'pressing a key when the table view has focus', ->
    beforeEach ->
      textInput(tableElement.hiddenInput, 'x')

    it 'starts the edition of the cursor', ->
      expect(tableElement.isEditing()).toBeTruthy()

    it 'fills the editor with the input data', ->
      editor = tableElement.querySelector('atom-text-editor').model
      expect(editor.getText()).toEqual('x')

    describe 'on an empty table', ->
      beforeEach ->
        tableEditor = new TableEditor
        tableElement = atom.views.getView(tableEditor)
        tableElement = tableElement

        jasmineContent.insertBefore(tableElement, jasmineContent.firstChild)

        textInput(tableElement.hiddenInput, 'x')

      it 'creates a column and a row prior to the edit', ->
        expect(tableEditor.getScreenColumnCount()).toEqual(1)
        expect(tableEditor.getScreenRowCount()).toEqual(1)

        editor = tableElement.querySelector('atom-text-editor').model
        expect(editor.getText()).toEqual('x')

  describe 'on an table with a column with a grammar', ->
    beforeEach ->
      waitsForPromise -> atom.packages.activatePackage('language-javascript')

      runs ->
        tableEditor.getScreenColumn(0).grammarScope = 'source.js'

        cell = tableElement.querySelector('tablr-cell[data-column="0"]')
        dblclick(cell)

    it 'sets the grammar on the editor', ->
      editor = tableElement.querySelector('atom-text-editor').model
      expect(editor.getGrammar().scopeName).toEqual('source.js')

  describe 'double clicking on a cell', ->
    beforeEach ->
      cell = tableElement.querySelector('tablr-cell:last-child')
      dblclick(cell)

    it 'starts the edition of the cell', ->
      expect(tableElement.isEditing()).toBeTruthy()

  describe '::startCellEdit', ->
    [editor, editorElement] = []

    editorElementRoot = () ->
      if parseFloat(atom.getVersion()) < 1.13
        editorElement.shadowRoot
      else
        editorElement

    beforeEach ->
      tableElement.startCellEdit()
      editorElement = tableElement.querySelector('atom-text-editor')
      editor = editorElement.model

    it 'opens a text editor above the cursor', ->
      cell = tableElement.querySelector('tablr-cell')
      cellOffset = cell.getBoundingClientRect()

      editorOffset = editorElement.getBoundingClientRect()

      expect(editorElement).toExist()
      expect(editorOffset.top).toBeCloseTo(cellOffset.top, -2)
      expect(editorOffset.left).toBeCloseTo(cellOffset.left, -2)
      expect(editorElement.offsetWidth).toBeCloseTo(cell.offsetWidth, -2)
      expect(editorElement.offsetHeight).toBeCloseTo(cell.offsetHeight, -2)

    it 'gives the focus to the editor', ->
      if parseFloat(atom.getVersion()) >= 1.13 and process.platform is 'darwin'
        expect(document.activeElement).toBe(editorElement.querySelector('input'))
      else
        expect(document.activeElement).toBe(editorElement)

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
      expect(isVisible(tableElement.editorElement)).toBeFalsy()

    it 'gives the focus back to the table view', ->
      expect(document.activeElement).toBe(tableElement.hiddenInput)
      expect(tableElement.hasFocus()).toBeTruthy()

    it 'leaves the cell value as is', ->
      expect(tableEditor.getLastCursor().getValue()).toEqual('row0')

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

    describe 'tablr:move-right-in-selection', ->
      it 'confirms the current edit and moves the active cursor to the right', ->
        previousActiveCell = tableEditor.getLastCursor()
        spyOn(tableElement, 'moveRightInSelection')
        editor.setText('Foo Bar')
        atom.commands.dispatch(editorElement, 'tablr:move-right-in-selection')

        expect(tableElement.isEditing()).toBeFalsy()
        expect(previousActiveCell.getValue()).toEqual('Foo Bar')
        expect(tableElement.moveRightInSelection).toHaveBeenCalled()

    describe 'tablr:move-left-in-selection', ->
      it 'confirms the current edit and moves the active cursor to the left', ->
        previousActiveCell = tableEditor.getLastCursor()
        spyOn(tableElement, 'moveLeftInSelection')
        editor.setText('Foo Bar')
        atom.commands.dispatch(editorElement, 'tablr:move-left-in-selection')

        expect(tableElement.isEditing()).toBeFalsy()
        expect(previousActiveCell.getValue()).toEqual('Foo Bar')
        expect(tableElement.moveLeftInSelection).toHaveBeenCalled()

    describe 'core:confirm', ->
      describe 'when the content of the editor has changed', ->
        beforeEach ->
          editor.setText('foobar')
          atom.commands.dispatch(editorElement, 'core:confirm')

        it 'closes the editor', ->
          expect(tableElement.querySelectorAll('atom-text-editor').length).toEqual(0)

        it 'gives the focus back to the table view', ->
          expect(document.activeElement).toBe(tableElement.hiddenInput)

        it 'changes the cell value', ->
          expect(tableEditor.getLastCursor().getValue()).toEqual('foobar')

      describe 'when the content of the editor did not changed', ->
        beforeEach ->
          spyOn(tableEditor, 'setValueAtScreenPosition').andCallThrough()
          atom.commands.dispatch(editorElement, 'core:confirm')

        it 'closes the editor', ->
          expect(isVisible(tableElement.editorElement)).toBeFalsy()

        it 'gives the focus back to the table view', ->
          expect(document.activeElement).toBe(tableElement.hiddenInput)

        it 'leaves the cell value as is', ->
          expect(tableEditor.getLastCursor().getValue()).toEqual('row0')
          expect(tableEditor.setValueAtScreenPosition).not.toHaveBeenCalled()

    describe 'clicking on another cell', ->
      beforeEach ->
        cell = tableElement.querySelector('tablr-cell[data-row="3"][data-column="2"]')
        mousedown(cell)

      it 'closes the editor', ->
        expect(tableElement.isEditing()).toBeFalsy()

  describe 'when there is many cursor', ->
    [editor, editorElement] = []

    beforeEach ->
      tableEditor.setSelectedRanges([
        [[0,0],[1,1]]
        [[1,0],[2,1]]
      ])
      tableElement.startCellEdit()
      editorElement = tableElement.querySelector('atom-text-editor')
      editor = editorElement.model

    describe 'core:confirm', ->
      describe 'when the content of the editor has changed', ->
        beforeEach ->
          editor.setText('foobar')
          atom.commands.dispatch(editorElement, 'core:confirm')

        it 'closes the editor', ->
          expect(tableElement.querySelectorAll('atom-text-editor').length).toEqual(0)

        it 'gives the focus back to the table view', ->
          expect(document.activeElement).toBe(tableElement.hiddenInput)

        it 'changes the cells value', ->
          expect(tableEditor.getCursors().length).toEqual(2)
          for cursor in tableEditor.getCursors()
            expect(cursor.getValue()).toEqual('foobar')

  describe 'when the element has the read-only attribute', ->
    beforeEach ->
      tableElement.setAttribute('read-only', true)

    describe 'pressing a key when the table view has focus', ->
      beforeEach ->
        textInput(tableElement.hiddenInput, 'x')

      it 'does not start the edit mode', ->
        expect(tableElement.isEditing()).toBeFalsy()
        expect(tableElement.querySelector('atom-text-editor')).not.toExist()

    describe 'double clicking on a cell', ->
      beforeEach ->
        cell = tableElement.querySelector('tablr-cell:last-child')
        dblclick(cell)

      it 'does not start the edit mode', ->
        expect(tableElement.isEditing()).toBeFalsy()
        expect(tableElement.querySelector('atom-text-editor')).not.toExist()

    describe 'core:confirm', ->
      beforeEach ->
        atom.commands.dispatch(tableElement, 'core:confirm')

      it 'does not start the edit mode', ->
        expect(tableElement.isEditing()).toBeFalsy()
        expect(tableElement.querySelector('atom-text-editor')).not.toExist()


  #     ######  ######## ##       ########  ######  ########
  #    ##    ## ##       ##       ##       ##    ##    ##
  #    ##       ##       ##       ##       ##          ##
  #     ######  ######   ##       ######   ##          ##
  #          ## ##       ##       ##       ##          ##
  #    ##    ## ##       ##       ##       ##    ##    ##
  #     ######  ######## ######## ########  ######     ##
  describe '', ->
    it 'has a selection', ->
      expect(tableEditor.getLastSelection().getRange()).toEqual([[0,0], [1,1]])

    describe 'selection', ->
      it 'follows the cursor when it moves', ->
        atom.config.set 'tablr.tableEditor.pageMoveRowAmount', 10
        tableElement.pageDown()
        tableElement.moveRight()

        expect(tableEditor.getLastSelection().getRange()).toEqual([[10,1], [11,2]])

      it 'can spans on several rows and columns', ->
        tableEditor.setSelectedRange([[2,0],[4,3]])

        expect(tableEditor.getLastSelection().getRange()).toEqual([[2,0],[4,3]])

      it 'marks the cells covered by the selection with a selected class', ->
        tableEditor.setSelectedRange([[2,0],[4,3]])

        nextAnimationFrame()

        expect(tableElement.querySelectorAll('tablr-cell.selected').length).toEqual(6)

      it 'marks the row number with a selected class', ->
        tableEditor.setSelectedRange([[2,0],[4,3]])

        nextAnimationFrame()

        expect(tableElement.querySelectorAll('tablr-gutter-cell.selected').length).toEqual(2)

    describe 'when the selection spans only one cell', ->
      it 'does not render the selection box', ->
        expect(tableElement.querySelector('tablr-editor-selection').style.display).toEqual('none')

    describe 'when the selection spans many cells', ->
      [selectionBox, selectionBoxHandle] = []

      beforeEach ->
        tableEditor.setSelectedRange([[2,0],[4,3]])
        nextAnimationFrame()
        selectionBox = tableElement.querySelector('tablr-editor-selection')
        selectionBoxHandle = tableElement.querySelector('.selection-box-handle')

      it 'renders the selection box', ->
        expect(selectionBox).toExist()
        expect(selectionBoxHandle).toExist()

      it 'positions the selection box over the cells', ->
        cells = tableElement.querySelectorAll('tablr-cell.selected')
        firstCell = tableElement.getScreenCellAtPosition([2,0])
        lastCell = tableElement.getScreenCellAtPosition([3,2])

        selectionBoxOffset = selectionBox.getBoundingClientRect()
        firstCellOffset = firstCell.getBoundingClientRect()

        expect(selectionBoxOffset.top).toEqual(firstCellOffset.top)
        expect(selectionBoxOffset.left).toEqual(firstCellOffset.left)
        expect(selectionBox.offsetWidth).toEqual(300)
        expect(selectionBox.offsetHeight).toEqual(firstCell.offsetHeight + lastCell.offsetHeight)

      it 'positions the selection box over the cells', ->
        tableEditor.setSelectedRange([[2,1],[4,3]])
        nextAnimationFrame()

        selectionBox = tableElement.querySelector('tablr-editor-selection')
        cells = tableElement.querySelectorAll('tablr-cell.selected')
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
          tableElement.setColumnsWidths([100, 100, 400])
          tableEditor.setSelectedRange([[2,0],[4,2]])
          nextAnimationFrame()

        it 'positions the selection box over the cells', ->
          cells = tableElement.querySelectorAll('tablr-cell.selected')
          firstCell = tableElement.getScreenCellAtPosition([2,0])
          lastCell = tableElement.getScreenCellAtPosition([3,1])

          selectionBoxOffset = selectionBox.getBoundingClientRect()
          firstCellOffset = firstCell.getBoundingClientRect()

          expect(selectionBoxOffset.top).toBeCloseTo(firstCellOffset.top, -1)
          expect(selectionBoxOffset.left).toBeCloseTo(firstCellOffset.left, -1)
          expect(selectionBox.offsetWidth).toBeCloseTo(firstCell.offsetWidth + lastCell.offsetWidth, -1)
          expect(selectionBox.offsetHeight).toBeCloseTo(firstCell.offsetHeight + lastCell.offsetHeight, -1)

      describe 'core:cancel', ->
        it 'does nothing', ->
          originalRange = tableEditor.getLastSelection().getRange()
          tableElement.resetSelections()

          expect(tableEditor.getLastSelection().getRange()).toEqual(originalRange)

    describe 'when there is many selections', ->
      beforeEach ->
        tableEditor.setSelectedRanges([
          [[0,0],[1,3]]
          [[1,0],[2,3]]
        ])

      it 'adds a new selection element in the table', ->
        expect(tableElement.querySelectorAll('tablr-editor-selection').length).toEqual(2)

      describe 'and one selection is destroyed', ->
        beforeEach ->
          tableEditor.setSelectedRanges([[[0,0],[1,3]]])

        it 'removes the selection element', ->
          expect(tableElement.querySelectorAll('tablr-editor-selection').length).toEqual(1)

      describe 'core:cancel', ->
        it 'resets all the selections to the last cursor range', ->
          atom.commands.dispatch(tableElement, 'core:cancel')

          expect(tableEditor.getSelections().length).toEqual(1)
          expect(tableEditor.getLastSelection().getRange()).toEqual([[1,0],[2,3]])

    describe 'core:select-right', ->
      it 'expands the selection by one cell on the right', ->
        atom.commands.dispatch(tableElement, 'core:select-right')
        expect(tableEditor.getLastSelection().getRange()).toEqual([[0,0],[1,2]])

      it 'stops at the last column', ->
        atom.commands.dispatch(tableElement, 'core:select-right')
        atom.commands.dispatch(tableElement, 'core:select-right')
        atom.commands.dispatch(tableElement, 'core:select-right')

        expect(tableEditor.getLastSelection().getRange()).toEqual([[0,0],[1,3]])

      describe 'then triggering core:select-left', ->
        it 'collapse the selection back to the left', ->
          tableEditor.setCursorAtScreenPosition([0,1])

          atom.commands.dispatch(tableElement, 'core:select-right')
          atom.commands.dispatch(tableElement, 'core:select-left')

          expect(tableEditor.getLastSelection().getRange()).toEqual([[0,1],[1,2]])

    describe 'core:select-left', ->
      beforeEach ->
        tableEditor.setCursorAtScreenPosition([0,2])

      it 'expands the selection by one cell on the left', ->
        atom.commands.dispatch(tableElement, 'core:select-left')
        expect(tableEditor.getLastSelection().getRange()).toEqual([[0,1],[1,3]])

      it 'stops at the first column', ->
        atom.commands.dispatch(tableElement, 'core:select-left')
        atom.commands.dispatch(tableElement, 'core:select-left')
        atom.commands.dispatch(tableElement, 'core:select-left')
        expect(tableEditor.getLastSelection().getRange()).toEqual([[0,0],[1,3]])

      describe 'then triggering core:select-right', ->
        it 'collapse the selection back to the right', ->
          tableEditor.setCursorAtScreenPosition([0,1])

          atom.commands.dispatch(tableElement, 'core:select-left')
          atom.commands.dispatch(tableElement, 'core:select-right')

          expect(tableEditor.getLastSelection().getRange()).toEqual([[0,1],[1,2]])

    describe 'core:select-up', ->
      beforeEach ->
        tableEditor.setCursorAtScreenPosition([2,0])

      it 'expands the selection by one cell to the top', ->
        atom.commands.dispatch(tableElement, 'core:select-up')
        expect(tableEditor.getLastSelection().getRange()).toEqual([[1,0],[3,1]])

      it 'stops at the first row', ->
        atom.commands.dispatch(tableElement, 'core:select-up')
        atom.commands.dispatch(tableElement, 'core:select-up')
        atom.commands.dispatch(tableElement, 'core:select-up')
        expect(tableEditor.getLastSelection().getRange()).toEqual([[0,0],[3,1]])

      it 'scrolls the view to make the added row visible', ->
        tableElement.setScrollTop(200)
        tableEditor.setCursorAtScreenPosition([10,0])

        atom.commands.dispatch(tableElement, 'core:select-up')

        expect(tableElement.getRowsContainer().scrollTop).toEqual(180)

      describe 'then triggering core:select-down', ->
        it 'collapse the selection back to the bottom', ->
          tableEditor.setCursorAtScreenPosition([1,0])

          atom.commands.dispatch(tableElement, 'core:select-up')
          atom.commands.dispatch(tableElement, 'core:select-down')

          expect(tableEditor.getLastSelection().getRange()).toEqual([[1,0],[2,1]])

    describe 'core:select-down', ->
      beforeEach ->
        tableEditor.setCursorAtScreenPosition([97,0])

      it 'expands the selection by one cell to the bottom', ->
        atom.commands.dispatch(tableElement, 'core:select-down')
        expect(tableEditor.getLastSelection().getRange()).toEqual([[97,0],[99,1]])

      it 'stops at the last row', ->
        atom.commands.dispatch(tableElement, 'core:select-down')
        atom.commands.dispatch(tableElement, 'core:select-down')
        atom.commands.dispatch(tableElement, 'core:select-down')
        expect(tableEditor.getLastSelection().getRange()).toEqual([[97,0],[100,1]])

      it 'scrolls the view to make the added row visible', ->
        tableEditor.setCursorAtScreenPosition([8,0])

        atom.commands.dispatch(tableElement, 'core:select-down')

        expect(tableElement.getRowsContainer().scrollTop).not.toEqual(0)

      describe 'then triggering core:select-up', ->
        it 'collapse the selection back to the bottom', ->
          tableEditor.setCursorAtScreenPosition([1,0])

          atom.commands.dispatch(tableElement, 'core:select-down')
          atom.commands.dispatch(tableElement, 'core:select-up')

          expect(tableEditor.getLastSelection().getRange()).toEqual([[1,0],[2,1]])

    describe 'tablr:select-to-end-of-line', ->
      it 'expands the selection to the end of the current row', ->
        atom.commands.dispatch(tableElement, 'tablr:select-to-end-of-line')

        expect(tableEditor.getLastSelection().getRange()).toEqual([[0,0],[1,3]])

      describe 'then triggering tablr:select-to-beginning-of-line', ->
        it 'expands the selection to the beginning of the current row', ->
          tableEditor.setCursorAtScreenPosition([0,1])

          atom.commands.dispatch(tableElement, 'tablr:select-to-end-of-line')
          atom.commands.dispatch(tableElement, 'tablr:select-to-beginning-of-line')

          expect(tableEditor.getLastSelection().getRange()).toEqual([[0,0],[1,2]])

    describe 'tablr:select-to-beginning-of-line', ->
      it 'expands the selection to the beginning of the current row', ->
        tableEditor.setCursorAtScreenPosition([0,2])

        atom.commands.dispatch(tableElement, 'tablr:select-to-beginning-of-line')

        expect(tableEditor.getLastSelection().getRange()).toEqual([[0,0],[1,3]])

      describe 'tablr:select-to-end-of-line', ->
        it 'expands the selection to the end of the current row', ->
          tableEditor.setCursorAtScreenPosition([0,1])

          atom.commands.dispatch(tableElement, 'tablr:select-to-beginning-of-line')
          atom.commands.dispatch(tableElement, 'tablr:select-to-end-of-line')

          expect(tableEditor.getLastSelection().getRange()).toEqual([[0,1],[1,3]])

    describe 'tablr:select-to-end-of-table', ->
      it 'expands the selection to the end of the table', ->
        atom.commands.dispatch(tableElement, 'tablr:select-to-end-of-table')

        expect(tableEditor.getLastSelection().getRange()).toEqual([[0,0],[100,1]])

      it 'scrolls the view to make the added row visible', ->
        atom.commands.dispatch(tableElement, 'tablr:select-to-end-of-table')

        expect(tableElement.getRowsContainer().scrollTop).not.toEqual(0)

      describe 'then triggering tablr:select-to-beginning-of-table', ->
        it 'expands the selection to the beginning of the table', ->
          tableEditor.setCursorAtScreenPosition([1,0])

          atom.commands.dispatch(tableElement, 'tablr:select-to-end-of-table')
          atom.commands.dispatch(tableElement, 'tablr:select-to-beginning-of-table')

          expect(tableEditor.getLastSelection().getRange()).toEqual([[0,0],[2,1]])

    describe 'tablr:select-to-beginning-of-table', ->
      it 'expands the selection to the beginning of the table', ->
        tableEditor.setCursorAtScreenPosition([2,0])

        atom.commands.dispatch(tableElement, 'tablr:select-to-beginning-of-table')

        expect(tableEditor.getLastSelection().getRange()).toEqual([[0,0],[3,1]])

      it 'scrolls the view to make the added row visible', ->
        tableEditor.setCursorAtScreenPosition([99,0])

        atom.commands.dispatch(tableElement, 'tablr:select-to-beginning-of-table')

        expect(tableElement.getRowsContainer().scrollTop).toEqual(0)

      describe 'tablr:select-to-end-of-table', ->
        it 'expands the selection to the end of the table', ->
          tableEditor.setCursorAtScreenPosition([1,0])

          atom.commands.dispatch(tableElement, 'tablr:select-to-beginning-of-table')
          atom.commands.dispatch(tableElement, 'tablr:select-to-end-of-table')

          expect(tableEditor.getLastSelection().getRange()).toEqual([[1,0],[100,1]])

    ##    ########  ##    ## ########
    ##    ##     ## ###   ## ##     ##
    ##    ##     ## ####  ## ##     ##
    ##    ##     ## ## ## ## ##     ##
    ##    ##     ## ##  #### ##     ##
    ##    ##     ## ##   ### ##     ##
    ##    ########  ##    ## ########

    describe 'dragging the mouse pressed over cell', ->
      it 'creates a selection with the cells from the mouse movements', ->
        startCell = tableElement.querySelector('tablr-cell[data-row="3"][data-column="0"]')
        endCell = tableElement.querySelector('tablr-cell[data-row="6"][data-column="2"]')

        mousedown(startCell)
        mousemove(endCell)

        expect(tableEditor.getLastSelection().getRange()).toEqual([[3,0],[7,3]])

        mousedown(endCell)
        mousemove(startCell)

        expect(tableEditor.getLastSelection().getRange()).toEqual([[3,0],[7,3]])

      describe 'when the meta key is pressed', ->
        it 'creates a new selection with the cells from the mouse movements', ->
          startCell = tableElement.querySelector('tablr-cell[data-row="3"][data-column="0"]')
          endCell = tableElement.querySelector('tablr-cell[data-row="6"][data-column="2"]')

          mousedown(startCell, metaKey: true)
          mousemove(endCell, metaKey: true)

          expect(tableEditor.getSelections().length).toEqual(2)

          expect(tableEditor.getLastSelection().getRange()).toEqual([[3,0],[7,3]])

        describe 'to create a selection within another one', ->
          it 'merges the two selections in one', ->
            tableEditor.setSelectedRange([[1,0],[5,3]])
            startCell = tableElement.querySelector('tablr-cell[data-row="2"][data-column="0"]')
            endCell = tableElement.querySelector('tablr-cell[data-row="3"][data-column="2"]')

            mousedown(startCell, metaKey: true)
            mousemove(endCell, metaKey: true)
            mouseup(endCell, metaKey: true)

            expect(tableEditor.getSelections().length).toEqual(1)

            expect(tableEditor.getLastSelection().getRange()).toEqual([[1,0],[5,3]])

      describe 'when the shift key is pressed', ->
        it 'creates a new selection with the cells from the mouse movements', ->
          startCell = tableElement.querySelector('tablr-cell[data-row="3"][data-column="0"]')
          mousedown(startCell, shiftKey: true)

          expect(tableEditor.getLastSelection().getRange()).toEqual([[0,0],[4,1]])

        describe 'and the mouse position is before the cursor position', ->
          it 'creates the proper selection', ->
            tableEditor.setCursorAtScreenPosition([4,2])

            startCell = tableElement.querySelector('tablr-cell[data-row="1"][data-column="0"]')
            mousedown(startCell, shiftKey: true)

            expect(tableEditor.getLastSelection().getRange()).toEqual([[1,0],[5,3]])

      it 'scrolls the view when the selection reach the last row', ->
        startCell = tableElement.querySelector('tablr-cell[data-row="6"][data-column="0"]')
        endCell = tableElement.querySelector('tablr-cell[data-row="9"][data-column="2"]')

        mousedown(startCell)
        mousemove(endCell)

        expect(tableElement.getRowsContainer().scrollTop).toBeGreaterThan(0)

      it 'scrolls the view when the selection reach the first row', ->
        tableElement.setScrollTop(300)
        nextAnimationFrame()

        startCell = tableElement.querySelector('tablr-cell[data-row="11"][data-column="0"]')
        endCell = tableElement.querySelector('tablr-cell[data-row="8"][data-column="2"]')

        mousedown(startCell)
        mousemove(endCell)

        expect(tableElement.getRowsContainer().scrollTop).toBeLessThan(300)

    it 'scrolls the view when the selection reach the last column', ->
      tableEditor.addColumn('rab')
      tableEditor.addColumn('bar')
      tableElement.setColumnsWidths([500, 500, 500, 500, 500])
      nextAnimationFrame()

      startCell = tableElement.querySelector('tablr-cell[data-row="6"][data-column="0"]')
      endCell = tableElement.querySelector('tablr-cell[data-row="6"][data-column="2"]')

      mousedown(startCell)
      mousemove(endCell)

      expect(tableElement.getRowsContainer().scrollLeft).toBeGreaterThan(0)

    it 'scrolls the view when the selection reach the first column', ->
      tableElement.setColumnsWidths([500, 500, 500])
      nextAnimationFrame()

      tableElement.setScrollLeft(550)
      nextAnimationFrame()

      startCell = tableElement.querySelector('tablr-cell[data-row="11"][data-column="1"]')
      endCell = tableElement.querySelector('tablr-cell[data-row="11"][data-column="0"]')

      mousedown(startCell)
      mousemove(endCell)

      expect(tableElement.getRowsContainer().scrollTop).toBeLessThan(550)

    describe 'when the columns widths have been changed', ->
      beforeEach ->
        tableElement.setColumnsWidths([100, 200, 300])
        nextAnimationFrame()

      it 'creates a selection with the cells from the mouse movements', ->
        startCell = tableElement.querySelector('tablr-cell[data-row="3"][data-column="0"]')
        endCell = tableElement.querySelector('tablr-cell[data-row="6"][data-column="1"]')

        mousedown(startCell)
        mousemove(endCell)

        expect(tableEditor.getLastSelection().getRange()).toEqual([[3,0],[7,2]])

    describe 'dragging the selection box handle', ->
      [handle, handleOffset] = []

      beforeEach ->
        tableEditor.setSelectedRange([[2,0],[3,2]])
        nextAnimationFrame()
        handle = tableElement.querySelector('.selection-box-handle')

        mousedown(handle)

      describe 'to the right', ->
        beforeEach ->
          handleOffset = handle.getBoundingClientRect()
          mousemove(handle, handleOffset.left + 50, handleOffset.top-2)

        it 'expands the selection to the right', ->
          expect(tableEditor.getLastSelection().getRange()).toEqual([[2,0],[3,3]])

    describe 'when there is multiple selections', ->
      beforeEach ->
        tableEditor.setSelectedRanges([
          [[0,0],[1,2]]
          [[2,0],[3,2]]
        ])
        nextAnimationFrame()

      describe 'dragging the first selection box handle', ->
        [handle, handleOffset] = []

        beforeEach ->
          handle = tableElement.querySelector('.selection-box-handle')
          mousedown(handle)

        describe 'to the right', ->
          beforeEach ->
            handleOffset = handle.getBoundingClientRect()
            mousemove(handle, handleOffset.left, handleOffset.top+16)

          it 'expands the selection to the right', ->
            expect(tableEditor.getSelections()[0].getRange()).toEqual([[0,0],[2,2]])
            expect(tableEditor.getSelections()[1].getRange()).toEqual([[2,0],[3,2]])

  #     ######   #######  ########  ######## #### ##    ##  ######
  #    ##    ## ##     ## ##     ##    ##     ##  ###   ## ##    ##
  #    ##       ##     ## ##     ##    ##     ##  ####  ## ##
  #     ######  ##     ## ########     ##     ##  ## ## ## ##   ####
  #          ## ##     ## ##   ##      ##     ##  ##  #### ##    ##
  #    ##    ## ##     ## ##    ##     ##     ##  ##   ### ##    ##
  #     ######   #######  ##     ##    ##    #### ##    ##  ######

  describe 'sorting', ->
    describe 'when a column have been set as the table order', ->
      beforeEach ->
        tableEditor.sortBy 'value', -1
        nextAnimationFrame()

      it 'sorts the rows accordingly', ->
        expect(tableElement.getScreenCellAtPosition([0,0]).textContent).toEqual('row99')

      it 'leaves the cursor position as it was before', ->
        expect(tableEditor.getCursorScreenPosition()).toEqual([0,0])
        expect(tableEditor.getCursorPosition()).toEqual([99,0])
        expect(tableEditor.getLastCursor().getValue()).toEqual(tableEditor.getValueAtPosition([99,0]))

      it 'sets the proper height on the table rows container', ->
        expect(tableElement.querySelector('.tablr-rows-wrapper').offsetHeight).toEqual(2000)

      it 'decorates the table header cell with a class', ->
        expect(tableElement.querySelectorAll('tablr-header-cell.order.descending').length).toEqual(1)

        tableEditor.toggleSortDirection()
        nextAnimationFrame()

        expect(tableElement.querySelectorAll('tablr-header-cell.order.ascending').length).toEqual(1)

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
          tableEditor.toggleSortDirection()
          nextAnimationFrame()

          expect(tableElement.getScreenCellAtPosition([0,0]).textContent).toEqual('row0')

      describe '::resetSort', ->
        beforeEach ->
          tableEditor.resetSort()
          nextAnimationFrame()

        it 'reorder the table in its initial order', ->
          expect(tableElement.getScreenCellAtPosition([0,0]).textContent).toEqual('row0')
