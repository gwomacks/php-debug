{View} = require 'atom-space-pen-views'
module.exports =
class ContextVariableScalarView extends View
  @content: =>
    @div =>
      @span outlet: "variableName"
      @span outlet: "variableValue"

  initialize: (@name, @value) ->
    @render()

  render: ->
    @variableName.append(@name)
    @variableValue.append(@value)
