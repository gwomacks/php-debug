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
    switch @variable.type
      when 'string' then @variableView.append(new ContextVariableScalarView(@variable.fullname, "\""+@variable.value+"\""))
      when 'int'
        @variableView.append(new ContextVariableScalarView(@variable.fullname, @variable.value))
      when 'uninitialized' then @variableView.append(new ContextVariableScalarView(@variable.fullname, "?"))
      when 'null' then @variableView.append(new ContextVariableScalarView(@variable.fullname, "null"))
      when 'array'
        summary ="array["+@variable.value.length+"]"
        @variableView.append(new ContextVariableListView({name: @variable.fullname, summary: summary, variables: @variable.value, autoopen: false}))
      when 'object'
        console.dir @variable
        summary ="object"
        name =  @variable.fullname
        properties = @variable.value
        @variableView.append(new ContextVariableListView({name:name, summary: summary, variables: properties, autoopen: false}))
      else
        console.error "Unhandled variable type: " + @variable.type
