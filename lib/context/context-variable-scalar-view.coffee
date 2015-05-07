{View} = require 'atom-space-pen-views'
module.exports =
class ContextVariableScalarView extends View
  @content: =>
    @div =>
      @span class: 'variable php', outlet: "variableName"
      @span class: 'type php', outlet: "variableValue"

  initialize: (@name, @value) ->
    @render()

  render: ->
    @variableName.append(@name)
    @variableValue.append(@value)
