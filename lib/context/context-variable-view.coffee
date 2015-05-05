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
    switch @variable.type
      when 'string' then @variableView.append(new ContextVariableScalarView(@variable.fullname, @variable.value))
      when 'int'
        @variableView.append(new ContextVariableScalarView(@variable.fullname, @variable.value))
      when 'uninitialized' then @variableView.append(new ContextVariableScalarView(@variable.fullname, "?"))
      when 'array'
        ContextVariableListView = require "./context-variable-list-view"
        summary ="array["+@variable.value.length+"]"
        @variableView.append(new ContextVariableListView({name: @variable.fullname, summary: summary, variables: @variable.value, autoopen: false}))
        #@value.append "ARRAY"
      else
        console.log "Unhandled variable type: " + @variable.type
