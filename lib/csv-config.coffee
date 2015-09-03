_ = require 'underscore-plus'

module.exports =
class CSVEditor
  constructor: (@config={}) ->

  get: (path, config) ->
    if config? then @config[path]?[config] else @config[path]

  set: (path, config, value) ->
    @config[path] ?= {}
    @config[path][config] = value

  serialize: ->
    _.clone(@config)
