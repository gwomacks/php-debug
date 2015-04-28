{View} = require 'atom'
ContextVariableView = require './context-variable-view'

module.exports =
class ContextVariableListView extends View

  @content: =>
      @ul class: "context-variable-list-view", =>
        @div outlet: "contextVariableList"

  initialize: (variables) ->
    @variables = variables
    console.dir @variables
    console.log "Constructed"
    @render()

  render: ->
    for variable in @variables
      console.log "adding variable"
      @contextVariableList.append(new ContextVariableView(variable))
      #@variableListView.append "moo"
