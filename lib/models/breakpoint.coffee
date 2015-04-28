module.exports =
class Breakpoint
  constructor: (path, marker) ->
    @path = path
    @marker = marker

  getPath: ->
    return @path

  getMarker: ->
    return @marker

  getLine: ->
    return @marker.getStartBufferPosition().row + 1

  isLessThan: (other) ->
    return true if !other instanceof Breakpoint
    return true if other.getPath() < @getPath()
    return true if other.getLine() < @getLine()

  isEqual: (other) ->
    return false if !other instanceof Breakpoint
    return false if other.getPath() != @getPath()
    return false if other.getLine() != @getLine()
    return true
    
  isGreaterThan: (other) ->
    return !@isLessThan(other) && !@isEqual(other)
