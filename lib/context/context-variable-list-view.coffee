{View} = require 'atom-space-pen-views'
ContextVariableView = require './context-variable-view'
helpers        = require '../helpers'

module.exports =
class ContextVariableListView extends View

  @content: (params) ->
    dataname = if params.name then params.name else ''
    dataname = if !!params.parent then params.parent + '.' + dataname else dataname
    @li class: "context-variable-list-view", =>
      @details 'data-name': dataname, =>
        @summary =>
          @span class: 'variable php', params.name
          @span class: 'type php', params.summary
        @ul outlet: "contextVariableList"

  initialize: ({@variables,@autoopen,@parent,@name,@openpaths}) ->
    @render()

  render: ->
    path = if !!@parent then @parent + '.' + @name else @name
    if @autoopen
      @find('details').attr("open", "open")
    if @variables
      for variable in @variables
        @contextVariableList.append(new ContextVariableView({variable:variable, parent: path,openpaths:@openpaths}))

    
