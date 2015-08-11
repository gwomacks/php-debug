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

exports.escapeValue = (object) ->
  if (typeof object == "string")
    return "\"" + object.replace("\\","\\\\").replace("\"","\\\"") + "\""
  return object;

exports.arraySearch = (array, object) ->
  if array.length == 0
    return false
  for index, curObject of array
    if object.isEqual curObject
      return index
  return false

exports.arrayRemove = (array, object) ->
  index = exports.arraySearch(array, object)
  if(index == false)
    return
  removed = array.splice(index,1)
  if removed.length > 0
    return removed[0]

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

exports.localPathToRemote = (localPath) ->
  pathMaps = atom.config.get('php-debug.PathMaps')
  for pathMap in pathMaps
    if localPath.indexOf(pathMap.local) == 0
      path = localPath.replace(pathMap.local, pathMap.remote)
      if pathMap.remote.indexOf('/') != null
        # remote path appears to be a unix path, so replace any \'s with /'s'
        path = path.replace(/\\/g, '/')
      else if pathMap.remote.indexOf('\\') != null
        # remote path appears to be a windows path, so replace any /'s with \'s'
        path = path.replace(/\//g, '\\')
      return path
  return localPath.replace('file:///','')

exports.remotePathToLocal = (remotePath) ->
  pathMaps = atom.config.get('php-debug.PathMaps')
  for pathMap in pathMaps
    if remotePath.indexOf(pathMap.remote) == 0
      return remotePath.replace(pathMap.remote, pathMap.local)
      break
  return remotePath.replace('file:///','')
