module.exports =
class Codepoint

  constructor: ({@filepath, @marker, @line, @stackdepth}) ->
    if @marker
      @syncLineFromMarker()
    if !@stackdepth
      @stackdepth = -1

  getPath: ->
    return @filepath

  getMarker: ->
    return @marker

  getStackDepth: ->
    return @stackdepth

  setMarker: (marker) ->
    if @marker
      @marker.destroy()
    @marker = marker
    undefined

  syncLineFromMarker: () ->
    @line = @marker.getStartBufferPosition().row + 1

  getLine: ->
    if @marker
      return @marker.getStartBufferPosition().row + 1
    return @line

  isLessThan: (other) ->
    return true if !other instanceof Codepoint
    return true if other.getPath() < @getPath()
    return true if other.getLine() < @getLine()

  isEqual: (other) ->
    return false if !other instanceof Codepoint
    return false if other.getPath() != @getPath()
    return false if other.getLine() != @getLine()
    return true

  isGreaterThan: (other) ->
    return !@isLessThan(other) && !@isEqual(other)

  @fromMarker: (marker) ->
