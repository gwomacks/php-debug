{View} = require 'atom-space-pen-views'
ContextVariableListView = require './context-variable-list-view'

module.exports =
class ContextView extends View

  @content: =>
    @div =>
      @span outlet: 'contextListView'

  initialize: (@context,@autoopen) ->
    @render()

  render: ->
    if @context.context
      openChildren = false
      if @autoopen?
        for open in @autoopen
          if (open.indexOf(@context.name) == 0)
            openChildren = true
            break

      cbDeepNaturalSort = (a,b) ->
        aIsNumeric = /^\d+$/.test(a.name)
        bIsNumeric = /^\d+$/.test(b.name)
        # cannot exist two equal keys, so skip case of returning 0
        if aIsNumeric && bIsNumeric # order numbers
          return if (parseInt(a.name, 10) < parseInt(b.name, 10)) then -1 else 1
        else if !aIsNumeric && !bIsNumeric # order strings
          return if (a.name < b.name) then -1 else 1
        else # string first (same behavior that PHP's `ksort`)
          return if aIsNumeric then 1 else -1

      fnWalkVar = (contextVar) ->
        if Array.isArray(contextVar)
          for item in contextVar
            if Array.isArray(item.value)
              fnWalkVar(item.value)
          contextVar.sort(cbDeepNaturalSort)
      if (atom.config.get('php-debug.SortArray'))
        fnWalkVar(@context.context.variables)
      @contextListView.append(new ContextVariableListView( {name: @context.name, summary: null, variables: @context.context.variables, autoopen: openChildren, openpaths:@autoopen, parent:null}))
