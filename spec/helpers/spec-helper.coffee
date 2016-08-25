Tablr = require '../../lib/tablr'

beforeEach ->
  Table = require '../../lib/table'
  DisplayTable = require '../../lib/display-table'
  TableEditor = require '../../lib/table-editor'
  CSVEditor = require '../../lib/csv-editor'
  {CSVEditorPlaceholder, CSVEditorPlaceholderElement} = require '../../lib/csv-editor-placeholder'

  atom.deserializers.add(CSVEditor)
  atom.deserializers.add(CSVEditorPlaceholder)
  atom.deserializers.add(TableEditor)
  atom.deserializers.add(DisplayTable)
  atom.deserializers.add(Table)

  TableElement = require '../../lib/table-element'
  TableSelectionElement = require '../../lib/table-selection-element'
  CSVEditorElement = require '../../lib/csv-editor-element'

  CSVEditorElement.registerViewProvider()
  TableElement.registerViewProvider()
  TableSelectionElement.registerViewProvider()
  CSVEditorPlaceholderElement.registerViewProvider()
