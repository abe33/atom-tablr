vm = require 'vm'
{compile} = require 'coffee-script'
Mixin = require 'mixto'

capitalize = (s) -> s[0].toUpperCase() + s[1..-1]

module.exports =
class Pool extends Mixin
  @pool: (singular, plural) ->
    Singular = capitalize singular
    Plural = capitalize plural

    source =  """
    class #{Plural}Pool extends Mixin
      init#{Plural}Pool: (@#{plural}Class, @#{plural}Container) ->
        @used#{Plural} ?= []
        @unused#{Plural} ?= []

      request#{Singular}: (model) ->
        if @unused#{Plural}.length
          instance = @unused#{Plural}.shift()
        else
          instance = new @#{plural}Class
          @#{plural}Container.appendChild instance

        instance.tableElement = this
        instance.tableEditor = @getModel()
        instance.setModel(model)
        @used#{Plural}.push(instance)

        instance

      release#{Singular}: (instance) ->
        return if instance.isReleased()

        @used#{Plural}.splice(@used#{Plural}.indexOf(instance), 1)
        @unused#{Plural}.push(instance)
        instance.release(false)

      total#{Singular}Count: -> @used#{Plural}.length + @unused#{Plural}.length

      clear#{Plural}: ->
        instance.release(false) for instance in @used#{Plural}
        @used#{Plural} = []
        @unused#{Plural} = []
    """

    sandbox = {Mixin, atom, console}
    context = vm.createContext(sandbox)

    mixin = vm.runInContext(compile(source, bare: true), context, "#{plural}-pool.vm")
    mixin.includeInto(this)
