module.exports =
class Breakpoint
  atom.deserializers.add(this)
  @version: '1a'

  constructor: (data) ->
    @filepath = data.filepath
    @marker = data.marker
    @line = data.line
    if @marker
      @syncLineFromMarker()

  serialize: -> {
    deserializer: 'Breakpoint'
    version: @constructor.version
    data: {
      filepath: @getPath()
      line: @getLine()
    }
  }

  @deserialize: ({data}) ->
    return new Breakpoint(filepath: data.filepath, line: data.line)


  getPath: ->
    return @filepath

  getMarker: ->
    return @marker

  syncLineFromMarker: () ->
    @line = @marker.getStartBufferPosition().row + 1

  getLine: ->
    return @line

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
