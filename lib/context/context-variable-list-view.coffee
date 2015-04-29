{View} = require 'atom'
ContextVariableView = require './context-variable-view'

module.exports =
class ContextVariableListView extends View

  @content: =>
      @ul class: "context-variable-list-view", =>
        @div outlet: "contextVariableList"

  initialize: (variables) ->
    @variables = variables
    @render()

  render: ->
    for variable in @variables
      @contextVariableList.append(new ContextVariableView(variable))
      #@variableListView.append "moo"
