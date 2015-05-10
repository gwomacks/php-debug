exports.getInsertIndex =  (sortedArray, object) ->
  if sortedArray.length == 0
    return 0
  for index, curObject of sortedArray
    if object.isLessThan curObject
      return index
  return sortedArray.length

exports.insertOrdered = (sortedArray, object) ->
  index = exports.getInsertIndex(sortedArray, object)
  sortedArray.splice(index, 0, object)
