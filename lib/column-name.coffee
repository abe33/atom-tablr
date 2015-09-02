
module.exports =
columnName = (index) ->
  base = 'A B C D E F G H I J K L M N O P Q R S T U V W X Y Z'.split(' ')

  quotient = Math.floor(index / 26)

  if quotient > 0
    columnName(quotient - 1) + base[index % 26]
  else
    base[index % 26]
