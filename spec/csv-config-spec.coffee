require './helpers/spec-helper'

CSVConfig = require '../lib/csv-config'

describe 'CSVConfig', ->
  [config] = []

  describe 'created without a state', ->
    beforeEach ->
      config = new CSVConfig

    describe 'setting a config', ->
      beforeEach ->
        config.set '/path/to/file.coffee', 'choice', 'TextEditor'

      it 'stores the value at the given setting path', ->
        expect(config.get '/path/to/file.coffee', 'choice').toEqual('TextEditor')

      describe '::serialize', ->
        it 'returns the config for paths', ->
          expect(config.serialize()).toEqual({
            '/path/to/file.coffee': {
              'choice': 'TextEditor'
            }
          })
