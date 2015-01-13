vm = require 'vm'
{compile} = require 'coffee-script'
Mixin = require 'mixto'

capitalize = (s) -> s[0].toUpperCase() + s[1..-1]

AxisMixin = ({axis, dimension, offset, singular, plural}) ->
  Dimension = capitalize dimension
  Singular = capitalize singular
  Offset = capitalize offset
  Plural = capitalize plural
  Axis = capitalize axis

  mixinSource =  """
  class #{Plural}Axis extends Mixin
    isActive#{Singular}: (#{singular}) ->
      @activeCellPosition.#{singular} is #{singular}

    isSelected#{Singular}: (#{singular}) ->
      @selection.start.#{singular} <= #{singular} <= @selection.end.#{singular}

    get#{Singular}#{Dimension}: ->
      @#{singular}#{Dimension} ? @config#{Singular}#{Dimension}

    getMinimum#{Singular}#{Dimension}: ->
      @minimum#{Singular}#{Dimension} ? @configMinimum#{Singular}#{Dimension}

    set#{Singular}#{Dimension}: (@#{singular}#{Dimension}) ->
      @compute#{Singular}Offsets()
      @requestUpdate()

    get#{Singular}#{Dimension}At: (index) ->
      @table.get#{Singular}(index)?.#{dimension} ? @get#{Singular}#{Dimension}()

    set#{Singular}#{Dimension}At: (index, #{dimension}) ->
      min#{Dimension} = @getMinimum#{Singular}#{Dimension}()
      #{dimension} = min#{Dimension} if #{dimension} < min#{Dimension}
      @table.get#{Singular}(index)?.#{dimension} = #{dimension}

    get#{Singular}OffsetAt: (index) -> @getScreen#{Singular}OffsetAt(@model#{Singular}ToScreen#{Singular}(index))

    get#{Singular}Overdraw: -> @#{singular}Overdraw ? @config#{Singular}Overdraw

    set#{Singular}Overdraw: (@#{singular}Overdraw) -> @requestUpdate()

    getLast#{Singular}: -> @table.get#{Plural}Count() - 1

    getFirstVisible#{Singular}: ->
      @find#{Singular}AtPosition(@body.scroll#{Offset})

    getLastVisible#{Singular}: ->
      scrollView#{Dimension} = @body.client#{Dimension}

      @find#{Singular}AtPosition(@body.scroll#{Offset} + scrollView#{Dimension}) ? @table.get#{Plural}Count() - 1

    getScreen#{Plural}: -> @screen#{Plural}

    getScreen#{Singular}: (#{singular}) ->
      @table.get#{Singular}(@screen#{Singular}ToModel#{Singular}(#{singular}))

    getScreen#{Singular}#{Dimension}At: (#{singular}) ->
      @get#{Singular}#{Dimension}At(@screen#{Singular}ToModel#{Singular}(#{singular}))

    setScreen#{Singular}#{Dimension}At: (#{singular}, #{dimension}) ->
      @set#{Singular}#{Dimension}At(@screen#{Singular}ToModel#{Singular}(#{singular}), #{dimension})

    getScreen#{Singular}OffsetAt: (#{singular}) ->
      @#{singular}Offsets[#{singular}]

    deleteActive#{Singular}: ->
      confirmation = atom.confirm
        message: 'Are you sure you want to delete the current active #{singular}?'
        detailedMessage: "You are deleting the #{singular} #\#{@activeCellPosition.#{singular} + 1}."
        buttons: ['Delete #{Singular}', 'Cancel']

      @table.remove#{Singular}At(@activeCellPosition.#{singular}) if confirmation is 0

    screen#{Singular}ToModel#{Singular}: (#{singular}) -> @screenToModel#{Plural}Map[#{singular}]

    model#{Singular}ToScreen#{Singular}: (#{singular}) -> @modelToScreen#{Plural}Map[#{singular}]

    make#{Singular}Visible: (#{singular}) ->
      #{singular}#{Dimension} = @getScreen#{Singular}#{Dimension}At(#{singular})
      scrollView#{Dimension} = @body.offset#{Dimension}
      currentScroll#{Offset} = @body.scroll#{Offset}

      #{singular}Offset = @getScreen#{Singular}OffsetAt(#{singular})

      scroll#{Offset}AsFirstVisible#{Singular} = #{singular}Offset
      scroll#{Offset}AsLastVisible#{Singular} = #{singular}Offset - (scrollView#{Dimension} - #{singular}#{Dimension})

      return if scroll#{Offset}AsFirstVisible#{Singular} >= currentScroll#{Offset} and
                scroll#{Offset}AsFirstVisible#{Singular} + #{singular}#{Dimension} <= currentScroll#{Offset} + scrollView#{Dimension}

      if #{singular}Offset > currentScroll#{Offset}
        @body.scroll#{Offset} = scroll#{Offset}AsLastVisible#{Singular}
      else
        @body.scroll#{Offset} = scroll#{Offset}AsFirstVisible#{Singular}

    compute#{Singular}Offsets: ->
      offsets = []
      offset = 0

      for i in [0...@table.get#{Plural}Count()]
        offsets.push offset
        offset += @getScreen#{Singular}#{Dimension}At(i)

      @#{singular}Offsets = offsets

    #{singular}ScreenPosition: (#{singular}) ->
      #{offset} = @getScreen#{Singular}OffsetAt(#{singular})

      content = @get#{Plural}Container()
      contentOffset = content.getBoundingClientRect()

      #{offset} + contentOffset.#{offset}

    find#{Singular}AtPosition: (#{axis}) ->
      for i in [0...@table.get#{Plural}Count()]
        offset = @getScreen#{Singular}OffsetAt(i)
        return i - 1 if #{axis} < offset

      return @table.get#{Plural}Count() - 1

    find#{Singular}AtScreenPosition: (#{axis}) ->
      content = @get#{Plural}Container()

      bodyOffset = content.getBoundingClientRect()

      #{axis} -= bodyOffset.#{offset}

      @find#{Singular}AtPosition(#{axis})

    updateScreen#{Plural}: ->
      #{plural} = @table.get#{Plural}()
      @screen#{Plural} = #{plural}.concat()
      @screen#{Plural}.sort(@compare#{Plural}(@order, @direction)) if @order?
      @screenToModel#{Plural}Map = (#{plural}.indexOf(#{singular}) for #{singular} in @screen#{Plural})
      @modelToScreen#{Plural}Map = (@screen#{Plural}.indexOf(#{singular}) for #{singular} in #{plural})
      @compute#{Singular}Offsets()

    compare#{Plural}: (order, direction) -> (a,b) ->
      a = a[order]
      b = b[order]
      if a > b
        direction
      else if a < b
        -direction
      else
        0
  """

  sandbox = {Mixin, atom}
  context = vm.createContext(sandbox)

  vm.runInContext(compile(mixinSource, bare: true), context, "axis-#{axis}.vm")

module.exports =
class Axis extends Mixin
  @axis: (axis, dimension, offset, singular, plural, ext={}) ->
    mixin = AxisMixin({axis, dimension, offset, singular, plural})
    mixin[key] = value for key,value of ext

    console.log mixin
    mixin.includeInto(this)
