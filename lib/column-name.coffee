
namingMethod=atom.config.get('tablr.defaultColumnNamingMethod')
module.exports =
columnName = (index) ->
  if namingMethod is 'numeric'
    String(1+index)
  else if namingMethod is 'numericZeroBased'
    String(index)
  else
    base = 'A B C D E F G H I J K L M N O P Q R S T U V W X Y Z'.split(' ')

    quotient = Math.floor(index / 26)

    if quotient > 0
      columnName(quotient - 1) + base[index % 26]
    else
      base[index % 26]
