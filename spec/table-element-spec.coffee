{$} = require 'space-pen'

path = require 'path'

Table = require '../lib/table'
TableElement = require '../lib/table-element'
Column = require '../lib/column'
Row = require '../lib/row'
Cell = require '../lib/cell'
CustomCellComponent = require './fixtures/custom-cell-component'
{mousedown, mousemove, mouseup, mousewheel, click, dblclick, textInput, objectCenterCoordinates} = require './helpers/events'

stylesheetPath = path.resolve __dirname, '..', 'stylesheets', 'table-edit.less'
stylesheet = "
  #{atom.themes.loadStylesheet(stylesheetPath)}

  atom-table-editor {
    height: 200px;
    width: 400px;
  }

  atom-table-editor::shadow .table-edit-header {
    height: 27px;
  }

  atom-table-editor::shadow .table-edit-row {
    border: 0;
  }

  atom-table-editor::shadow .table-edit-cell {
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
  [tableElement, tableShadowRoot, table, nextAnimationFrame, noAnimationFrame, requestAnimationFrameSafe, styleNode, row, cells, jasmineContent] = []

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

    atom.config.set 'table-edit.rowHeight', 20
    atom.config.set 'table-edit.columnWidth', 100
    atom.config.set 'table-edit.rowOverdraw', 10
    atom.config.set 'table-edit.minimumRowHeight', 10

    tableElement = atom.views.getView(table)
    tableShadowRoot = tableElement.shadowRoot

    styleNode = document.createElement('style')
    styleNode.textContent = stylesheet

    firstChild = jasmineContent.firstChild

    jasmineContent.insertBefore(styleNode, firstChild)
    jasmineContent.insertBefore(tableElement, firstChild)

    nextAnimationFrame()

  it 'holds a table', ->
    expect(tableElement.table).toEqual(table)

  #     ######   #######  ##    ## ######## ######## ##    ## ########
  #    ##    ## ##     ## ###   ##    ##    ##       ###   ##    ##
  #    ##       ##     ## ####  ##    ##    ##       ####  ##    ##
  #    ##       ##     ## ## ## ##    ##    ######   ## ## ##    ##
  #    ##       ##     ## ##  ####    ##    ##       ##  ####    ##
  #    ##    ## ##     ## ##   ###    ##    ##       ##   ###    ##
  #     ######   #######  ##    ##    ##    ######## ##    ##    ##

  it 'has a scroll-view', ->
    expect(tableShadowRoot.querySelector('.scroll-view')).toExist()

  describe 'when not scrolled yet', ->
    it 'renders the lines at the top of the table', ->
      rows = tableShadowRoot.querySelectorAll('.table-edit-row')
      expect(rows.length).toEqual(18)
      expect(rows[0].dataset.rowId).toEqual('1')
      expect(rows[rows.length - 1].dataset.rowId).toEqual('18')

    describe '::getFirstVisibleRow', ->
      it 'returns 0', ->
        expect(tableElement.getFirstVisibleRow()).toEqual(0)

    describe '::getLastVisibleRow', ->
      it 'returns 8', ->
        expect(tableElement.getLastVisibleRow()).toEqual(8)

  describe 'once rendered', ->
    beforeEach ->
      row = tableShadowRoot.querySelector('.table-edit-row')
      cells = row.querySelectorAll('.table-edit-cell')

    it 'has as many columns as the model row', ->
      expect(cells.length).toEqual(3)

    it 'renders undefined cells based on a config', ->
      atom.config.set('table-edit.undefinedDisplay', 'foo')

      tableElement.getActiveCell().setValue(undefined)
      nextAnimationFrame()
      expect(cells[0].textContent).toEqual('foo')

    it 'renders undefined cells based on the view property', ->
      tableElement.undefinedDisplay = 'bar'
      atom.config.set('table-edit.undefinedDisplay', 'foo')

      tableElement.getActiveCell().setValue(undefined)
      nextAnimationFrame()
      expect(cells[0].textContent).toEqual('bar')

    it 'sets the proper height on the table body content', ->
      bodyContent = tableShadowRoot.querySelector('.table-edit-content')

      expect(bodyContent.offsetHeight).toBeCloseTo(2000)

    it 'sets the proper width and height on the table rows container', ->
      bodyContent = tableShadowRoot.querySelector('.table-edit-rows')

      expect(bodyContent.offsetHeight).toBeCloseTo(2000)
      expect(bodyContent.offsetWidth).toBeCloseTo(tableElement.offsetWidth, -1)

    describe 'with the absolute widths setting enabled', ->
      beforeEach ->
        tableElement.setAbsoluteColumnsWidths(true)
        nextAnimationFrame()

        row = tableShadowRoot.querySelector('.table-edit-row')
        cells = row.querySelectorAll('.table-edit-cell')

      describe 'without any columns layout data', ->
        it 'has cells that all have the same width', ->
          expect(cell.offsetWidth).toEqual(100) for cell,i in cells

      describe 'with a columns layout defined', ->
        beforeEach ->
          tableElement.setColumnsWidths([100, 200, 300])
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
          cells = tableShadowRoot.querySelectorAll('.table-edit-header-cell')
          widths = [100,200,300]
          expect(cell.offsetWidth).toEqual(widths[i]) for cell,i in cells

        describe 'when the content is scroll horizontally', ->
          beforeEach ->
            tableElement.getRowsContainer().scrollLeft = 100
            mousewheel(tableElement.getRowsContainer())
            nextAnimationFrame()

          it 'scrolls the header by the same amount', ->
            expect(tableElement.getColumnsContainer().scrollLeft).toEqual(100)

    describe 'with the absolute widths setting disabled', ->
      beforeEach ->
        tableElement.setAbsoluteColumnsWidths(false)
        nextAnimationFrame()

      describe 'without any columns layout data', ->
        it 'has cells that all have the same width', ->
          for cell in cells
            expect(cell.clientWidth).toBeCloseTo(tableElement.clientWidth / 3, -2)

      describe 'with a columns layout defined', ->
        describe 'with an array with enough values', ->
          it 'modifies the columns widths', ->
            tableElement.setColumnsWidths([0.2, 0.3, 0.5])
            nextAnimationFrame()

            expect(cells[0].clientWidth).toBeCloseTo(tableElement.clientWidth * 0.2, -2)
            expect(cells[1].clientWidth).toBeCloseTo(tableElement.clientWidth * 0.3, -2)
            expect(cells[2].clientWidth).toBeCloseTo(tableElement.clientWidth * 0.5, -2)

        describe 'with an array with sparse values', ->
          it 'computes the other columns width', ->
            tableElement.setColumnsWidths([0.2, null, 0.5])
            nextAnimationFrame()

            expect(cells[0].clientWidth).toBeCloseTo(tableElement.clientWidth * 0.2, -2)
            expect(cells[1].clientWidth).toBeCloseTo(tableElement.clientWidth * 0.3, -2)
            expect(cells[2].clientWidth).toBeCloseTo(tableElement.clientWidth * 0.5, -2)

        describe 'with an array with more than one missing value', ->
          it 'divides the rest width between the missing columns', ->
            tableElement.setColumnsWidths([0.2])
            nextAnimationFrame()

            expect(cells[0].clientWidth).toBeCloseTo(tableElement.clientWidth * 0.2, -2)
            expect(cells[1].clientWidth).toBeCloseTo(tableElement.clientWidth * 0.4, -2)
            expect(cells[2].clientWidth).toBeCloseTo(tableElement.clientWidth * 0.4, -2)

        describe 'with an array whose sum is greater than 1', ->
          it 'divides the rest width between the missing columns', ->
            tableElement.setColumnsWidths([0.5, 0.5, 1])
            nextAnimationFrame()

            expect(cells[0].clientWidth).toBeCloseTo(tableElement.clientWidth * 0.25, -2)
            expect(cells[1].clientWidth).toBeCloseTo(tableElement.clientWidth * 0.25, -2)
            expect(cells[2].clientWidth).toBeCloseTo(tableElement.clientWidth * 0.5, -2)

        describe 'with a sparse array whose sum is greater or equal than 1', ->
          it 'divides the rest width between the missing columns', ->
            tableElement.setColumnsWidths([0.5, 0.5])
            nextAnimationFrame()

            expect(cells[0].clientWidth).toBeCloseTo(tableElement.clientWidth * 0.25, -2)
            expect(cells[1].clientWidth).toBeCloseTo(tableElement.clientWidth * 0.25, -2)
            expect(cells[2].clientWidth).toBeCloseTo(tableElement.clientWidth * 0.5, -2)

        describe "by setting the width on model's columns", ->
          it 'uses the columns data', ->
            table.getColumn(0).width = 0.2
            table.getColumn(1).width = 0.3

            nextAnimationFrame()

            expect(cells[0].clientWidth).toBeCloseTo(tableElement.clientWidth * 0.2, -2)
            expect(cells[1].clientWidth).toBeCloseTo(tableElement.clientWidth * 0.3, -2)
            expect(cells[2].clientWidth).toBeCloseTo(tableElement.clientWidth * 0.5, -2)

        describe "from both the model's columns and in the view", ->
          it 'uses the view data and fallback to the columns data if available', ->
            table.getColumn(0).width = 0.2
            table.getColumn(1).width = 0.3

            tableElement.setColumnsWidths([0.8])
            nextAnimationFrame()

            expect(cells[0].clientWidth).toBeCloseTo(tableElement.clientWidth * 0.8, -2)
            expect(cells[1].clientWidth).toBeCloseTo(tableElement.clientWidth * 0.1, -2)
            expect(cells[2].clientWidth).toBeCloseTo(tableElement.clientWidth * 0.1, -2)

      describe 'with alignements defined in the columns models', ->
        it 'sets the cells text-alignement using the model data', ->
          table.getColumn(0).align = 'right'
          table.getColumn(1).align = 'center'

          nextAnimationFrame()

          expect(cells[0].style.textAlign).toEqual('right')
          expect(cells[1].style.textAlign).toEqual('center')
          expect(cells[2].style.textAlign).toEqual('left')

      describe 'with alignements defined in the view', ->
        it 'sets the cells text-alignement with the view data', ->
          tableElement.setColumnsAligns(['right', 'center'])
          nextAnimationFrame()

          expect(cells[0].style.textAlign).toEqual('right')
          expect(cells[1].style.textAlign).toEqual('center')
          expect(cells[2].style.textAlign).toEqual('left')

      describe 'with both alignements defined on the view and models', ->
        it 'sets the cells text-alignement with the view data', ->
          table.getColumn(0).align = 'left'
          table.getColumn(1).align = 'right'
          table.getColumn(2).align = 'center'

          tableElement.setColumnsAligns(['right', 'center'])
          nextAnimationFrame()

          expect(cells[0].style.textAlign).toEqual('right')
          expect(cells[1].style.textAlign).toEqual('center')
          expect(cells[2].style.textAlign).toEqual('center')

    describe 'with a custom cell renderer defined on a column', ->
      it 'uses the provided renderer to render the columns cells', ->
        table.getColumn(2).componentClass = CustomCellComponent

        nextAnimationFrame()

        expect(tableShadowRoot.querySelector('.table-edit-row:first-child .table-edit-cell:last-child').textContent).toEqual('foo: yes')

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
      expect(tableElement.body.scrollTop).toEqual(100)

    it 'does not render new rows', ->
      rows = tableShadowRoot.querySelectorAll('.table-edit-row')
      expect(rows.length).toEqual(18)
      expect(rows[0].dataset.rowId).toEqual('1')
      expect(rows[rows.length-1].dataset.rowId).toEqual('18')

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
      rows = tableShadowRoot.querySelectorAll('.table-edit-row')
      expect(rows.length).toEqual(28)
      expect(rows[0].dataset.rowId).toEqual('6')
      expect(rows[rows.length-1].dataset.rowId).toEqual('33')

  describe 'when the table columns are modified', ->
    describe 'by adding one column', ->
      it 'adjusts the columns widths', ->
        table.addColumn('bar')

        compareCloseArrays(tableElement.getColumnsWidths(), [0.25, 0.25, 0.25, 0.25])

      describe 'when columns have already a width', ->
        it 'adjusts the columns widths and keeps the proportions of initial columns', ->
          tableElement.setColumnsWidths([0.1, 0.1, 0.8])
          table.addColumn('bar')

          compareCloseArrays(tableElement.getColumnsWidths(), [0.08, 0.08, 0.64, 0.2])

    describe 'by removing a column', ->
      it 'adjusts the columns widths', ->
        table.removeColumnAt(2)

        compareCloseArrays(tableElement.getColumnsWidths(), [0.5, 0.5])

    describe 'when columns have already a width', ->
      it 'adjusts the columns widths and keeps the proportions of initial columns', ->
        tableElement.setColumnsWidths([0.1, 0.1, 0.8])
        table.removeColumnAt(2)

        compareCloseArrays(tableElement.getColumnsWidths(), [0.5, 0.5])

  describe 'when the table rows are modified', ->
    describe 'by adding one at the end', ->
      it 'does not render new rows', ->
        table.addRow ['foo', 'bar', 'baz']

        nextAnimationFrame()

        rows = tableShadowRoot.querySelectorAll('.table-edit-row')
        expect(rows.length).toEqual(18)
        expect(rows[0].dataset.rowId).toEqual('1')
        expect(rows[rows.length-1].dataset.rowId).toEqual('18')

    describe 'by adding one at the begining', ->
      it 'updates the rows', ->
        rows = tableShadowRoot.querySelectorAll('.table-edit-row')
        expect(rows[0].querySelector('.table-edit-cell').textContent).toEqual('row0')

        table.addRowAt 0, ['foo', 'bar', 'baz']

        nextAnimationFrame()

        rows = tableShadowRoot.querySelectorAll('.table-edit-row')
        expect(rows.length).toEqual(18)
        expect(rows[0].dataset.rowId).toEqual('1')
        expect(rows[0].querySelector('.table-edit-cell').textContent).toEqual('foo')
        expect(rows[rows.length-1].dataset.rowId).toEqual('18')

    describe 'by adding one in the middle', ->
      it 'updates the rows', ->
        rows = tableShadowRoot.querySelectorAll('.table-edit-row')
        expect(rows[6].querySelector('.table-edit-cell').textContent).toEqual('row6')

        table.addRowAt 6, ['foo', 'bar', 'baz']

        nextAnimationFrame()

        rows = tableShadowRoot.querySelectorAll('.table-edit-row')
        expect(rows.length).toEqual(18)
        expect(rows[0].dataset.rowId).toEqual('1')
        expect(rows[6].querySelector('.table-edit-cell').textContent).toEqual('foo')
        expect(rows[rows.length-1].dataset.rowId).toEqual('18')

    describe 'by updating the content of a row', ->
      it 'update the rows', ->
        rows = tableShadowRoot.querySelectorAll('.table-edit-row')
        expect(rows[6].querySelector('.table-edit-cell').textContent).toEqual('row6')

        table.getRow(6).key = 'foo'

        nextAnimationFrame()

        rows = tableShadowRoot.querySelectorAll('.table-edit-row')
        expect(rows[6].querySelector('.table-edit-cell').textContent).toEqual('foo')

  describe 'setting a custom height for a row', ->
    beforeEach ->
      tableElement.setRowHeightAt(2, 100)
      nextAnimationFrame()

    it 'sets the proper height on the table body content', ->
      bodyContent = tableShadowRoot.querySelector('.table-edit-content')

      expect(bodyContent.offsetHeight).toBeCloseTo(2080)

    it "renders the row's cells with the provided height", ->
      cell = tableShadowRoot.querySelector('.table-edit-row:nth-child(3) .table-edit-cell')

      expect(cell.offsetHeight).toEqual(100)

    it 'offsets the cells after the modified one', ->
      row = tableShadowRoot.querySelector('.table-edit-row:nth-child(4)')

      expect(row.style.top).toEqual('140px')

    it 'activates the cell under the mouse when pressed', ->
      cell = tableShadowRoot.querySelector('.table-edit-row:nth-child(4) .table-edit-cell:nth-child(2)')
      mousedown(cell)

      expect(tableElement.getActiveCell().getValue()).toEqual(300)

    it 'gives the size of the cell to the editor when starting an edit', ->
      tableElement.activateCellAtPosition(row: 2, column: 0)
      nextAnimationFrame()
      tableElement.startCellEdit()

      expect(tableElement.querySelector('atom-text-editor').offsetHeight).toEqual(100)

    it 'uses the offset to position the editor', ->
      tableElement.activateCellAtPosition(row: 3, column: 0)
      nextAnimationFrame()
      tableElement.startCellEdit()

      editorTop = tableElement.querySelector('atom-text-editor').getBoundingClientRect().top
      cellTop = tableShadowRoot.querySelector('.table-edit-cell.active').getBoundingClientRect().top
      expect(editorTop).toBeCloseTo(cellTop, -2)

    describe 'by changing the option on the row itself', ->
      beforeEach ->
        table.getRow(2).height = 50
        nextAnimationFrame()

      it 'sets the proper height on the table body content', ->
        bodyContent = tableShadowRoot.querySelector('.table-edit-content')

        expect(bodyContent.offsetHeight).toBeCloseTo(2030)

      it "renders the row's cells with the provided height", ->
        cell = tableShadowRoot.querySelector('.table-edit-row:nth-child(3) .table-edit-cell')

        expect(cell.offsetHeight).toEqual(50)

      it 'offsets the cells after the modified one', ->
        row = tableShadowRoot.querySelector('.table-edit-row:nth-child(4)')

        expect(row.style.top).toEqual('90px')

    describe 'when scrolled by 300px', ->
      beforeEach ->
        tableElement.setScrollTop(300)
        nextAnimationFrame()

      it 'activates the cell under the mouse when pressed', ->
        cell = tableShadowRoot.querySelector('.table-edit-row[data-row-id="15"] .table-edit-cell:nth-child(2)')
        mousedown(cell)

        expect(tableElement.getActiveCell().getValue()).toEqual(1400)

    describe 'when scrolled all way down to the bottom edge', ->
      beforeEach ->
        tableElement.setScrollTop(2000)
        nextAnimationFrame()

      it 'activates the cell under the mouse when pressed', ->
        cell = tableShadowRoot.querySelector('.table-edit-row:last-child .table-edit-cell:nth-child(2)')
        mousedown(cell)

        expect(tableElement.getActiveCell().getValue()).toEqual(9900)

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
      cells = tableShadowRoot.querySelectorAll('.table-edit-header-cell')
      expect(cells.length).toEqual(3)
      expect(cells[0].textContent).toEqual('key')
      expect(cells[1].textContent).toEqual('value')
      expect(cells[2].textContent).toEqual('foo')

    it 'has cells that contains a resize handle', ->
      expect(tableShadowRoot.querySelectorAll('.column-resize-handle').length).toEqual(tableShadowRoot.querySelectorAll('.table-edit-header-cell').length)

    it 'has cells that contains an edit button', ->
      expect(tableShadowRoot.querySelectorAll('.column-edit-action').length).toEqual(tableShadowRoot.querySelectorAll('.table-edit-header-cell').length)

    it 'has cells that have the same width as the body cells', ->
      tableElement.setColumnsWidths([0.2, 0.3, 0.5])
      nextAnimationFrame()

      cells = tableShadowRoot.querySelectorAll('.table-edit-header-cell')
      rowCells = tableShadowRoot.querySelectorAll('.table-edit-row:first-child .table-edit-cell')

      expect(cells[0].offsetWidth).toBeCloseTo(rowCells[0].offsetWidth, -2)
      expect(cells[1].offsetWidth).toBeCloseTo(rowCells[1].offsetWidth, -2)
      expect(cells[2].offsetWidth).toBeCloseTo(rowCells[rowCells.length-1].offsetWidth, -2)

    describe 'when the gutter is enabled', ->
      beforeEach ->
        tableElement.showGutter()
        nextAnimationFrame()

      it 'contains a filler div to figurate the gutter width', ->
        expect(header.querySelector('.table-edit-header-filler')).toExist()

    describe 'clicking on a header cell', ->
      [column] = []

      beforeEach ->
        column = tableShadowRoot.querySelector('.table-edit-header-cell:last-child')
        mousedown(column)

      it 'changes the sort order to use the clicked column', ->
        expect(tableElement.order).toEqual('foo')
        expect(tableElement.direction).toEqual(1)

      describe 'a second time', ->
        beforeEach ->
          mousedown(column)

        it 'toggles the sort direction', ->
          expect(tableElement.order).toEqual('foo')
          expect(tableElement.direction).toEqual(-1)

      describe 'a third time', ->
        beforeEach ->
          mousedown(column)
          mousedown(column)

        it 'removes the sorting order', ->
          expect(tableElement.order).toBeNull()

      describe 'when the absoluteColumnsWidths setting is enabled', ->
        beforeEach ->
          tableElement.setAbsoluteColumnsWidths(true)
          tableElement.setColumnsWidths([100, 200, 300])
          nextAnimationFrame()

          column = tableShadowRoot.querySelector('.table-edit-header-cell:nth-child(2)')
          mousedown(column)

        it 'changes the sort order to use the clicked column', ->
          expect(tableElement.order).toEqual('value')
          expect(tableElement.direction).toEqual(1)

      describe 'when the columns size have been changed', ->
        beforeEach ->
          tableElement.setColumnsWidths([0.1, 0.1, 0.8])
          nextAnimationFrame()
          column = tableShadowRoot.querySelector('.table-edit-header-cell:first-child')
          mousedown(column)

        it 'changes the sort order to use the clicked column', ->
          expect(tableElement.order).toEqual('key')
          expect(tableElement.direction).toEqual(1)

    describe 'dragging a resize handle', ->
      it 'resizes the columns', ->
        initialColumnWidths = tableElement.getColumnsScreenWidths()

        handle = header.querySelectorAll('.column-resize-handle')[1]
        {x, y} = objectCenterCoordinates(handle)

        mousedown(handle)
        mouseup(handle, x + 50, y)

        newColumnWidths = tableElement.getColumnsScreenWidths()

        expect(newColumnWidths[0]).toBeCloseTo(initialColumnWidths[0], -1)
        expect(newColumnWidths[1]).toBeCloseTo(initialColumnWidths[1] + 50, -1)
        expect(newColumnWidths[2]).toBeCloseTo(initialColumnWidths[2] - 50, -1)

      it 'displays a ruler when starting the drag', ->
        ruler = tableShadowRoot.querySelector('.column-resize-ruler')

        expect(ruler).toExist()
        expect(isVisible(ruler)).toBeFalsy()

        handle = header.querySelectorAll('.column-resize-handle')[1]
        {x} = objectCenterCoordinates(handle)

        mousedown(handle)

        expect(isVisible(ruler)).toBeTruthy()
        comparePixelStyles(ruler.style.left, x + 'px')
        expect(ruler.offsetHeight).toEqual(tableElement.offsetHeight)

      it 'moves the ruler during drag', ->
        ruler = tableShadowRoot.querySelector('.column-resize-ruler')
        handle = header.querySelectorAll('.column-resize-handle')[1]
        {x,y} = objectCenterCoordinates(handle)

        mousedown(handle)
        mousemove(handle, x + 50, y)

        comparePixelStyles(ruler.style.left, (x + 50) + 'px')

      it 'moves the ruler during drag', ->
        ruler = tableShadowRoot.querySelector('.column-resize-ruler')
        handle = header.querySelectorAll('.column-resize-handle')[1]

        mousedown(handle)
        mouseup(handle)

        expect(isVisible(ruler)).toBeFalsy()

      describe 'with absolute columns widths layout', ->
        beforeEach ->
          tableElement.absoluteColumnsWidths = true
          tableElement.setColumnsWidths([100,100,100])

        it 'resizes the columns', ->
          initialColumnWidths = tableElement.getColumnsScreenWidths()

          handle = header.querySelectorAll('.column-resize-handle')[1]
          {x, y} = objectCenterCoordinates(handle)

          mousedown(handle)
          mouseup(handle, x + 50, y)

          newColumnWidths = tableElement.getColumnsScreenWidths()

          expect(newColumnWidths[0]).toBeCloseTo(initialColumnWidths[0])
          expect(newColumnWidths[1]).toBeCloseTo(initialColumnWidths[1] + 50)
          expect(newColumnWidths[2]).toBeCloseTo(initialColumnWidths[2])

    describe 'clicking on a header cell edit action button', ->
      [editor, editorElement, cell, cellOffset] = []

      beforeEach ->
        cell = header.querySelector('.table-edit-header-cell')
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
          expect(tableElement.table.getColumn(0).name).toEqual('foobar')

      describe 'table-edit:move-right', ->
        it 'confirms the current edit and moves the active cursor to the right', ->
          previousActiveCell = tableElement.getActiveCell()
          spyOn(tableElement, 'moveRight')
          editor.setText('Foo Bar')
          atom.commands.dispatch(editorElement, 'table-edit:move-right')

          expect(tableElement.isEditing()).toBeFalsy()
          expect(tableElement.table.getColumn(0).name).toEqual('Foo Bar')
          expect(tableElement.moveRight).toHaveBeenCalled()

      describe 'table-edit:move-left', ->
        it 'confirms the current edit and moves the active cursor to the left', ->
          previousActiveCell = tableElement.getActiveCell()
          spyOn(tableElement, 'moveLeft')
          editor.setText('Foo Bar')
          atom.commands.dispatch(editorElement, 'table-edit:move-left')

          expect(tableElement.isEditing()).toBeFalsy()
          expect(tableElement.table.getColumn(0).name).toEqual('Foo Bar')
          expect(tableElement.moveLeft).toHaveBeenCalled()

  #     ######   ##     ## ######## ######## ######## ########
  #    ##    ##  ##     ##    ##       ##    ##       ##     ##
  #    ##        ##     ##    ##       ##    ##       ##     ##
  #    ##   #### ##     ##    ##       ##    ######   ########
  #    ##    ##  ##     ##    ##       ##    ##       ##   ##
  #    ##    ##  ##     ##    ##       ##    ##       ##    ##
  #     ######    #######     ##       ##    ######## ##     ##

  describe 'gutter', ->
    it 'is rendered only when the flag is enabled', ->
      expect(tableShadowRoot.querySelector('.table-edit-gutter')).not.toExist()

      tableElement.showGutter()
      nextAnimationFrame()

      expect(tableShadowRoot.querySelector('.table-edit-gutter')).toExist()

    describe 'rows numbers', ->
      [content, gutter] = []

      beforeEach ->
        tableElement.showGutter()
        nextAnimationFrame()
        content = tableShadowRoot.querySelector('.table-edit-content')
        gutter = tableShadowRoot.querySelector('.table-edit-gutter')

      it 'contains a filler div to set the gutter width', ->
        expect(gutter.querySelector('.table-edit-gutter-filler')).toExist()

      it 'matches the count of rows in the body', ->
        expect(gutter.querySelectorAll('.table-edit-row-number').length)
        .toEqual(content.querySelectorAll('.table-edit-row').length)

      it 'contains resize handlers for each row', ->
        expect(gutter.querySelectorAll('.table-edit-row-number .row-resize-handle').length)
        .toEqual(content.querySelectorAll('.table-edit-row').length)

      describe 'pressing the mouse on a gutter cell', ->
        beforeEach ->
          cell = gutter.querySelectorAll('.table-edit-row-number')[2]
          mousedown(cell)
          nextAnimationFrame()

        it 'selects the whole line', ->
          expect(tableElement.activeCellPosition).toEqual([2,0])
          expect(tableElement.getSelection()).toEqual([[2,0],[2,2]])

        describe 'then dragging the mouse down', ->
          beforeEach ->
            cell = gutter.querySelectorAll('.table-edit-row-number')[4]
            mousemove(cell)
            nextAnimationFrame()

          it 'expands the selection with the covered rows', ->
            expect(tableElement.activeCellPosition).toEqual([2,0])
            expect(tableElement.getSelection()).toEqual([[2,0],[4,2]])

          describe 'until reaching the bottom of the view', ->
            beforeEach ->
              cell = gutter.querySelectorAll('.table-edit-row-number')[10]
              mousemove(cell)
              nextAnimationFrame()

            it 'scrolls the view', ->
              expect(tableElement.body.scrollTop).toBeGreaterThan(0)

          describe 'then dragging the mouse up', ->
            beforeEach ->
              cell = gutter.querySelectorAll('.table-edit-row-number')[0]
              mousemove(cell)
              nextAnimationFrame()

            it 'changes the selection using the active cell as pivot', ->
              expect(tableElement.activeCellPosition).toEqual([2,0])
              expect(tableElement.getSelection()).toEqual([[0,0],[2,2]])

      describe 'dragging the mouse over gutter cells and reaching the top of the view', ->
        it 'scrolls the view', ->
          tableElement.setScrollTop(300)
          nextAnimationFrame()

          startCell = tableShadowRoot.querySelector('.table-edit-row-number:nth-child(12)')
          endCell = tableShadowRoot.querySelector('.table-edit-row-number:nth-child(9)')

          mousedown(startCell)
          mousemove(endCell)

          expect(tableElement.body.scrollTop).toBeLessThan(300)

      describe 'dragging the resize handler of a row number', ->
        it 'resize the row on mouse up', ->
          handle = tableShadowRoot.querySelectorAll('.table-edit-row-number .row-resize-handle')[2]
          {x, y} = objectCenterCoordinates(handle)

          mousedown(handle)
          mouseup(handle, x, y + 50)

          expect(tableElement.getRowHeightAt(2)).toEqual(70)

        it 'displays a ruler when the drag have begun', ->
          ruler = tableShadowRoot.querySelector('.row-resize-ruler')

          expect(isVisible(ruler)).toBeFalsy()

          handle = tableShadowRoot.querySelectorAll('.table-edit-row-number .row-resize-handle')[2]
          mousedown(handle)

          expect(isVisible(ruler)).toBeTruthy()
          expect(ruler.getBoundingClientRect().top).toEqual(handle.getBoundingClientRect().top + handle.offsetHeight)

        it 'moves the handle during the drag', ->
          ruler = tableShadowRoot.querySelector('.row-resize-ruler')
          handle = tableShadowRoot.querySelectorAll('.table-edit-row-number .row-resize-handle')[2]
          {x, y} = objectCenterCoordinates(handle)

          mousedown(handle)
          mousemove(handle, x, y + 50)

          expect(ruler.getBoundingClientRect().top).toEqual(handle.getBoundingClientRect().top + handle.offsetHeight + 50)

        it 'hides the ruler on drag end', ->
          ruler = tableShadowRoot.querySelector('.row-resize-ruler')
          handle = tableShadowRoot.querySelectorAll('.table-edit-row-number .row-resize-handle')[2]
          mousedown(handle)
          mouseup(handle)

          expect(isVisible(ruler)).toBeFalsy()

        it 'stops the resize when the height is lower than the minimum row height', ->
          ruler = tableShadowRoot.querySelector('.row-resize-ruler')
          handle = tableShadowRoot.querySelectorAll('.table-edit-row-number .row-resize-handle')[2]
          {x, y} = objectCenterCoordinates(handle)

          mousedown(handle)
          mousemove(handle, x, y + -20)

          expect(ruler.getBoundingClientRect().top).toEqual(handle.getBoundingClientRect().top + handle.offsetHeight - 10)

          mouseup(handle, x, y + -20)

          expect(tableElement.getRowHeightAt(2)).toEqual(10)

      describe 'when an editor is opened', ->
        [editor, editorElement] = []

        beforeEach ->
          tableElement.startCellEdit()
          editorElement = tableElement.querySelector('atom-text-editor')
          editor = editorElement.model

        it 'opens a text editor above the active cell', ->
          cell = tableShadowRoot.querySelector('.table-edit-row:first-child .table-edit-cell:first-child')
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

    expect(tableElement.hiddenInput.matches(':focus')).toBeTruthy()

  it 'activates the cell under the mouse when pressed', ->
    cell = tableShadowRoot.querySelector('.table-edit-row:nth-child(4) .table-edit-cell:last-child')
    mousedown(cell)

    expect(tableElement.getActiveCell().getValue()).toEqual('no')

  it 'does not focus the hidden input twice when multiple press occurs', ->
    spyOn(tableElement.hiddenInput, 'focus').andCallThrough()

    mousedown(tableElement)
    mousedown(tableElement)

    expect(tableElement.hiddenInput.focus).toHaveBeenCalled()
    expect(tableElement.hiddenInput.focus.calls.length).toEqual(1)
    expect(tableElement.hiddenInput.matches(':focus')).toBeTruthy()

  it 'has an active cell', ->
    activeCell = tableElement.getActiveCell()
    expect(activeCell).toBeDefined()
    expect(activeCell.getValue()).toEqual('row0')

  it 'renders the active cell using a class', ->
    expect(tableShadowRoot.querySelectorAll('.table-edit-header-cell.active-column').length).toEqual(1)
    expect(tableShadowRoot.querySelectorAll('.table-edit-row.active-row').length).toEqual(1)
    expect(tableShadowRoot.querySelectorAll('.table-edit-cell.active').length).toEqual(1)
    expect(tableShadowRoot.querySelectorAll('.table-edit-cell.active-column').length)
    .toBeGreaterThan(1)

  describe 'when the absoluteColumnsWidths setting is enabled', ->
    beforeEach ->
      tableElement.setAbsoluteColumnsWidths(true)
      nextAnimationFrame()

    it 'activates the cell under the mouse when pressed', ->
      cell = tableShadowRoot.querySelector('.table-edit-row:nth-child(4) .table-edit-cell:last-child')
      mousedown(cell)

      expect(tableElement.getActiveCell().getValue()).toEqual('no')

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

      expect(tableElement.getActiveCell().getValue()).toEqual(0)

      tableElement.moveRight()

      expect(tableElement.getActiveCell().getValue()).toEqual('yes')

    it 'moves the active cell to the next row when on last cell of a row', ->
      tableElement.moveRight()
      tableElement.moveRight()
      tableElement.moveRight()
      expect(tableElement.getActiveCell().getValue()).toEqual('row1')

    it 'moves the active cell to the first row when on last cell of last row', ->
      tableElement.activeCellPosition.row = 99
      tableElement.activeCellPosition.column = 2

      tableElement.moveRight()
      expect(tableElement.getActiveCell().getValue()).toEqual('row0')

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
      expect(tableElement.getActiveCell().getValue()).toEqual('no')

    it 'moves the active cell cursor to the left', ->
      tableElement.moveRight()
      tableElement.moveLeft()
      expect(tableElement.getActiveCell().getValue()).toEqual('row0')

    it 'moves the active cell cursor to the upper row', ->
      tableElement.moveRight()
      tableElement.moveRight()
      tableElement.moveRight()
      tableElement.moveLeft()
      expect(tableElement.getActiveCell().getValue()).toEqual('yes')

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
      expect(tableElement.getActiveCell().getValue()).toEqual('row99')

    it 'moves the active cell on the upper row', ->
      tableElement.activeCellPosition.row = 10

      tableElement.moveUp()
      expect(tableElement.getActiveCell().getValue()).toEqual('row9')

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
      expect(tableElement.getActiveCell().getValue()).toEqual('row1')

    it 'moves the active cell to the first row when on the last row', ->
      tableElement.activeCellPosition.row = 99

      tableElement.moveDown()
      expect(tableElement.getActiveCell().getValue()).toEqual('row0')

  describe '::makeRowVisible', ->
    it 'scrolls the view until the passed-on row become visible', ->
      tableElement.makeRowVisible(50)

      expect(tableElement.body.scrollTop).toEqual(847)

  describe 'core:undo', ->
    it 'triggers an undo on the table', ->
      spyOn(table, 'undo')

      atom.commands.dispatch(tableElement, 'core:undo')

      expect(table.undo).toHaveBeenCalled()

  describe 'core:redo', ->
    it 'triggers an redo on the table', ->
      spyOn(table, 'redo')

      atom.commands.dispatch(tableElement, 'core:redo')

      expect(table.redo).toHaveBeenCalled()

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

      expect(table.getRow(0).getValues()).toEqual([null, null, null])

  describe 'table-edit:insert-row-after', ->
    it 'inserts a new row after the active row', ->
      atom.commands.dispatch(tableElement, 'table-edit:insert-row-after')

      expect(table.getRow(1).getValues()).toEqual([null, null, null])

  describe 'table-edit:delete-row', ->
    it 'deletes the current active row', ->
      mockConfirm(0)
      atom.commands.dispatch(tableElement, 'table-edit:delete-row')

      expect(table.getRow(0).getValues()).toEqual(['row1', 100, 'no'])

    it 'asks for a confirmation', ->
      mockConfirm(0)
      atom.commands.dispatch(tableElement, 'table-edit:delete-row')

      expect(atom.confirm).toHaveBeenCalled()

    it 'does not remove the row when cancelled', ->
      mockConfirm(1)
      atom.commands.dispatch(tableElement, 'table-edit:delete-row')

      expect(table.getRow(0).getValues()).toEqual(['row0', 0, 'yes'])

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

      expect(table.getRow(0).getValues()).toEqual([null, 'row0', 0, 'yes'])

    it 'adjusts the columns width and keeps proportions of the initial columns', ->
      tableElement.setColumnsWidths([0.1, 0.1, 0.8])
      atom.commands.dispatch(tableElement, 'table-edit:insert-column-before')

      compareCloseArrays(tableElement.getColumnsWidths(), [0.2, 0.08, 0.08, 0.64])

    describe 'called several times', ->
      it 'creates incremental names for columns', ->
        atom.commands.dispatch(tableElement, 'table-edit:insert-column-before')
        atom.commands.dispatch(tableElement, 'table-edit:insert-column-before')

        expect(table.getColumn(0).name).toEqual('untitled_1')
        expect(table.getColumn(1).name).toEqual('untitled_0')

  describe 'table-edit:insert-column-after', ->
    it 'inserts a new column after the active column', ->
      atom.commands.dispatch(tableElement, 'table-edit:insert-column-after')

      expect(table.getRow(0).getValues()).toEqual(['row0', null, 0, 'yes'])

    it 'adjusts the columns width and keeps proportions of the initial columns', ->
      tableElement.setColumnsWidths([0.1, 0.1, 0.8])
      atom.commands.dispatch(tableElement, 'table-edit:insert-column-after')

      compareCloseArrays(tableElement.getColumnsWidths(), [0.08, 0.2, 0.08, 0.64])

    describe 'called several times', ->
      it 'creates incremental names for columns', ->
        atom.commands.dispatch(tableElement, 'table-edit:insert-column-after')
        atom.commands.dispatch(tableElement, 'table-edit:insert-column-after')

        expect(table.getColumn(1).name).toEqual('untitled_1')
        expect(table.getColumn(2).name).toEqual('untitled_0')

  describe 'table-edit:delete-column', ->
    it 'deletes the current active column', ->
      mockConfirm(0)
      atom.commands.dispatch(tableElement, 'table-edit:delete-column')

      expect(table.getRow(0).getValues()).toEqual([0, 'yes'])

    it 'asks for a confirmation', ->
      mockConfirm(0)
      atom.commands.dispatch(tableElement, 'table-edit:delete-column')

      expect(atom.confirm).toHaveBeenCalled()

    it 'does not remove the column when cancelled', ->
      mockConfirm(1)
      atom.commands.dispatch(tableElement, 'table-edit:delete-column')

      expect(table.getRow(0).getValues()).toEqual(['row0', 0, 'yes'])

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

    it 'starts the edition of the active cell', ->
      expect(tableElement.isEditing()).toBeTruthy()

    it 'fills the editor with the input data', ->
      editor = tableElement.querySelector('atom-text-editor').model
      expect(editor.getText()).toEqual('x')

  describe 'double clicking on a cell', ->
    beforeEach ->
      cell = tableShadowRoot.querySelector('.table-edit-row:last-child .table-edit-cell:last-child')
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
      cell = tableShadowRoot.querySelector('.table-edit-row:first-child .table-edit-cell:first-child')
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
      expect(tableElement.getActiveCell().getValue()).toEqual('row0')

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
        previousActiveCell = tableElement.getActiveCell()
        spyOn(tableElement, 'moveRight')
        editor.setText('Foo Bar')
        atom.commands.dispatch(editorElement, 'table-edit:move-right')

        expect(tableElement.isEditing()).toBeFalsy()
        expect(previousActiveCell.getValue()).toEqual('Foo Bar')
        expect(tableElement.moveRight).toHaveBeenCalled()

    describe 'table-edit:move-left', ->
      it 'confirms the current edit and moves the active cursor to the left', ->
        previousActiveCell = tableElement.getActiveCell()
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
          expect(tableElement.getActiveCell().getValue()).toEqual('foobar')

      describe 'when the content of the editor did not changed', ->
        beforeEach ->
          spyOn(tableElement.getActiveCell(), 'setValue').andCallThrough()
          atom.commands.dispatch(editorElement, 'core:confirm')

        it 'closes the editor', ->
          expect(isVisible(tableElement.querySelector('atom-text-editor'))).toBeFalsy()

        it 'gives the focus back to the table view', ->
          expect(tableElement.hiddenInput.matches(':focus')).toBeTruthy()

        it 'leaves the cell value as is', ->
          expect(tableElement.getActiveCell().getValue()).toEqual('row0')
          expect(tableElement.getActiveCell().setValue).not.toHaveBeenCalled()

    describe 'clicking on another cell', ->
      beforeEach ->
        cell = tableShadowRoot.querySelector('.table-edit-row:nth-child(4) .table-edit-cell:last-child')
        mousedown(cell)

      it 'closes the editor', ->
        expect(tableElement.isEditing()).toBeFalsy()

  #     ######  ######## ##       ########  ######  ########
  #    ##    ## ##       ##       ##       ##    ##    ##
  #    ##       ##       ##       ##       ##          ##
  #     ######  ######   ##       ######   ##          ##
  #          ## ##       ##       ##       ##          ##
  #    ##    ## ##       ##       ##       ##    ##    ##
  #     ######  ######## ######## ########  ######     ##

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

      expect(tableShadowRoot.querySelectorAll('.selected').length).toEqual(6)

    it 'marks the row number with a selected class', ->
      tableElement.showGutter()
      tableElement.setSelection([[2,0],[3,2]])

      nextAnimationFrame()

      expect(tableShadowRoot.querySelectorAll('.table-edit-row-number.selected').length).toEqual(2)
  describe 'when the selection spans only one cell', ->
    it 'does not render the selection box', ->
      expect(tableShadowRoot.querySelectorAll('.selection-box').length).toEqual(0)
      expect(tableShadowRoot.querySelectorAll('.selection-box-handle').length).toEqual(0)

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
      cells = tableShadowRoot.querySelectorAll('.table-edit-cell.selected')
      firstCell = cells[0]
      lastCell = cells[2]

      selectionBoxOffset = selectionBox.getBoundingClientRect()
      firstCellOffset = firstCell.getBoundingClientRect()

      expect(selectionBoxOffset.top).toEqual(firstCellOffset.top)
      expect(selectionBoxOffset.left).toEqual(firstCellOffset.left)
      expect(selectionBox.offsetWidth).toEqual(tableShadowRoot.querySelector('.table-edit-rows').offsetWidth)
      expect(selectionBox.offsetHeight).toEqual(firstCell.offsetHeight + lastCell.offsetHeight)

    it 'positions the selection box handle at the bottom right corner', ->
      cells = tableShadowRoot.querySelectorAll('.table-edit-cell.selected')
      lastCell = cells[2]
      lastCellOffset = lastCell.getBoundingClientRect()
      selectionBoxHandleOffset = selectionBoxHandle.getBoundingClientRect()

      expect(selectionBoxHandleOffset.top - 20).toBeCloseTo(lastCellOffset.bottom, -1)
      expect(selectionBoxHandleOffset.left).toBeCloseTo(lastCellOffset.right, -1)

    describe 'when the columns widths have been changed', ->
      beforeEach ->
        tableElement.setColumnsWidths([0.1, 0.1, 0.8])
        tableElement.setSelection([[2,0],[3,1]])
        nextAnimationFrame()

      it 'positions the selection box over the cells', ->
        cells = tableShadowRoot.querySelectorAll('.table-edit-cell.selected')
        firstCell = cells[0]
        lastCell = cells[2]

        selectionBoxOffset = selectionBox.getBoundingClientRect()
        firstCellOffset = firstCell.getBoundingClientRect()

        expect(selectionBoxOffset.top).toEqual(firstCellOffset.top)
        expect(selectionBoxOffset.left).toEqual(firstCellOffset.left)
        expect(selectionBox.offsetWidth).toEqual(firstCell.offsetWidth + lastCell.offsetWidth)
        expect(selectionBox.offsetHeight).toEqual(firstCell.offsetHeight + lastCell.offsetHeight)

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
      tableElement.scrollTop(200)
      tableElement.activateCellAtPosition([10,0])

      atom.commands.dispatch(tableElement, 'core:select-up')

      expect(tableElement.body.scrollTop()).toEqual(180)

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

      expect(tableElement.body.scrollTop()).not.toEqual(0)

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

      expect(tableElement.body.scrollTop()).not.toEqual(0)

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

      expect(tableElement.body.scrollTop()).toEqual(0)

    describe 'table-edit:select-to-end-of-table', ->
      it 'expands the selection to the end of the table', ->
        tableElement.activateCellAtPosition([1,0])

        atom.commands.dispatch(tableElement, 'table-edit:select-to-beginning-of-table')
        atom.commands.dispatch(tableElement, 'table-edit:select-to-end-of-table')

        expect(tableElement.getSelection()).toEqual([[1,0],[99,0]])

  describe 'dragging the mouse pressed over cell', ->
    it 'creates a selection with the cells from the mouse movements', ->
      startCell = tableShadowRoot.querySelectorAll('.table-edit-row:nth-child(4) .table-edit-cell:nth-child(1)')
      endCell = tableShadowRoot.querySelectorAll('.table-edit-row:nth-child(7) .table-edit-cell:nth-child(3)')

      mousedown(startCell)
      mousemove(endCell)

      expect(tableElement.getSelection()).toEqual([[3,0],[6,2]])

      mousedown(endCell)
      mousemove(startCell)

      expect(tableElement.getSelection()).toEqual([[3,0],[6,2]])

    it 'scrolls the view when the selection reach the last row', ->
      startCell = tableShadowRoot.querySelectorAll('.table-edit-row:nth-child(7) .table-edit-cell:nth-child(1)')
      endCell = tableShadowRoot.querySelectorAll('.table-edit-row:nth-child(10) .table-edit-cell:nth-child(3)')

      mousedown(startCell)
      mousemove(endCell)

      expect(tableElement.body.scrollTop()).toBeGreaterThan(0)

    it 'scrolls the view when the selection reach the first row', ->
      tableElement.scrollTop(300)
      nextAnimationFrame()

      startCell = tableShadowRoot.querySelectorAll('.table-edit-row:nth-child(12) .table-edit-cell:nth-child(1)')
      endCell = tableShadowRoot.querySelectorAll('.table-edit-row:nth-child(9) .table-edit-cell:nth-child(3)')

      mousedown(startCell)
      mousemove(endCell)

      expect(tableElement.body.scrollTop()).toBeLessThan(300)

  describe 'when the columns widths have been changed', ->
    beforeEach ->
      tableElement.setColumnsWidths([0.1, 0.1, 0.8])
      nextAnimationFrame()

    it 'creates a selection with the cells from the mouse movements', ->
      startCell = tableShadowRoot.querySelectorAll('.table-edit-row:nth-child(4) .table-edit-cell:nth-child(1)')
      endCell = tableShadowRoot.querySelectorAll('.table-edit-row:nth-child(7) .table-edit-cell:nth-child(2)')

      mousedown(startCell)
      mousemove(endCell)

      expect(tableElement.getSelection()).toEqual([[3,0],[6,1]])

  describe 'dragging the selection box handle', ->
    [handle, handleOffset] = []

    beforeEach ->
      tableElement.setSelection([[2,0],[2,1]])
      nextAnimationFrame()
      handle = tableShadowRoot.querySelectorAll('.selection-box-handle')

      mousedown(handle)

    describe 'to the right', ->
      beforeEach ->
        handleOffset = handle.offset()
        mousemove(handle, handleOffset.left + 50, handleOffset.top + 2)

      it 'expands the selection to the right', ->
        expect(tableElement.getSelection()).toEqual([[2,0],[2,2]])

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
        tableElement.sortBy 'value', -1
        nextAnimationFrame()

      it 'sorts the rows accordingly', ->
        expect(tableShadowRoot.querySelectorAll('.table-edit-row:first-child .table-edit-cell:first-child').text()).toEqual('row99')

      it 'leaves the active cell position as it was before', ->
        expect(tableElement.activeCellPosition).toEqual([0,0])
        expect(tableElement.getActiveCell()).toEqual(table.cellAtPosition([99,0]))

      it 'sets the proper height on the table rows container', ->
        expect(tableShadowRoot.querySelectorAll('.table-edit-rows').height()).toEqual(2000)

      it 'decorates the table cells with a class', ->
        expect(tableShadowRoot.querySelectorAll('.table-edit-cell.order').length).toBeGreaterThan(1)

      it 'decorates the table header cell with a class', ->
        expect(tableShadowRoot.querySelectorAll('.table-edit-header-cell.order.descending').length).toEqual(1)

        tableElement.toggleSortDirection()
        nextAnimationFrame()

        expect(tableShadowRoot.querySelectorAll('.table-edit-header-cell.order.ascending').length).toEqual(1)

      describe 'opening an editor', ->
        beforeEach ->
          tableElement.startCellEdit()

        it 'opens the editor at the cell position', ->
          editorOffset = tableShadowRoot.querySelectorAll('atom-text-editor').offset()
          cellOffset = tableShadowRoot.querySelectorAll('.table-edit-row:first-child .table-edit-cell:first-child').offset()

          expect(editorOffset.top).toBeCloseTo(cellOffset.top, -1)
          expect(editorOffset.left).toBeCloseTo(cellOffset.left, -1)

      describe '::toggleSortDirection', ->
        it 'changes the direction of the table sort', ->
          tableElement.toggleSortDirection()
          nextAnimationFrame()

          expect(tableElement.direction).toEqual(1)
          expect(tableShadowRoot.querySelectorAll('.table-edit-row:first-child .table-edit-cell:first-child').text()).toEqual('row0')

      describe '::resetSort', ->
        beforeEach ->
          tableElement.resetSort()
          nextAnimationFrame()

        it 'clears the value for table order', ->
          expect(tableElement.order).toBeNull()

        it 'reorder the table in its initial order', ->
          expect(tableShadowRoot.querySelectorAll('.table-edit-row:first-child .table-edit-cell:first-child').text()).toEqual('row0')
