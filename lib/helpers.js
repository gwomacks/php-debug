'use babel'

import path from 'path'
import fastGlob from 'fast-glob'
import os from 'os'

exports.getInsertIndex = function(sortedArray, object) {
  var curObject, index;
  if (sortedArray.length === 0) {
    return 0;
  }
  for (index in sortedArray) {
    curObject = sortedArray[index];
    if (object.isLessThan(curObject)) {
      return index;
    }
  }
  return sortedArray.length;
};

exports.generatePathMaps = function(remoteUri, existingPathMaps, aggregate, reverse) {
  if (existingPathMaps == undefined || existingPathMaps == null) {
    existingPathMaps = []
  }
  var aggregateResults = {};
  let uri = remoteUri;
  uri = decodeURI(uri).replace('file:///','')
  // Try to do the right thing if it's a windows path vs *nix
  if (uri[1].charCodeAt(0) != 58 && uri[0].charCodeAt(0) != 47) {
    uri = "/" + uri;
  }
  let baseName = path.basename(uri)
  let uriParent = path.dirname(uri)
  var uriParts = uriParent.split('/')
  var bestMatchExisting = null
  if (reverse != undefined && reverse != null && reverse === true) {
    let uriParentAlt = uriParent.replace(/\\/g,"/")
    let uriAlt = uri.replace(/\\/g,"/")
    for (let mapping of existingPathMaps) {
      if (mapping.localPath == uriParent || mapping.localPath == uri || mapping.localPath == uriParentAlt || mapping.localPath == uriAlt) {
        if (aggregate == undefined || aggregate == null) {
          return {type:"existing", results:mapping}
        }
        aggregateResults["existing"] = {type:"existing", results:mapping}
        break;
      } else if (mapping.localPath.endsWith("*")) {
        var wildcardPath = mapping.localPath.substring(0, mapping.localPath.length-1);
        if (uriParent.startsWith(wildcardPath) || (uriParent + "/").startsWith(wildcardPath) || uriParentAlt.startsWith(wildcardPath) || (uriParentAlt + "/").startsWith(wildcardPath) ) {
          if (aggregate == undefined || aggregate == null) {
            return {type:"existing", results:{remotePath:mapping.remotePath,localPath:wildcardPath}}
          }
          aggregateResults["existing"] = {type:"existing", results:{remotePath:mapping.remotePath,localPath:wildcardPath}}
          break;
        }
      } else if (uriParent.indexOf(mapping.localPath) == 0 || uriParentAlt.indexOf(mapping.localPath) == 0) {
        if (bestMatchExisting != null && mapping.localPath.length < bestMatchExisting.results.localPath.length) {
          bestMatchExisting = {type:"existing", results:mapping}
        } if (bestMatchExisting == null) {
          bestMatchExisting = {type:"existing", results:mapping}
        }
      }
    }
    if (bestMatchExisting != null) {
      if (aggregate == undefined || aggregate == null) {
        return bestMatchExisting
      }
      aggregateResults["existing"] = bestMatchExisting
    }
    return {type:"list",results:[{remotePath:"",localPath:uriParentAlt}]}
  }


  for (let mapping of existingPathMaps) {
    if (mapping.remotePath == uriParent || mapping.remotePath == uri) {
      if (aggregate == undefined || aggregate == null) {
        return {type:"existing", results:mapping}
      }
      aggregateResults["existing"] = {type:"existing", results:mapping}
      break;
    } else if (mapping.remotePath.endsWith("*")) {
      var wildcardPath = mapping.remotePath.substring(0, mapping.remotePath.length-1);
      if (uriParent.startsWith(wildcardPath) || (uriParent + "/").startsWith(wildcardPath)) {
        if (aggregate == undefined || aggregate == null) {
          return {type:"existing", results:{remotePath:wildcardPath,localPath:mapping.localPath}}
        }
        aggregateResults["existing"] = {type:"existing", results:{remotePath:wildcardPath,localPath:mapping.localPath}}
        break;
      }
    } else if (uriParent.indexOf(mapping.remotePath) == 0) {
      if (bestMatchExisting != null && mapping.remotePath.length < bestMatchExisting.results.remotePath.length) {
        bestMatchExisting = {type:"existing", results:mapping}
      } if (bestMatchExisting == null) {
        bestMatchExisting = {type:"existing", results:mapping}
      }
    }
  }
  if (bestMatchExisting != null) {
    if (aggregate == undefined || aggregate == null) {
      return bestMatchExisting
    }
    aggregateResults["existing"] = bestMatchExisting
  }

  let projectDirs = atom.project.rootDirectories
  let possibleMatches = []
  let rankedListing = []
  let matchedFiles = []
  if (atom.config.get('php-debug.xdebug.projectScan') === true || atom.config.get('php-debug.xdebug.projectScan') === 1) {
    for (let project of projectDirs) {
      if (project.realPath != undefined && project.realPath != null) {
        const joined = path.join(project.realPath,'/**/',baseName)
        const normal = [path.normalize(joined).replace(/\\/gi,'/')]
        const ignorePaths = atom.config.get('php-debug.pathMapsSearchIgnore')
        const globSearch = normal.concat(ignorePaths);
        const files = fastGlob.sync(globSearch);
        matchedFiles = matchedFiles.concat(files)
      }
    }
  }

  for (let possible of matchedFiles) {
    // Direct match
    if (possible == uri) {
      possible = path.dirname(possible);
      if (aggregate == undefined || aggregate == null) {

        return {type:"direct", results:{remotePath:possible,localPath:possible}}
      }
      //aggregateResults["direct"] = {type:"direct", results:{remotePath:possible,localPath:possible}}
      rankedListing.push({remotePath:possible,localPath:possible});
    } else {
      // Traverse up the tree until the paths diverge, use as possible

      let pathParent = path.dirname(possible)

      var pathParts = pathParent.split('/')
      var uriIdx = uriParts.length - 1
      var pathIdx = pathParts.length - 1
      var nextUriBase = uriParts[uriIdx]
      var nextPathBase = pathParts[pathIdx]
      var matches = -1
      while (nextUriBase == nextPathBase && uriIdx >= 0 && pathIdx >= 0) {
        uriIdx--
        pathIdx--
        nextUriBase = uriParts[uriIdx]
        nextPathBase = pathParts[pathIdx]
        matches++
      }
      if (matches == -1) {
        possibleMatches.push({slices: 0, remote:uriParts,local:pathParts})
      } else {
        possibleMatches.push({slices:matches, remote:uriParts,local:pathParts})
      }
    }
  }
  for (let listing of possibleMatches) {
    for (let x = listing.slices; x >= 0; x--) {
      let remoteParts = listing.remote.slice(0, listing.remote.length-x)
      let localParts = listing.local.slice(0, listing.local.length-x)
      rankedListing.push({remotePath:remoteParts.join('/'),localPath:localParts.join('/')})
    }
  }
  if (aggregate == undefined || aggregate == null) {
    if (rankedListing.length == 0) {
      rankedListing.push({remotePath:uriParent,localPath:""})
    }
    return {type:"list",results:rankedListing}
  }
  aggregateResults["list"] = {type:"list", results:rankedListing}
  return aggregateResults;
}

exports.createPreventableEvent = function() {
    return {
      preventDefault : function(promise) {
      	this._defaultPrevented = true;
        this._promise = promise;
      },
      isDefaultPrevented : function() {
      	return this._defaultPrevented == true;
      },
      getPromise : function() {
        return this._promise
      }
    };
}

exports.insertOrdered = function(sortedArray, object) {
  var index;
  index = exports.getInsertIndex(sortedArray, object);
  return sortedArray.splice(index, 0, object);
};

exports.escapeValue = function(object) {
  if (typeof object === "string") {
    return "\"" + object.replace("\\", "\\\\").replace("\"", "\\\"") + "\"";
  }
  return object;
};

exports.escapeHtml = function(string) {
  var entityMap, result;
  entityMap = {
    "<": "&lt;",
    ">": "&gt;"
  };
  result = String(string).replace(/[<>]/g, function(s) {
    return entityMap[s];
  });
  return result;
};

exports.arraySearch = function(array, object) {
  var curObject, index;
  if (array.length === 0) {
    return false;
  }
  for (index in array) {
    curObject = array[index];
    if (object.isEqual(curObject)) {
      return index;
    }
  }
  return false;
};

exports.arrayRemove = function(array, object) {
  var index, removed;
  index = exports.arraySearch(array, object);
  if (index === false) {
    return;
  }
  removed = array.splice(index, 1);
  if (removed.length > 0) {
    return removed[0];
  }
};

exports.serializeArray = function(array) {
  var curObject, index, object, ret;
  ret = [];
  for (index in array) {
    curObject = array[index];
    object = curObject.serialize();
    if (object === void 0) {
      continue;
    }
    ret.push(object);
  }
  return ret;
};

exports.shallowEqual = function(oldProps, newProps) {
  var newKeys, oldKeys;
  newKeys = Object.keys(newProps).sort();
  oldKeys = Object.keys(oldProps).sort();
  if (!newKeys.every((function(_this) {
    return function(key) {
      return oldKeys.includes(key);
    };
  })(this))) {
    return false;
  }
  return newKeys.every((function(_this) {
    return function(key) {
      return newProps[key] === oldProps[key];
    };
  })(this));
};

exports.deserializeArray = function(array) {
  var curObject, error, index, object, ret;
  ret = [];
  for (index in array) {
    curObject = array[index];
    try {
      object = atom.deserializers.deserialize(curObject);
      if (object === void 0) {
        continue;
      }
      ret.push(object);
    } catch (_error) {
      error = _error;
      console.error("Could not deserialize object");
      console.dir(curObject);
    }
  }
  return ret;
};

exports.hasLocalPathMap = function(localPath, pathMaps) {
  if (!Array.isArray(pathMaps)) {
    pathMaps = [pathMaps];
  }
  for (let pathMap of pathMaps) {
    if (pathMap == undefined || pathMap == null || !pathMap.hasOwnProperty('localPath') || !pathMap.hasOwnProperty('remotePath') ) {
      return false;
    }
    localPath = localPath.replace(/\\/g, '/');
    let mapLocal = path.posix.normalize(pathMap.localPath.replace(/\\/g, '/'));
    localPath = path.posix.normalize(localPath.replace('file://',''))
    if (localPath.startsWith(mapLocal)) {
      return true;
    }
  }
  return false;
}
exports.hasRemotePathMap = function(remotePath, pathMaps) {
  if (!Array.isArray(pathMaps)) {
    pathMaps = [pathMaps];
  }
  for (let pathMap of pathMaps) {
    if (pathMap == undefined || pathMap == null || !pathMap.hasOwnProperty('localPath') || !pathMap.hasOwnProperty('remotePath') ) {
      return false;
    }
    remotePath = path.posix.normalize(remotePath.replace(/\//g, '/').replace("file://",''));
    let mapRemote = path.posix.normalize(pathMap.remotePath.replace(/\//g, '/'));
    if (remotePath.startsWith(mapRemote)) {
      return true;
    }
  }
  return false;
}

exports.localPathToRemote = function(localPath, pathMaps) {
  if (!Array.isArray(pathMaps)) {
    pathMaps = [pathMaps];
  }
  for (let pathMap of pathMaps) {
    if (pathMap == undefined || pathMap == null || !pathMap.hasOwnProperty('localPath') || !pathMap.hasOwnProperty('remotePath') ) {
      if (localPath.indexOf('/') !== 0) {
        localPath = '/' + localPath
      }
      if (localPath.indexOf('file://') !== 0) {
        return 'file://' + localPath
      }
      return localPath
    }
    // Unify to unix line seperators
    localPath = localPath.replace(/\\/g, '/');
    let mapLocal = path.posix.normalize(pathMap.localPath.replace(/\\/g, '/'));
    localPath = path.posix.normalize(localPath.replace('file://',''))
    if (!localPath.startsWith(mapLocal)) {
      continue;
    }
    let resultPath = localPath.replace(mapLocal, path.posix.normalize(pathMap.remotePath));
    if (resultPath.indexOf('/') !== 0) {
      resultPath = '/' + resultPath
    }
    if (resultPath.indexOf('file://') !== 0) {
      return 'file://' + resultPath
    }
    return resultPath
  }
  if (localPath.indexOf('/') !== 0) {
    localPath = '/' + localPath
  }
  if (localPath.indexOf('file://') !== 0) {
    return 'file://' + localPath
  }
};

exports.remotePathToLocal = function(remotePath, pathMaps) {
  if (!Array.isArray(pathMaps)) {
    pathMaps = [pathMaps];
  }
  for (let pathMap of pathMaps) {
    if (pathMap == undefined || pathMap == null || !pathMap.hasOwnProperty('localPath') || !pathMap.hasOwnProperty('remotePath')) {
      return remotePath.replace("file://",'');
    }
    remotePath = path.posix.normalize(remotePath.replace(/\//g, '/').replace("file://",''));
    let mapRemote = path.posix.normalize(pathMap.remotePath.replace(/\//g, '/'));
    if (!remotePath.startsWith(mapRemote) && !remotePath.substring(1).startsWith(mapRemote)) {
      if (!remotePath.startsWith(mapRemote.replace(/\\/g, '/')) && !remotePath.substring(1).startsWith(mapRemote.replace(/\\/g, '/'))) {
        continue;
      } else {
        mapRemote = mapRemote.replace(/\\/g, '/');
      }
    }
    let resultPath = remotePath.replace(mapRemote, path.posix.normalize(pathMap.localPath));
    if (os.type() == "Windows_NT") {
      resultPath = resultPath.replace(/\//g, '\\')
      if (resultPath.indexOf('\\') === 0) {
        resultPath = resultPath.substring(1)
      }
    }
    return resultPath
  }
  return remotePath.replace("file://",'');
};
