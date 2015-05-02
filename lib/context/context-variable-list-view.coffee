{View} = require 'atom-space-pen-views'
ContextVariableView = require './context-variable-view'

module.exports =
class ContextVariableListView extends View

  @content: =>
    @li class: "context-variable-list-view", =>
      @details =>
        @summary =>
          @span outlet: "listName"
          @span outlet: "listSummary"
        @ul outlet: "contextVariableList"



  initialize: (@name, @summary, @variables) ->
    console.dir @name
    console.dir @summary
    console.dir @variables
    @render()

  render: ->
    @listName.append(@name)
    @listSummary.append(@summary)
    for variable in @variables
      @contextVariableList.append(new ContextVariableView(variable))
