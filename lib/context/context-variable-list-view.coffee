{View} = require 'atom-space-pen-views'
ContextVariableView = require './context-variable-view'

module.exports =
class ContextVariableListView extends View

  @content: (params) ->
    @li class: "context-variable-list-view", =>
      @details =>
        @summary =>
          @span class: 'variable php', params.name
          @span class: 'type php', params.summary
        @ul outlet: "contextVariableList"

  initialize: ({@variables}) ->
    @render()

  render: ->
    if @autoopen
      @find('details').attr("open", "open")
    if @variables
      for variable in @variables
        @contextVariableList.append(new ContextVariableView(variable))
