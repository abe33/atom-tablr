require './helpers/spec-helper'

Range = require '../lib/range'

describe "Range", ->
  it 'rearranges the start and end values', ->
    expect(new Range([-1,  2], [ 3, -4])).toEqual([[-1, -4], [3,2]])

  describe "::intersectsWith(other, [exclusive])", ->
    intersectsWith = (range1, range2, exclusive) ->
      range1 = Range.fromObject(range1)
      range2 = Range.fromObject(range2)
      range1.intersectsWith(range2, exclusive)

    describe "when the exclusive argument is false (the default)", ->
      it "returns true if the ranges intersect, exclusive of their endpoints", ->
        expect(intersectsWith([[1, 2], [3, 4]], [[1, 0], [1, 1]])).toBe false
        expect(intersectsWith([[1, 2], [3, 4]], [[1, 5], [2, 7]])).toBe false
        expect(intersectsWith([[1, 2], [3, 4]], [[1, 0], [2, 2]])).toBe true
        expect(intersectsWith([[1, 2], [3, 4]], [[1, 3], [2, 7]])).toBe true

    describe "when the exclusive argument is true", ->
      it "returns true if the ranges intersect, exclusive of their endpoints", ->
        expect(intersectsWith([[1, 2], [3, 4]], [[1, 0], [1, 1]], true)).toBe false
        expect(intersectsWith([[1, 2], [3, 4]], [[1, 0], [1, 2]], true)).toBe false

  describe "::containsRange(other, [exclusive])", ->
    contains = (range1, range2, exclusive) ->
      range1 = Range.fromObject(range1)
      range2 = Range.fromObject(range2)
      range1.containsRange(range2, exclusive)

    it "returns true when the range is contained", ->
      expect(contains([[0,0],[1,1]], [[0,0],[1,1]])).toBe true
      expect(contains([[0,0],[2,2]], [[0,0],[1,1]])).toBe true
      expect(contains([[0,0],[2,2]], [[1,1],[3,3]])).toBe false
      expect(contains([[0,0],[2,2]], [[2,2],[3,3]])).toBe false

  describe "::negate()", ->
    it "should negate the start and end points", ->
      expect(new Range([ 0,  0], [ 0,  0]).negate().toString()).toBe "[(0, 0) - (0, 0)]"
      expect(new Range([ 1,  2], [ 3,  4]).negate().toString()).toBe "[(-3, -4) - (-1, -2)]"
      expect(new Range([-1, -2], [-3, -4]).negate().toString()).toBe "[(1, 2) - (3, 4)]"
      expect(new Range([-1,  2], [ 3, -4]).negate().toString()).toBe "[(-3, -2) - (1, 4)]"
