{View} = require 'atom-space-pen-views'
ContextVariableView = require './context-variable-view'
helpers        = require '../helpers'

module.exports =
class ContextVariableListView extends View

  @content: (params) ->
    dataname = if params.name then params.name else ''
    dataname = if !!params.parent then params.parent + '.' + dataname else dataname
    nameIsNumeric = /^\d+$/.test(params.name)
    label = params.name
    if !params.parent # root taxonomy (Locals, etc.)
      labelClass = 'syntax--type'
    else if params.parent.indexOf('.') == -1 # variable
      labelClass = 'syntax--variable'
    else # array key, object property
      labelClass = "syntax--property #{if nameIsNumeric then 'syntax--constant syntax--numeric' else 'syntax--string'}"
      label = '"' + params.name + '"'
    valueClass = switch params.type
      when 'array' then 'syntax--support syntax--function'
      when 'object' then 'syntax--entity syntax--name syntax--type'
      else ''
    @li class: "context-variable-list-view", =>
      @details 'data-name': dataname, =>
        @summary =>
          @span class: "variable php syntax--php #{labelClass}", label
          @span class: "type php syntax--php syntax--#{params.type} #{valueClass}", params.summary
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
