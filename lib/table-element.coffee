{Point, Range, TextEditor} = require 'atom'
{View, $} = require 'space-pen'
{CompositeDisposable, Disposable} = require 'event-kit'
{EventsDelegation} = require 'atom-utils'
PropertyAccessors = require 'property-accessors'
React = require 'react-atom-fork'

Table = require './table'
TableComponent = require './table-component'
TableHeaderComponent = require './table-header-component'
Axis = require './mixins/axis'

PIXEL = 'px'

stopPropagationAndDefault = (f) -> (e) ->
  e.stopPropagation()
  e.preventDefault()
  f?(e)

module.exports =
class TableElement extends HTMLElement
  PropertyAccessors.includeInto(this)
  EventsDelegation.includeInto(this)
  Axis.includeInto(this)

  domPollingInterval: 100
  domPollingIntervalId: null
  domPollingPaused: false
  gutter: false
  rowOffsets: null
  columnOffsets: null
  absoluteColumnsWidths: false

  createdCallback: ->
    @activeCellPosition = new Point
    @subscriptions = new CompositeDisposable

    @initializeContent()
    @subscribeToContent()
    @subscribeToConfig()

  initializeContent: ->
    @shadowRoot = @createShadowRoot()

    @body = document.createElement('div')
    @body.className = 'scroll-view'

    @head = document.createElement('div')
    @head.className = 'table-edit-header'

    @hiddenInput = document.createElement('input')
    @hiddenInput.className = 'hidden-input'

    @contentInsertion = document.createElement('content')
    @contentInsertion.select = 'atom-text-editor'

    @shadowRoot.appendChild(@hiddenInput)
    @shadowRoot.appendChild(@head)
    @shadowRoot.appendChild(@body)
    @shadowRoot.appendChild(@contentInsertion)

    @absoluteColumnsWidths = @hasAttribute('absolute-columns-widths')

  subscribeToContent: ->
    @subscriptions.add @subscribeTo @hiddenInput,
      'textInput': (e) =>
        unless @isEditing()
          @startCellEdit()
          @editor.setText(e.data)

    @subscriptions.add atom.commands.add 'atom-table-editor',
      'core:confirm': => @startCellEdit()
      'core:undo': => @table.undo()
      'core:redo': => @table.redo()
      'core:move-left': => @moveLeft()
      'core:move-right': => @moveRight()
      'core:move-up': => @moveUp()
      'core:move-down': => @moveDown()
      'core:move-to-top': => @moveToTop()
      'core:move-to-bottom': => @moveToBottom()
      'core:page-up': => @pageUp()
      'core:page-down': => @pageDown()
      'core:select-right': => @expandSelectionRight()
      'core:select-left': => @expandSelectionLeft()
      'core:select-up': => @expandSelectionUp()
      'core:select-down': => @expandSelectionDown()
      'table-edit:select-to-end-of-line': => @expandSelectionToEndOfLine()
      'table-edit:select-to-beginning-of-line': => @expandSelectionToBeginningOfLine()
      'table-edit:select-to-end-of-table': => @expandSelectionToEndOfTable()
      'table-edit:select-to-beginning-of-table': => @expandSelectionToBeginningOfTable()
      'table-edit:insert-row-before': => @insertRowBefore()
      'table-edit:insert-row-after': => @insertRowAfter()
      'table-edit:delete-row': => @deleteActiveRow()
      'table-edit:insert-column-before': => @insertColumnBefore()
      'table-edit:insert-column-after': => @insertColumnAfter()
      'table-edit:delete-column': => @deleteActiveColumn()

    @subscriptions.add @subscribeTo this,
      'mousedown': stopPropagationAndDefault (e) => @focus()
      'click': stopPropagationAndDefault()

    @subscriptions.add @subscribeTo @head,
      'mousedown': stopPropagationAndDefault (e) =>
        if column = @columnAtScreenPosition(e.pageX, e.pageY)
          if column.name is @order
            if @direction is -1
              @resetSort()
            else
              @toggleSortDirection()
          else
            @sortBy(column.name)

    @subscriptions.add @subscribeTo @head, '.table-edit-header-cell .column-edit-action',
      'mousedown': stopPropagationAndDefault (e) =>
      'click': stopPropagationAndDefault (e) => @startColumnEdit(e)

    @subscriptions.add @subscribeTo @head, '.table-edit-header-cell .column-resize-handle',
      'mousedown': stopPropagationAndDefault (e) => @startColumnResizeDrag(e)
      'click': stopPropagationAndDefault()

    @subscriptions.add @subscribeTo @body,
      'scroll': (e) => @requestUpdate()
      'dblclick': (e) => @startCellEdit()
      'mousedown': stopPropagationAndDefault (e) =>
        @stopEdit() if @isEditing()

        if position = @cellPositionAtScreenPosition(e.pageX, e.pageY)
          @activateCellAtPosition position

        @startDrag(e)
        @focus()
      'click': stopPropagationAndDefault()

    @subscriptions.add @subscribeTo @body, '.table-edit-rows',
      'mousewheel': (e) =>
        e.stopPropagation()
        requestAnimationFrame =>
          @getColumnsContainer().scrollLeft = @getRowsContainer().scrollLeft

    @subscriptions.add @subscribeTo @body, '.table-edit-gutter',
      'mousedown': stopPropagationAndDefault (e) => @startGutterDrag(e)
      'click': stopPropagationAndDefault()

    @subscriptions.add @subscribeTo @body, '.table-edit-gutter .row-resize-handle',
      'mousedown': stopPropagationAndDefault (e) => @startRowResizeDrag(e)
      'click': stopPropagationAndDefault()

    @subscriptions.add @subscribeTo @body, '.selection-box-handle',
      'mousedown': stopPropagationAndDefault (e) => @startDrag(e)
      'click': stopPropagationAndDefault()

  subscribeToConfig: ->
    @observeConfig
      'table-edit.undefinedDisplay': (@configUndefinedDisplay) =>
        @requestUpdate() if @attached
      'table-edit.pageMovesAmount': (@configPageMovesAmount) =>
        @requestUpdate() if @attached
      'table-edit.minimumRowHeight': (@configMinimumRowHeight) =>
      'table-edit.rowHeight': (@configRowHeight) =>
        if @table?
          @computeRowOffsets()
          @requestUpdate() if @attached
      'table-edit.rowOverdraw': (@configRowOverdraw) =>
        @requestUpdate() if @attached
      'table-edit.columnWidth': (@configColumnWidth) =>
        if @table?
          @computeColumnOffsets()
          @requestUpdate() if @attached
      'table-edit.columnOverdraw': (@configColumnOverdraw) =>
        @requestUpdate() if @attached

  observeConfig: (configs) ->
    for config, callback of configs
      @subscriptions.add atom.config.observe config, callback

  getUndefinedDisplay: -> @undefinedDisplay ? @configUndefinedDisplay

  #        ###    ######## ########    ###     ######  ##     ##
  #       ## ##      ##       ##      ## ##   ##    ## ##     ##
  #      ##   ##     ##       ##     ##   ##  ##       ##     ##
  #     ##     ##    ##       ##    ##     ## ##       #########
  #     #########    ##       ##    ######### ##       ##     ##
  #     ##     ##    ##       ##    ##     ## ##    ## ##     ##
  #     ##     ##    ##       ##    ##     ##  ######  ##     ##

  attach: (target) ->
    target.appendChild(this)

  attachedCallback: ->
    @buildModel() unless @getModel()?
    @computeRowOffsets()
    @computeColumnOffsets()
    @mountComponent() unless @bodyComponent?.isMounted()
    @domPollingIntervalId = setInterval((=> @pollDOM()), @domPollingInterval)
    @measureHeightAndWidth()
    @requestUpdate()
    @attached = true

  mountComponent: ->
    props = {parentView: this}
    @bodyComponent = React.renderComponent(TableComponent(props), @body)
    @headComponent = React.renderComponent(TableHeaderComponent(props), @head)

  detachedCallback: ->
    @attached = false

  destroy: ->
    @subscriptions.dispose()
    @remove()

  remove: ->
    @parentNode?.removeChild(this)

  showGutter: ->
    @gutter = true
    @requestUpdate()

  hideGutter: ->
    @gutter = false
    @requestUpdate()

  pauseDOMPolling: ->
    @domPollingPaused = true
    @resumeDOMPollingAfterDelay ?= debounce(@resumeDOMPolling, 100)
    @resumeDOMPollingAfterDelay()

  resumeDOMPolling: ->
    @domPollingPaused = false

  resumeDOMPollingAfterDelay: null

  pollDOM: ->
    return if @domPollingPaused or @frameRequested

    if @width isnt @clientWidth or @height isnt @clientHeight
      @measureHeightAndWidth()
      @requestUpdate()

  measureHeightAndWidth: ->
    @height = @clientHeight
    @width = @clientWidth

  #    ##     ##  #######  ########  ######## ##
  #    ###   ### ##     ## ##     ## ##       ##
  #    #### #### ##     ## ##     ## ##       ##
  #    ## ### ## ##     ## ##     ## ######   ##
  #    ##     ## ##     ## ##     ## ##       ##
  #    ##     ## ##     ## ##     ## ##       ##
  #    ##     ##  #######  ########  ######## ########

  getModel: -> @table

  buildModel: ->
    model = new Table
    model.addColumn('untitled')
    model.addRow()
    @setModel(model)

  setModel: (table) ->
    return unless table?

    @unsetModel() if @table?

    @table = table
    @modelSubscriptions = new CompositeDisposable()
    @modelSubscriptions.add @table.onDidAddColumn (e) => @onColumnAdded(e)
    @modelSubscriptions.add @table.onDidRemoveColumn (e) => @onColumnRemoved(e)
    @modelSubscriptions.add @table.onDidChangeColumnsOptions =>
      @computeColumnOffsets()
      @requestUpdate()
    @modelSubscriptions.add @table.onDidChangeRows =>
      @computeRowOffsets()
      @requestUpdate()
    @modelSubscriptions.add @table.onDidChangeRowsOptions =>
      @computeRowOffsets()
      @requestUpdate()

    @subscribeToColumn(column) for column in @table.getColumns()

    @updateScreenRows()
    @updateScreenColumns()
    @setSelectionFromActiveCell()
    @requestUpdate()

  unsetModel: ->
    @modelSubscriptions.dispose()
    @modelSubscriptions = null
    @table = null

  #    ########   #######  ##      ##  ######
  #    ##     ## ##     ## ##  ##  ## ##    ##
  #    ##     ## ##     ## ##  ##  ## ##
  #    ########  ##     ## ##  ##  ##  ######
  #    ##   ##   ##     ## ##  ##  ##       ##
  #    ##    ##  ##     ## ##  ##  ## ##    ##
  #    ##     ##  #######   ###  ###   ######

  getRowRange: (row) -> Range.fromObject([[row, 0], [row, @getLastColumn()]])

  getRowsContainer: -> @body.querySelector('.table-edit-rows')

  getRowsWrapper: -> @body.querySelector('.table-edit-rows-wrapper')

  getRowResizeRuler: -> @body.querySelector('.row-resize-ruler')

  insertRowBefore: -> @table.addRowAt(@activeCellPosition.row)

  insertRowAfter: -> @table.addRowAt(@activeCellPosition.row + 1)

  @axis 'y', 'height', 'top', 'row', 'rows'

  #     ######   #######  ##       ##     ## ##     ## ##    ##  ######
  #    ##    ## ##     ## ##       ##     ## ###   ### ###   ## ##    ##
  #    ##       ##     ## ##       ##     ## #### #### ####  ## ##
  #    ##       ##     ## ##       ##     ## ## ### ## ## ## ##  ######
  #    ##       ##     ## ##       ##     ## ##     ## ##  ####       ##
  #    ##    ## ##     ## ##       ##     ## ##     ## ##   ### ##    ##
  #     ######   #######  ########  #######  ##     ## ##    ##  ######

  getLastColumn: -> @table.getColumnsCount() - 1

  getActiveColumn: -> @table.getColumn(@activeCellPosition.column)

  isActiveColumn: (column) -> @activeCellPosition.column is column

  getColumnsAligns: ->
    [0...@table.getColumnsCount()].map (col) =>
      @columnsAligns?[col] ? @table.getColumn(col).align

  setColumnsAligns: (@columnsAligns) ->
    @requestUpdate()

  hasColumnWithWidth: -> @table.getColumns().some (c) -> c.width?

  getColumnWidth: -> @columnWidth ? @configColumnWidth

  setColumnWidth: (@columnWidth) ->

  setAbsoluteColumnsWidths: (@absoluteColumnsWidths) -> @requestUpdate()

  getColumnsWidths: ->
    return @columnsWidths if @columnsWidths

    if @hasColumnWithWidth()
      @columnsWidths = @getColumnsWidthsFromModel()
    else
      count = @table.getColumnsCount()
      if @absoluteColumnsWidths
        (@getColumnWidth() for n in [0...count])
      else
        (1 / count for n in [0...count])

  setColumnsWidths: (columnsWidths) ->
    unless @absoluteColumnsWidths
      columnsWidths = @normalizeColumnsWidths(columnsWidths)

    @columnsWidths = columnsWidths

    @requestUpdate()

  getColumnsWidthsCSS: ->
    if @absoluteColumnsWidths
      @getColumnsWidthPixels()
    else
      @getColumnsWidthPercentages()

  getColumnsWidthPercentages: -> @getColumnsWidths().map @floatToPercent

  getColumnsWidthPixels: -> @getColumnsWidths().map @floatToPixel

  getColumnsWidthsFromModel: ->
    count = @table.getColumnsCount()

    widths = (@table.getColumn(col).width for col in [0...count])
    @normalizeColumnsWidths(widths)

  getColumnsScreenWidths: ->
    if @absoluteColumnsWidths
      @getColumnsWidths()
    else
      width = @getRowsWrapper()?.offsetWidth ? 0
      @getColumnsWidths().map (v) => v * width

  getColumnsScreenMargins: ->
    widths = if @absoluteColumnsWidths
      @getColumnsWidths()
    else
      width = @getRowsWrapper()?.offsetWidth ? 0
      @getColumnsWidths().map (v) -> v * width

    pad = 0
    width = @getRowsWrapper()?.offsetWidth ? 0
    margins = widths.map (v) =>
      res = pad
      pad += v
      res

    margins

  getColumnsContainer: -> @head.querySelector('.table-edit-header-row')

  getColumnsWrapper: -> @head.querySelector('.table-edit-header-wrapper')

  getColumnResizeRuler: -> @head.querySelector('.column-resize-ruler')

  getNewColumnName: -> @newColumnId ?= 0; "untitled_#{@newColumnId++}"

  insertColumnBefore: ->
    @table.addColumnAt(@activeCellPosition.column, @getNewColumnName())

  insertColumnAfter: ->
    @table.addColumnAt(@activeCellPosition.column + 1, @getNewColumnName())

  deleteActiveColumn: ->
    column = @table.getColumn(@activeCellPosition.column).name
    confirmation = atom.confirm
      message: 'Are you sure you want to delete the current active column?'
      detailedMessage: "You are deleting the column '#{column}'."
      buttons: ['Delete Column', 'Cancel']

    @table.removeColumnAt(@activeCellPosition.column) if confirmation is 0

  columnAtScreenPosition: (x,y) ->
    return unless x? and y?

    content = @getColumnsContainer()

    bodyWidth = content.offsetWidth
    bodyOffset = content.getBoundingClientRect()

    x -= bodyOffset.left
    y -= bodyOffset.top

    columnsWidths = @getColumnsScreenWidths()
    column = -1
    pad = 0
    while pad <= x
      pad += columnsWidths[column+1]
      column++

    @table.getColumn(column)

  normalizeColumnsWidths: (columnsWidths) ->
    restWidth = 1
    wholeWidth = 0
    missingIndices = []
    widths = []

    for index in [0...@table.getColumnsCount()]
      width = columnsWidths[index]
      if width?
        widths[index] = width
        wholeWidth += width
        restWidth -= width
      else
        missingIndices.push index

    if (missingCount = missingIndices.length)
      if restWidth <= 0 and missingCount
        restWidth = wholeWidth
        wholeWidth *= 2

      for index in missingIndices
        widths[index] = restWidth / missingCount

    if wholeWidth > 1
      widths = widths.map (w) -> w * (1 / wholeWidth)

    widths

  onColumnAdded: ({column}) ->
    @computeColumnOffsets()
    @calculateNewColumnWidthFor(column) if @columnsWidths?
    @subscribeToColumn(column)
    @requestUpdate()

  onColumnRemoved: ({column, index}) ->
    @computeColumnOffsets()
    @columnsWidths.splice(index, 1) if @columnsWidths?
    @unsubscribeFromColumn(column)
    @requestUpdate()

  calculateNewColumnWidthFor: (column) ->
    index = @table.getColumns().indexOf(column)
    newColumnWidth = 1 / (@table.getColumnsCount())
    columnsWidths = @getColumnsWidths()
    columnsWidths.splice(index, 0, newColumnWidth)
    @setColumnsWidths(columnsWidths)

  subscribeToColumn: (column) ->
    @columnSubscriptions ?= {}
    subscription = @columnSubscriptions[column.id] = new CompositeDisposable

    subscription.add column.onDidChangeName => @requestUpdate()
    subscription.add column.onDidChangeOption => @requestUpdate()

  unsubscribeFromColumn: (column) ->
    @columnSubscriptions[column.id]?.dispose()
    delete @columnSubscriptions[column.id]

  @axis 'x', 'width', 'left', 'column', 'columns'

  #     ######  ######## ##       ##        ######
  #    ##    ## ##       ##       ##       ##    ##
  #    ##       ##       ##       ##       ##
  #    ##       ######   ##       ##        ######
  #    ##       ##       ##       ##             ##
  #    ##    ## ##       ##       ##       ##    ##
  #     ######  ######## ######## ########  ######

  getActiveCell: ->
    @table.cellAtPosition(@modelPosition(@activeCellPosition))

  isActiveCell: (cell) -> @getActiveCell() is cell

  isSelectedCell: (cell) -> @isSelectedPosition(@table.positionOfCell(cell))

  activateCell: (cell) ->
    @activateCellAtPosition(@table.positionOfCell(cell))

  activateCellAtPosition: (position) ->
    return unless position?

    position = Point.fromObject(position)

    @activeCellPosition = position
    @afterActiveCellMove()

  cellScreenRect: (position) ->
    {top, left} = @cellScreenPosition(position)
    widths = @getColumnsScreenWidths()

    width = widths[position.column]
    height = @getScreenRowHeightAt(position.row)

    {top, left, width, height}

  cellScreenPosition: (position) ->
    {top, left} = @cellScrollPosition(position)

    content = @getRowsWrapper()
    contentOffset = content.getBoundingClientRect()

    {
      top: top + contentOffset.top,
      left: left + contentOffset.left
    }

  cellScrollPosition: (position) ->
    position = Point.fromObject(position)
    margins = @getColumnsScreenMargins()
    {
      top: @getScreenRowOffsetAt(position.row)
      left: margins[position.column]
    }

  cellPositionAtScreenPosition: (x,y) ->
    return unless x? and y?

    content = @getRowsWrapper()

    bodyWidth = content.offsetWidth
    bodyOffset = content.getBoundingClientRect()

    x -= bodyOffset.left
    y -= bodyOffset.top

    row = @findRowAtPosition(y)

    columnsWidths = @getColumnsScreenWidths()
    column = -1
    pad = 0
    while pad <= x
      pad += columnsWidths[column+1]
      column++

    {row, column}

  screenPosition: (position) ->
    {row, column} = Point.fromObject(position)

    {row: @modelRowToScreenRow(row), column}

  modelPosition: (position) ->
    {row, column} = Point.fromObject(position)

    {row: @screenRowToModelRow(row), column}

  #     ######   #######  ##    ## ######## ########   #######  ##
  #    ##    ## ##     ## ###   ##    ##    ##     ## ##     ## ##
  #    ##       ##     ## ####  ##    ##    ##     ## ##     ## ##
  #    ##       ##     ## ## ## ##    ##    ########  ##     ## ##
  #    ##       ##     ## ##  ####    ##    ##   ##   ##     ## ##
  #    ##    ## ##     ## ##   ###    ##    ##    ##  ##     ## ##
  #     ######   #######  ##    ##    ##    ##     ##  #######  ########

  focus: -> @hiddenInput.focus() unless @hasFocus()

  hasFocus: -> this is document.activeElement

  moveRight: ->
    if @activeCellPosition.column + 1 < @table.getColumnsCount()
      @activeCellPosition.column++
    else
      @activeCellPosition.column = 0

      if @activeCellPosition.row + 1 < @table.getRowsCount()
        @activeCellPosition.row++
      else
        @activeCellPosition.row = 0

    @afterActiveCellMove()

  moveLeft: ->
    if @activeCellPosition.column - 1 >= 0
      @activeCellPosition.column--
    else
      @activeCellPosition.column = @getLastColumn()

      if @activeCellPosition.row - 1 >= 0
        @activeCellPosition.row--
      else
        @activeCellPosition.row = @getLastRow()

    @afterActiveCellMove()

  moveUp: ->
    if @activeCellPosition.row - 1 >= 0
      @activeCellPosition.row--
    else
      @activeCellPosition.row = @getLastRow()

    @afterActiveCellMove()

  moveDown: ->
    if @activeCellPosition.row + 1 < @table.getRowsCount()
      @activeCellPosition.row++
    else
      @activeCellPosition.row = 0

    @afterActiveCellMove()

  moveToTop: ->
    return if @activeCellPosition.row is 0

    @activeCellPosition.row = 0
    @afterActiveCellMove()

  moveToBottom: ->
    end = @getLastRow()
    return if @activeCellPosition.row is end

    @activeCellPosition.row = end
    @afterActiveCellMove()

  pageDown: ->
    amount = @getPageMovesAmount()
    if @activeCellPosition.row + amount < @table.getRowsCount()
      @activeCellPosition.row += amount
    else
      @activeCellPosition.row = @getLastRow()

    @afterActiveCellMove()

  pageUp: ->
    amount = @getPageMovesAmount()
    if @activeCellPosition.row - amount >= 0
      @activeCellPosition.row -= amount
    else
      @activeCellPosition.row = 0

    @afterActiveCellMove()

  afterActiveCellMove: ->
    @setSelectionFromActiveCell()
    @requestUpdate()
    @makeRowVisible(@activeCellPosition.row)

  getPageMovesAmount: -> @pageMovesAmount ? @configPageMovesAmount

  #    ######## ########  #### ########
  #    ##       ##     ##  ##     ##
  #    ##       ##     ##  ##     ##
  #    ######   ##     ##  ##     ##
  #    ##       ##     ##  ##     ##
  #    ##       ##     ##  ##     ##
  #    ######## ########  ####    ##

  isEditing: -> @editing

  startCellEdit: =>
    @createTextEditor() unless @editor?

    @subscribeToCellTextEditor(@editor)

    @editing = true

    activeCell = @getActiveCell()
    activeCellRect = @cellScreenRect(@activeCellPosition)

    @editorElement.style.top = @toUnit(activeCellRect.top)
    @editorElement.style.left = @toUnit(activeCellRect.left)
    @editorElement.style.width = @toUnit(activeCellRect.width)
    @editorElement.style.height = @toUnit(activeCellRect.height)
    @editorElement.style.display = 'block'
    @editorElement.focus()

    @editor.setText(activeCell.getValue().toString())

    @editor.getBuffer().history.clearUndoStack()
    @editor.getBuffer().history.clearRedoStack()

  confirmCellEdit: ->
    @stopEdit()
    activeCell = @getActiveCell()
    newValue = @editor.getText()
    activeCell.setValue(newValue) unless newValue is activeCell.getValue()

  startColumnEdit: ({target}) =>
    @createTextEditor() unless @editor?

    @subscribeToColumnTextEditor(@editor)

    @editing = true

    activeColumn = @getActiveColumn()
    activeColumnRect = target.parentNode.getBoundingClientRect()

    @editorElement.style.top = @toUnit(activeColumnRect.top)
    @editorElement.style.left =  @toUnit(activeColumnRect.left)
    @editorElement.style.width = @toUnit(activeColumnRect.width)
    @editorElement.style.height = @toUnit(activeColumnRect.height)
    @editorElement.style.display = 'block'

    @editorElement.focus()
    @editor.setText(activeColumn.name)

    @editor.getBuffer().history.clearUndoStack()
    @editor.getBuffer().history.clearRedoStack()

  confirmColumnEdit: ->
    @stopEdit()
    activeColumn = @getActiveColumn()
    newValue = @editor.getText()
    activeColumn.name = newValue unless newValue is activeColumn.name

  stopEdit: ->
    @editing = false
    @editorElement.style.display = 'none'
    @textEditorSubscriptions?.dispose()
    @textEditorSubscriptions = null
    @focus()

  createTextEditor: ->
    @editor = new TextEditor({})
    @editorElement = atom.views.getView(@editor)
    @appendChild(@editorElement)

  subscribeToCellTextEditor: (editor) ->
    @textEditorSubscriptions = new CompositeDisposable
    @textEditorSubscriptions.add atom.commands.add 'atom-table-editor atom-text-editor:not([mini])',

      'table-edit:move-right': (e) =>
        @confirmCellEdit()
        @moveRight()
      'table-edit:move-left': (e) =>
        @confirmCellEdit()
        @moveLeft()
      'core:cancel': (e) =>
        @stopEdit()
        e.stopImmediatePropagation()
        return false
      'core:confirm': (e) =>
        @confirmCellEdit()
        e.stopImmediatePropagation()
        return false

  subscribeToColumnTextEditor: (editorView) ->
    @textEditorSubscriptions = new CompositeDisposable
    @textEditorSubscriptions.add atom.commands.add 'atom-table-editor atom-text-editor:not([mini])',

      'table-edit:move-right': (e) =>
        @confirmColumnEdit()
        @moveRight()
      'table-edit:move-left': (e) =>
        @confirmColumnEdit()
        @moveLeft()
      'core:cancel': (e) =>
        @stopEdit()
        e.stopImmediatePropagation()
        return false
      'core:confirm': (e) =>
        @confirmColumnEdit()
        e.stopImmediatePropagation()
        return false

  #     ######  ######## ##       ########  ######  ########
  #    ##    ## ##       ##       ##       ##    ##    ##
  #    ##       ##       ##       ##       ##          ##
  #     ######  ######   ##       ######   ##          ##
  #          ## ##       ##       ##       ##          ##
  #    ##    ## ##       ##       ##       ##    ##    ##
  #     ######  ######## ######## ########  ######     ##

  isSelectedPosition: (position) ->
    position = Point.fromObject(position)

    position.row >= @selection.start.row and
    position.row <= @selection.end.row and
    position.column >= @selection.start.column and
    position.column <= @selection.end.column

  getSelection: -> @selection

  selectionScrollRect: ->
    {top, left} = @cellScrollPosition(@selection.start)
    width = 0
    height = 0

    widths = @getColumnsScreenWidths()

    for col in [@selection.start.column..@selection.end.column]
      width += widths[col]

    for row in [@selection.start.row..@selection.end.row]
      height += @getScreenRowHeightAt(row)

    {top, left, width, height}

  setSelection: (selection) ->
    @selection = Range.fromObject(selection)
    @activeCellPosition = @selection.start.copy()
    @requestUpdate()

  setSelectionFromActiveCell: ->
    @selection = Range.fromObject([
      [@activeCellPosition.row, @activeCellPosition.column]
      [@activeCellPosition.row, @activeCellPosition.column]
    ])

  expandSelectionRight: ->
    if @selectionExpandedLeft()
      @selection.start.column = Math.min(@selection.start.column + 1, @getLastColumn())
    else
      @selection.end.column = Math.min(@selection.end.column + 1, @getLastColumn())

    @requestUpdate()

  expandSelectionLeft: ->
    if @selectionExpandedRight()
      @selection.end.column = Math.max(@selection.end.column - 1, 0)
    else
      @selection.start.column = Math.max(@selection.start.column - 1, 0)

    @requestUpdate()

  expandSelectionUp: ->
    row = if @selectionExpandedDown()
      @selection.end.row = Math.max(@selection.end.row - 1, 0)
    else
      @selection.start.row = Math.max(@selection.start.row - 1, 0)

    @makeRowVisible(row)
    @requestUpdate()

  expandSelectionDown: ->
    row = if @selectionExpandedUp()
      @selection.start.row = Math.min(@selection.start.row + 1, @getLastRow())
    else
      @selection.end.row = Math.min(@selection.end.row + 1, @getLastRow())

    @makeRowVisible(row)
    @requestUpdate()

  expandSelectionToEndOfLine: ->
    @selection.start.column = @activeCellPosition.column
    @selection.end.column = @getLastColumn()
    @requestUpdate()

  expandSelectionToBeginningOfLine: ->
    @selection.start.column = 0
    @selection.end.column = @activeCellPosition.column
    @requestUpdate()

  expandSelectionToEndOfTable: ->
    @selection.start.row = @activeCellPosition.row
    @selection.end.row = @getLastRow()

    @makeRowVisible(@selection.end.row)
    @requestUpdate()

  expandSelectionToBeginningOfTable: ->
    @selection.start.row = 0
    @selection.end.row = @activeCellPosition.row

    @makeRowVisible(@selection.start.row)
    @requestUpdate()

  selectionExpandedRight: ->
    @activeCellPosition.column is @selection.start.column and
    @activeCellPosition.column isnt @selection.end.column

  selectionExpandedLeft: ->
    @activeCellPosition.column is @selection.end.column and
    @activeCellPosition.column isnt @selection.start.column

  selectionExpandedUp: ->
    @activeCellPosition.row is @selection.end.row and
    @activeCellPosition.row isnt @selection.start.row

  selectionExpandedDown: ->
    @activeCellPosition.row is @selection.start.row and
    @activeCellPosition.row isnt @selection.end.row

  selectionSpansManyCells: ->
    @selectionSpansManyColumns() or @selectionSpansManyRows()

  selectionSpansManyColumns: ->
    @selection.start.column isnt @selection.end.column

  selectionSpansManyRows: ->
    @selection.start.row isnt @selection.end.row

  #    ########    ####    ########
  #    ##     ##  ##  ##   ##     ##
  #    ##     ##   ####    ##     ##
  #    ##     ##  ####     ##     ##
  #    ##     ## ##  ## ## ##     ##
  #    ##     ## ##   ##   ##     ##
  #    ########   ####  ## ########

  startDrag: (e) ->
    return if @dragging

    @dragging = true

    @initializeDragEvents @body,
      'mousemove': stopPropagationAndDefault (e) => @drag(e)
      'mouseup': stopPropagationAndDefault (e) => @endDrag(e)

  drag: (e) ->
    if @dragging
      {pageX, pageY} = e
      {row, column} = @cellPositionAtScreenPosition pageX, pageY

      if row < @activeCellPosition.row
        @selection.start.row = row
        @selection.end.row = @activeCellPosition.row
      else if row > @activeCellPosition.row
        @selection.end.row = row
        @selection.start.row = @activeCellPosition.row
      else
        @selection.end.row = @activeCellPosition.row
        @selection.start.row = @activeCellPosition.row

      if column < @activeCellPosition.column
        @selection.start.column = column
        @selection.end.column = @activeCellPosition.column
      else if column > @activeCellPosition.column
        @selection.end.column = column
        @selection.start.column = @activeCellPosition.column
      else
        @selection.end.column = @activeCellPosition.column
        @selection.start.column = @activeCellPosition.column

      @scrollDuringDrag(row)
      @requestUpdate()

  endDrag: (e) ->
    return unless @dragging

    @drag(e)
    @dragging = false
    @dragSubscription.dispose()

  startGutterDrag: (e) ->
    return if @dragging

    @dragging = true

    row = @findRowAtScreenPosition(e.pageY)
    @setSelection(@getRowRange(row)) if row?

    @initializeDragEvents @body,
      'mousemove': stopPropagationAndDefault (e) => @gutterDrag(e)
      'mouseup': stopPropagationAndDefault (e) => @endGutterDrag(e)

  gutterDrag: (e) ->
    if @dragging
      row = @findRowAtScreenPosition(e.pageY)

      if row < @activeCellPosition.row
        @selection.start.row = row
        @selection.end.row = @activeCellPosition.row
      else if row > @activeCellPosition.row
        @selection.end.row = row
        @selection.start.row = @activeCellPosition.row
      else
        @selection.end.row = @activeCellPosition.row
        @selection.start.row = @activeCellPosition.row

      @scrollDuringDrag(row)
      @requestUpdate()

  endGutterDrag: (e) ->
    return unless @dragging

    @dragSubscription.dispose()
    @gutterDrag(e)
    @dragging = false

  startRowResizeDrag: (e) ->
    return if @dragging

    @dragging = true

    row = @findRowAtScreenPosition(e.pageY)

    handle = e.target
    handleHeight = handle.offsetHeight
    handleOffset = handle.getBoundingClientRect()
    dragOffset = handleOffset.top - e.pageY

    initial = {row, handle, handleHeight, dragOffset}

    rulerTop = @getScreenRowOffsetAt(row) + @getScreenRowHeightAt(row)

    ruler = @getRowResizeRuler()
    ruler.classList.add('visible')
    ruler.style.top = @toUnit(rulerTop)

    @initializeDragEvents @body,
      'mousemove': stopPropagationAndDefault (e) => @rowResizeDrag(e, initial)
      'mouseup': stopPropagationAndDefault (e) => @endRowResizeDrag(e, initial)

  rowResizeDrag: (e, {row, handleHeight, dragOffset}) ->
    if @dragging
      {pageY} = e
      rowY = @rowScreenPosition(row)
      newRowHeight = Math.max(pageY - rowY + dragOffset + handleHeight, @getMinimumRowHeight())
      rulerTop = @getScreenRowOffsetAt(row) + newRowHeight
      ruler = @getRowResizeRuler()
      ruler.style.top = @toUnit(rulerTop)

  endRowResizeDrag: (e, {row, handleHeight, dragOffset}) ->
    return unless @dragging

    {pageY} = e
    rowY = @rowScreenPosition(row)
    newRowHeight = pageY - rowY + dragOffset + handleHeight
    @setScreenRowHeightAt(row, newRowHeight)
    @getRowResizeRuler().classList.remove('visible')

    @dragSubscription.dispose()
    @dragging = false

  startColumnResizeDrag: ({pageX, target}) ->
    return if @dragging

    @dragging = true

    handleWidth = target.offsetWidth
    handleOffset = target.getBoundingClientRect()
    dragOffset = handleOffset.left - pageX

    parent = target.parentNode
    container = parent.parentNode

    leftCellIndex = Array::indexOf.call(container.childNodes, parent)
    rightCellIndex = Array::indexOf.call(container.childNodes, parent.nextSibling)

    initial = {handle: target, leftCellIndex, rightCellIndex, handleWidth, dragOffset, startX: pageX}

    @initializeDragEvents this,
      'mousemove': stopPropagationAndDefault (e) =>
        @columnResizeDrag(e, initial)
      'mouseup': stopPropagationAndDefault (e) =>
        @endColumnResizeDrag(e, initial)

    ruler = @getColumnResizeRuler()
    ruler.classList.add('visible')
    ruler.style.left = @toUnit(pageX - @head.getBoundingClientRect().left)
    ruler.style.height = @toUnit(@offsetHeight)

  columnResizeDrag: ({pageX}) ->
    ruler = @getColumnResizeRuler()
    ruler.style.left = @toUnit(pageX - @head.getBoundingClientRect().left)

  endColumnResizeDrag: ({pageX}, {startX, leftCellIndex, rightCellIndex}) ->
    return unless @dragging

    moveX = pageX - startX
    columnsScreenWidths = @getColumnsScreenWidths()
    columnsWidths = @getColumnsWidths().concat()

    leftCellWidth = columnsScreenWidths[leftCellIndex]
    rightCellWidth = columnsScreenWidths[rightCellIndex]

    if @absoluteColumnsWidths
      columnsWidths[leftCellIndex] = leftCellWidth + moveX
    else
      columnsWidth = @getColumnsWrapper().offsetWidth

      leftCellRatio = (leftCellWidth + moveX) / columnsWidth
      rightCellRatio = (rightCellWidth - moveX) / columnsWidth

      columnsWidths[leftCellIndex] = leftCellRatio
      columnsWidths[rightCellIndex] = rightCellRatio

    @setColumnsWidths(columnsWidths)

    @getColumnResizeRuler().classList.remove('visible')
    @dragSubscription.dispose()
    @dragging = false

  scrollDuringDrag: (row) ->
    if row >= @getLastVisibleRow() - 1
      @makeRowVisible(row + 1)
    else if row <= @getFirstVisibleRow() + 1
      @makeRowVisible(row - 1)

  initializeDragEvents: (object, events) ->
    @dragSubscription = new CompositeDisposable
    for event,callback of events
      @dragSubscription.add @addDisposableEventListener object, event, callback

  #     ######   #######  ########  ######## #### ##    ##  ######
  #    ##    ## ##     ## ##     ##    ##     ##  ###   ## ##    ##
  #    ##       ##     ## ##     ##    ##     ##  ####  ## ##
  #     ######  ##     ## ########     ##     ##  ## ## ## ##   ####
  #          ## ##     ## ##   ##      ##     ##  ##  #### ##    ##
  #    ##    ## ##     ## ##    ##     ##     ##  ##   ### ##    ##
  #     ######   #######  ##     ##    ##    #### ##    ##  ######

  sortBy: (@order, @direction=1) ->
    @updateScreenRows()
    @requestUpdate()

  toggleSortDirection: ->
    @direction *= -1
    @updateScreenRows()
    @requestUpdate()

  resetSort: ->
    @order = null
    @updateScreenRows()
    @requestUpdate()

  #    ##     ## ########  ########     ###    ######## ########
  #    ##     ## ##     ## ##     ##   ## ##      ##    ##
  #    ##     ## ##     ## ##     ##  ##   ##     ##    ##
  #    ##     ## ########  ##     ## ##     ##    ##    ######
  #    ##     ## ##        ##     ## #########    ##    ##
  #    ##     ## ##        ##     ## ##     ##    ##    ##
  #     #######  ##        ########  ##     ##    ##    ########

  setScrollTop: (scroll) ->
    if scroll?
      @body.scrollTop = scroll
      @requestUpdate(false)

    @body.scrollTop

  requestUpdate: (@hasChanged=true) =>
    return if @updateRequested

    @updateRequested = true
    requestAnimationFrame =>
      @update()
      @updateRequested = false

  update: =>
    return unless @table?
    firstVisibleRow = @getFirstVisibleRow()
    lastVisibleRow = @getLastVisibleRow()

    return if firstVisibleRow >= @firstRenderedRow and lastVisibleRow <= @lastRenderedRow and not @hasChanged

    rowOverdraw = @getRowOverdraw()
    firstRow = Math.max 0, firstVisibleRow - rowOverdraw
    lastRow = Math.min @table.getRowsCount(), lastVisibleRow + rowOverdraw

    state = {
      @table
      @gutter
      firstRow
      lastRow
      @absoluteColumnsWidths
      columnsWidths: @getColumnsWidthsCSS()
      columnsAligns: @getColumnsAligns()
      totalRows: @table.getRowsCount()
    }

    @bodyComponent.setState state
    @headComponent.setState state

    @firstRenderedRow = firstRow
    @lastRenderedRow = lastRow
    @hasChanged = false

  floatToPercent: (w) -> "#{Math.round(w * 10000) / 100}%"

  floatToPixel: (w) -> "#{w}px"

  toUnit: (value, unit=PIXEL) -> "#{value}#{unit}"

#    ######## ##       ######## ##     ## ######## ##    ## ########
#    ##       ##       ##       ###   ### ##       ###   ##    ##
#    ##       ##       ##       #### #### ##       ####  ##    ##
#    ######   ##       ######   ## ### ## ######   ## ## ##    ##
#    ##       ##       ##       ##     ## ##       ##  ####    ##
#    ##       ##       ##       ##     ## ##       ##   ###    ##
#    ######## ######## ######## ##     ## ######## ##    ##    ##

module.exports = TableElement = document.registerElement 'atom-table-editor', prototype: TableElement.prototype

TableElement.registerViewProvider = ->
  atom.views.addViewProvider Table, (model) ->
    element = new TableElement
    element.setModel(model)
    element
