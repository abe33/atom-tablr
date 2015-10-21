
module.exports =
columnName = (index) ->
  if atom.config.get('tablr.defaultColumnNamingMethod') == 'numeric'
    (1+index) + ''
  else if atom.config.get('tablr.defaultColumnNamingMethod') == 'numericZeroBased'
    index + ''
  else
    base = 'A B C D E F G H I J K L M N O P Q R S T U V W X Y Z'.split(' ')

    quotient = Math.floor(index / 26)

    if quotient > 0
      columnName(quotient - 1) + base[index % 26]
    else
      base[index % 26]
