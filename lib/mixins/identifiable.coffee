Mixin = require 'mixto'

module.exports =
class Identifiable extends Mixin
  @lastId: 0

  initID: ->
    @id = ++@constructor.lastId
