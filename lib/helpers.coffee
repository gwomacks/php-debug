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

exports.escapeHtml = (string) ->
  entityMap = {
    "<": "&lt;"
    ">": "&gt;"
  }
  result = String(string).replace /[<>]/g, (s) ->
    return entityMap[s]
  #console.log string,result
  return result

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
    remote = fixPath(pathMap.substring(0,pathMap.indexOf(";")))
    local = fixPath(pathMap.substring(pathMap.indexOf(";")+1))
    if localPath.indexOf(local) == 0
      path = localPath.replace(local, remote)
      if remote.indexOf('/') != null
        # remote path appears to be a unix path, so replace any \'s with /'s'
        path = path.replace(/\\/g, '/')
      else if remote.indexOf('\\') != null
        # This might not work in some cases
        # remote path appears to be a windows path, so replace any /'s with \'s'
        path = path.replace(/\//g, '\\')
      else
        atom.notifications.addError "Oops, looks like php-debug can't determine the remote path's type"
      return path.replace('file://','')
  return localPath.replace('file://','')

exports.remotePathToLocal = (remotePath) ->
  pathMaps = atom.config.get('php-debug.PathMaps')
  remotePath = decodeURI(remotePath)
  for pathMap in pathMaps
    remote = fixPath(pathMap.substring(0,pathMap.indexOf(";")))
    local = fixPath(pathMap.substring(pathMap.indexOf(";")+1))
    if remotePath.indexOf('/') != null && remotePath.indexOf('/') != 0
      #Consider throwing an error instead of modifying invalid input
      #can check with require('path').posix.isAbsolute()
      adjustedPath = '/' + remotePath
      if adjustedPath.indexOf(remote) == 0
        return adjustedPath.replace(remote, local)
        break
    else
      if remotePath.indexOf(remote) == 0
        return remotePath.replace(remote, local)
        break

  return remotePath.replace('file://','')

#Get rid of extra slashes and trailing slashes
#Both of them give us a hard time
fixPath = (path) ->
  modpath = require 'path'
  path = modpath.normalize(path)
  lastChar = path.slice(-1)
  if lastChar == '/' || lastChar == '\\'
    return path.slice(0, path.length - 1)
  return path
