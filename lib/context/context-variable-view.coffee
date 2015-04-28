{View} = require 'atom'

module.exports =
class ContextVariableView extends View
  @content: =>
    @li class: 'meow', =>
      @div class: 'meow', =>
        @span outlet: 'name'
        @span outlet: 'value'

  initialize: (variable) ->
    @variable = variable
    @render()

  render: ->
    console.log "Rendering variable"
    @name.append @variable.fullname
    switch @variable.type
      when 'string' then @value.append @variable.value
      when 'uninitialized' then @value.append "?"
      when 'array'
        ContextVariableListView = require "./context-variable-list-view"
        @value.append("array("+@variable.value.length+")")
        @value.append(new ContextVariableListView(@variable.value))
        #@value.append "ARRAY"
      else
        console.log "Unhandled variable type: " + @variable.type
