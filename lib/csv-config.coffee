_ = require 'underscore-plus'

module.exports =
class CSVConfig
  constructor: (@config={}) ->

  get: (path, config) ->
    if config? then @config[path]?[config] else @config[path]

  set: (path, config, value) ->
    @config[path] ?= {}
    @config[path][config] = value

  move: (oldPath, newPath) ->
    @config[newPath] = @config[oldPath]
    delete @config[oldPath]

  serialize: ->
    _.clone(@config)
