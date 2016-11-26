'use strict'

const {Point} = require('atom')
const range = (l, r) =>
  !isNaN(l) && !isNaN(r) ? new Array(r - l).fill().map((x, i) => l + i) : []

module.exports = class Range {
  static fromObject (object, copy) {
    if (Array.isArray(object)) {
      return new this(object[0], object[1])
    } else if (object instanceof this) {
      if (copy) { return object.copy() } else { return object }
    } else {
      return new this(object.start, object.end)
    }
  }

  static fromPointWithDelta (startPoint, rowDelta, columnDelta) {
    startPoint = Point.fromObject(startPoint)
    let endPoint = new Point(startPoint.row + rowDelta, startPoint.column + columnDelta)
    return new this(startPoint, endPoint)
  }

  static deserialize (array) {
    return Array.isArray(array)
      ? new this(array[0], array[1])
      : new this()
  }

  constructor (pointA = new Point(0, 0), pointB = new Point(0, 0)) {
    pointA = Point.fromObject(pointA)
    pointB = Point.fromObject(pointB)

    this.start = new Point(
      Math.min(pointA.row, pointB.row),
      Math.min(pointA.column, pointB.column)
    )
    this.end = new Point(
      Math.max(pointA.row, pointB.row),
      Math.max(pointA.column, pointB.column)
    )
  }

  each (block) {
    range(this.start.row, this.end.row).forEach(row => {
      range(this.start.column, this.end.column).forEach(column => {
        block(row, column)
      })
    })
  }

  map (block) {
    return range(this.start.row, this.end.row).map(row =>
      range(this.start.column, this.end.column).map(column =>
        block(row, column)
      )
    )
  }

  copy () {
    return new Range(this.start.copy(), this.end.copy())
  }

  negate () {
    return new Range(this.start.negate(), this.end.negate())
  }

  bounds () {
    return {
      top: this.start.row,
      left: this.start.column,
      bottom: this.end.row,
      right: this.end.column
    }
  }

  serialize () { return [this.start.serialize(), this.end.serialize()] }

  isEmpty () { return this.start.isEqual(this.end) }

  spanMoreThanOneCell () {
    return this.getRowCount() > 1 || this.getColumnCount() > 1
  }

  getRowCount () {
    return this.end.row - this.start.row
  }

  getRows () {
    return range(this.start.row, this.end.row)
  }

  getColumnCount () {
    return this.end.column - this.start.column
  }

  getColumns () {
    return range(this.start.column, this.end.column)
  }

  freeze () {
    this.start.freeze()
    this.end.freeze()
    return Object.freeze(this)
  }

  union (otherRange) {
    const start = this.start.isLessThan(otherRange.start)
      ? this.start
      : otherRange.start
    const end = this.end.isGreaterThan(otherRange.end)
      ? this.end
      : otherRange.end
    return new Range(start, end)
  }

  compare (other) {
    other = Range.fromObject(other)
    const value = this.start.compare(other.start)
    return value || other.end.compare(this.end)
  }

  isEqual (other) {
    if (other == null) { return false }
    other = Range.fromObject(other)
    return other.start.isEqual(this.start) && other.end.isEqual(this.end)
  }

  intersectsWith (otherRange, exclusive) {
    let bounds1 = this.bounds()
    let bounds2 = otherRange.bounds()

    if (exclusive) {
      return !(
        bounds1.top >= bounds2.bottom ||
        bounds1.left >= bounds2.right ||
        bounds1.bottom <= bounds2.top ||
        bounds1.right <= bounds2.left
      )
    } else {
      return !(
        bounds1.top > bounds2.bottom ||
        bounds1.left > bounds2.right ||
        bounds1.bottom < bounds2.top ||
        bounds1.right < bounds2.left
      )
    }
  }

  containsRange (otherRange) {
    let {start, end} = Range.fromObject(otherRange)
    return this.containsPoint(start) && this.containsPoint({row: end.row - 1, column: end.column - 1})
  }

  containsPoint (point) {
    point = Point.fromObject(point)

    return this.containsRow(point.row) && this.containsColumn(point.column)
  }

  containsRow (row) { return this.start.row <= row && row < this.end.row }

  containsColumn (column) { return this.start.column <= column && column < this.end.column }

  toString () {
    return `[${this.start} - ${this.end}]`
  }
}
