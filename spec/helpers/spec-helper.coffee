Tablr = require '../../lib/tablr'
TableElement = require '../../lib/table-element'

deserializers = {
  CSVEditor: 'deserializeCSVEditor',
  TableEditor: 'deserializeTableEditor',
  DisplayTable: 'deserializeDisplayTable',
  Table: 'deserializeTable'
}

beforeEach ->
  atom.views.addViewProvider(Tablr.tablrViewProvider)
  TableElement.registerCommands()

  for k,v of deserializers
    atom.deserializers.add name: k, deserialize: Tablr[v]
