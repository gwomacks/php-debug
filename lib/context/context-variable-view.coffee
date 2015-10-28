{View} = require 'atom-space-pen-views'
ContextVariableScalarView = require "./context-variable-scalar-view"


module.exports =
class ContextVariableView extends View
  @content: =>
    @li class: 'native-key-bindings', =>
      @div class: 'native-key-bindings', tabindex: -1, outlet: 'variableView'

  initialize: (@variable) ->
    @render()

  renderScalar: ({label,value}) ->
    "<span class=\"variable php\">#{label}</span><span class=\"type php\">#{value}</span>"

  render: ->
    ContextVariableListView = require "./context-variable-list-view"
    label = @variable.label
    switch @variable.type
      when 'string'
        @variableView.append(@renderScalar({label:label, value: "\""+@variable.value+"\""}))
      when 'numeric'
        @variableView.append(@renderScalar({label: label, value:@variable.value}))
      when 'bool'
        @variableView.append(@renderScalar({label: label, value:@variable.value}))
      when 'uninitialized'
        @variableView.append(@renderScalar({label:label, value:"?"}))
      when 'error'
          @variableView.append(@renderScalar({label:label, value:@variable.value}))
      when 'null'
        @variableView.append(@renderScalar({label: label, value: "null"}))
      when 'array'
        summary ="array["+@variable.length+"]"
        @variableView.append(new ContextVariableListView({name: label, summary: summary, variables: @variable.value, autoopen: false}))
      when 'object'
        summary ="object"
        properties = @variable.value
        @variableView.append(new ContextVariableListView({name:label, summary: summary, variables: properties, autoopen: false}))
      else
        console.error "Unhandled variable type: " + @variable.type
