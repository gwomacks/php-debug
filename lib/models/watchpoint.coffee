module.exports =
class Watchpoint
  atom.deserializers.add(this)
  @version: '1b'
  constructor: (data) ->
    if (!data.expression)
      throw new Error("Invalid watchpoint")
    @expression = data.expression.trim()

  serialize: () ->
    return {
      deserializer: 'Watchpoint'
      version: @constructor.version
      data: {
        expression: @getExpression()
      }
    }

  @deserialize: ({data}) ->
    return new Watchpoint(expression: data.expression)

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
    return false if !other instanceof Watchpoint
    return false if other.getExpression() != @getExpression()
    return true

  isGreaterThan: (other) ->
    return !@isLessThan(other) && !@isEqual(other)
