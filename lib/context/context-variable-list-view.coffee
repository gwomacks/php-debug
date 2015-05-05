{View} = require 'atom-space-pen-views'
ContextVariableView = require './context-variable-view'

module.exports =
class ContextVariableListView extends View

  @content: (params) ->
    @li class: "context-variable-list-view", =>
      @details =>
        @summary =>
          @span outlet: "listName"
          @span outlet: "listSummary"
        @ul outlet: "contextVariableList"



  initialize: (params) ->
    @name = params.name
    @summary = params.summary
    @variables = params.variables
    @autoopen = params.autoopen
    @render()

  render: ->
    @listName.append(@name)
    @listSummary.append(@summary)
    console.log "details are: "
    if @autoopen
      @find('details').attr("open", "open")
    for variable in @variables
      @contextVariableList.append(new ContextVariableView(variable))
