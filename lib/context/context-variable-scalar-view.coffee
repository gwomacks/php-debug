{View} = require 'atom-space-pen-views'
helpers        = require '../helpers'
module.exports =
class ContextVariableScalarView extends View
  @content: (params) =>
    @div =>
      @span class: 'variable php', params.label
      @span class: 'type php', params.value

  # initialize: ({@name, @value}) ->
  #   @render()
  #
  # render: ->
  #   @variableName.append(@name)
  #   @variableValue.append(@value)
