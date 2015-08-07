{Point} = require 'atom'

# Public: Represents a region in a table in row/column coordinates.
#
# Every public method that takes a range also accepts a *range-compatible*
# {Array}. This means a 2-element array containing {Point}s or point-compatible
# arrays. So the following are equivalent:
#
# ## Examples
#
# ```coffee
# new Range(new Point(0, 1), new Point(2, 3))
# new Range([0, 1], [2, 3])
# [[0, 1], [2, 3]] # Range compatible array
# ```
module.exports =
class Range
  ###
  Section: Properties
  ###

  # Public: A {Point} representing the start of the {Range}.
  start: null

  # Public: A {Point} representing the end of the {Range}.
  end: null

  ###
  Section: Construction
  ###

  # Public: Convert any range-compatible object to a {Range}.
  #
  # * `object` This can be an object that's already a {Range}, in which case it's
  #   simply returned, or an array containing two {Point}s or point-compatible
  #   arrays.
  # * `copy` An optional boolean indicating whether to force the copying of objects
  #   that are already ranges.˚
  #
  # Returns: A {Range} based on the given object.
  @fromObject: (object, copy) ->
    if Array.isArray(object)
      new this(object[0], object[1])
    else if object instanceof this
      if copy then object.copy() else object
    else
      new this(object.start, object.end)

  # Returns a {Range} that starts at the given point and ends at the
  # start point plus the given row and column deltas.
  #
  # * `startPoint` A {Point} or point-compatible {Array}
  # * `rowDelta` A {Number} indicating how many rows to add to the start point
  #   to get the end point.
  # * `columnDelta` A {Number} indicating how many rows to columns to the start
  #   point to get the end point.
  @fromPointWithDelta: (startPoint, rowDelta, columnDelta) ->
    startPoint = Point.fromObject(startPoint)
    endPoint = new Point(startPoint.row + rowDelta, startPoint.column + columnDelta)
    new this(startPoint, endPoint)

  ###
  Section: Serialization and Deserialization
  ###

  # Public: Call this with the result of {Range::serialize} to construct a new Range.
  #
  # * `array` {Array} of params to pass to the {::constructor}
  @deserialize: (array) ->
    if Array.isArray(array)
      new this(array[0], array[1])
    else
      new this()

  ###
  Section: Construction
  ###

  # Public: Construct a {Range} object
  #
  # * `pointA` {Point} or Point compatible {Array} (default: [0,0])
  # * `pointB` {Point} or Point compatible {Array} (default: [0,0])
  constructor: (pointA = new Point(0, 0), pointB = new Point(0, 0)) ->
    unless this instanceof Range
      return new Range(pointA, pointB)

    pointA = Point.fromObject(pointA)
    pointB = Point.fromObject(pointB)

    @start = new Point(
      Math.min(pointA.row, pointB.row),
      Math.min(pointA.column, pointB.column)
    )
    @end = new Point(
      Math.max(pointA.row, pointB.row),
      Math.max(pointA.column, pointB.column)
    )

  each: (block) ->
    for row in [@start.row...@end.row]
      for column in [@start.column...@end.column]
        block(row, column)

    return

  # Public: Returns a new range with the same start and end positions.
  copy: ->
    new @constructor(@start.copy(), @end.copy())

  # Public: Returns a new range with the start and end positions negated.
  negate: ->
    new @constructor(@start.negate(), @end.negate())

  # Public: Returns an {Object} representing the bounds of the range.
  bounds: ->
    top: @start.row
    left: @start.column
    bottom: @end.row
    right: @end.column

  ###
  Section: Serialization and Deserialization
  ###

  # Public: Returns a plain javascript object representation of the range.
  serialize: ->
    [@start.serialize(), @end.serialize()]

  ###
  Section: Range Details
  ###

  # Public: Is the start position of this range equal to the end position?
  #
  # Returns a {Boolean}.
  isEmpty: ->
    @start.isEqual(@end)

  spanMoreThanOneCell: ->
    @getRowCount() > 1 or @getColumnCount() > 1

  # Public: Get the number of rows in this range.
  #
  # Returns a {Number}.
  getRowCount: ->
    @end.row - @start.row

  # Public: Returns an array of all rows in the range.
  getRows: ->
    [@start.row...@end.row]

  # Public: Get the number of columns in this range.
  #
  # Returns a {Number}.
  getColumnCount: ->
    @end.column - @start.column

  # Public: Returns an array of all columns in the range.
  getColumns: ->
    [@start.column...@end.column]

  ###
  Section: Operations
  ###

  # Public: Freezes the range and its start and end point so it becomes
  # immutable and returns itself.
  #
  # Returns an immutable version of this {Range}
  freeze: ->
    @start.freeze()
    @end.freeze()
    Object.freeze(this)

  # Public: Returns a new range that contains this range and the given range.
  #
  # * `otherRange` A {Range} or range-compatible {Array}
  union: (otherRange) ->
    start = if @start.isLessThan(otherRange.start) then @start else otherRange.start
    end = if @end.isGreaterThan(otherRange.end) then @end else otherRange.end
    new @constructor(start, end)

  ###
  Section: Comparison
  ###

  # Public: Compare two Ranges
  #
  # * `otherRange` A {Range} or range-compatible {Array}.
  #
  # Returns `-1` if this range starts before the argument or contains it.
  # Returns `0` if this range is equivalent to the argument.
  # Returns `1` if this range starts after the argument or is contained by it.
  compare: (other) ->
    other = @constructor.fromObject(other)
    if value = @start.compare(other.start)
      value
    else
      other.end.compare(@end)

  # Public: Returns a {Boolean} indicating whether this range has the same start
  # and end points as the given {Range} or range-compatible {Array}.
  #
  # * `otherRange` A {Range} or range-compatible {Array}.
  isEqual: (other) ->
    return false unless other?
    other = @constructor.fromObject(other)
    other.start.isEqual(@start) and other.end.isEqual(@end)

  # Public: Determines whether this range intersects with the argument.
  #
  # * `otherRange` A {Range} or range-compatible {Array}
  # * `exclusive` (optional) {Boolean} indicating whether to exclude endpoints
  #     when testing for intersection. Defaults to `false`.
  #
  # Returns a {Boolean}.
  intersectsWith: (otherRange, exclusive) ->
    bounds1 = @bounds()
    bounds2 = otherRange.bounds()

    if exclusive
      not (
        bounds1.top >= bounds2.bottom or
        bounds1.left >= bounds2.right or
        bounds1.bottom <= bounds2.top or
        bounds1.right <= bounds2.left
      )
    else
      not (
        bounds1.top > bounds2.bottom or
        bounds1.left > bounds2.right or
        bounds1.bottom < bounds2.top or
        bounds1.right < bounds2.left
      )

  # Public: Returns a {Boolean} indicating whether this range contains the given
  # range.
  #
  # * `otherRange` A {Range} or range-compatible {Array}
  # * `exclusive` A boolean value including that the containment should be exclusive of
  #   endpoints. Defaults to false.
  containsRange: (otherRange) ->
    {start, end} = @constructor.fromObject(otherRange)
    @containsPoint(start) and @containsPoint({row: end.row - 1, column: end.column - 1})

  # Public: Returns a {Boolean} indicating whether this range contains the given
  # point.
  #
  # * `point` A {Point} or point-compatible {Array}
  # * `exclusive` A boolean value including that the containment should be exclusive of
  #   endpoints. Defaults to false.
  containsPoint: (point) ->
    point = Point.fromObject(point)

    @containsRow(point.row) and @containsColumn(point.column)

  containsRow: (row) -> @start.row <= row < @end.row
  containsColumn: (column) -> @start.column <= column < @end.column

  # Public: Returns a string representation of the range.
  toString: ->
    "[#{@start} - #{@end}]"
