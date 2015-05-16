{View} = require 'atom-space-pen-views'
ContextVariableScalarView = require "./context-variable-scalar-view"


module.exports =
class ContextVariableView extends View
  @content: =>
    @li =>
      @div outlet: 'variableView'

  initialize: (@variable) ->
    @render()

  render: ->
    ContextVariableListView = require "./context-variable-list-view"
    label = @variable.label
    switch @variable.type
      when 'string' then @variableView.append(new ContextVariableScalarView(label, "\""+@variable.value+"\""))
      when 'int'
        @variableView.append(new ContextVariableScalarView(label, @variable.value))
      when 'uninitialized' then @variableView.append(new ContextVariableScalarView(label, "?"))
      when 'null' then @variableView.append(new ContextVariableScalarView(label, "null"))
      when 'array'
        summary ="array["+@variable.value.length+"]"
        @variableView.append(new ContextVariableListView({name: label, summary: summary, variables: @variable.value, autoopen: false}))
      when 'object'
        summary ="object"
        properties = @variable.value
        @variableView.append(new ContextVariableListView({name:label, summary: summary, variables: properties, autoopen: false}))
      else
        console.error "Unhandled variable type: " + @variable.type
