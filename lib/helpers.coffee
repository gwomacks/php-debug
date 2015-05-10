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

exports.serializeArray = (array) ->
  ret = []
  for index, curObject of array
    object = curObject.serialize()
    if object == undefined
      continue
    ret.push object
  return ret

exports.deserializeArray = (array) ->
  ret = []
  for index, curObject of array
    try
      object =  atom.deserializers.deserialize(curObject)
      if object == undefined
        continue
      ret.push object
    catch error
      console.error "Could not deserialize object"
      console.dir curObject
  return ret
