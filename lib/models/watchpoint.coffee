module.exports =
class Watchpoint
  constructor: (expression) ->
    @expression = expression

  getPath: ->
    return @path

  getExpression: ->
    return @expression

  setValue: (@value) ->
    undefined

  getValue: () ->
    return @value
    
  isLessThan: (other) ->
    return true if !other instanceof Watchpoint
    return true if other.getExpression() < @getExpression()

  isEqual: (other) ->
    return false if !other instanceof Watch
    return false if other.geExpression() != @getExpression()
    return true

  isGreaterThan: (other) ->
    return !@isLessThan(other) && !@isEqual(other)
