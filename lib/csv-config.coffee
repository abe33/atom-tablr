_ = require 'underscore-plus'

module.exports =
class CSVEditor
  constructor: (@config={}) ->

  get: (path, config) ->
    @config[path]?[config]

  set: (path, config, value) ->
    @config[path] ?= {}
    @config[path][config] = value

  serialize: ->
    _.clone(@config)
