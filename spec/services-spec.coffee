require './helpers/spec-helper'

Tablr = require '../lib/tablr'
Table = require '../lib/table'
DisplayTable = require '../lib/display-table'
TableEditor = require '../lib/table-editor'
Range = require '../lib/range'
CSVEditor = require '../lib/csv-editor'

describe 'Tablr', ->
  describe '.provideTablrModelsServiceV1', ->
    it 'returns an object containing the tablr models', ->
      api = Tablr.provideTablrModelsServiceV1()

      expect(api.Table).toEqual(Table)
      expect(api.DisplayTable).toEqual(DisplayTable)
      expect(api.TableEditor).toEqual(TableEditor)
      expect(api.Range).toEqual(Range)
      expect(api.CSVEditor).toEqual(CSVEditor)
