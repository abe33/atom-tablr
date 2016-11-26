'use strict'

const alphabet = [...'ABCDEFGHIJKLMNOPQRSTUVWXYZ']

const namingStrategies = {
  numeric: (index) => String(index + 1),
  numericZeroBased: (index) => String(index),
  alphabetic: (index) => {
    const quotient = Math.floor(index / 26)

    return quotient > 0
      ? namingStrategies.alphabetic(quotient - 1) + alphabet[index % 26]
      : alphabet[index % 26]
  }
}

module.exports = function columnName (index) {
  const namingMethod = atom.config.get('tablr.defaultColumnNamingMethod')

  return namingStrategies[namingMethod](index)
}
