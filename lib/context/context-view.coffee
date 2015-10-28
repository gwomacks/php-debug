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

      @contextListView.append(new ContextVariableListView( {name: @context.name, summary: null, variables: @context.context.variables, autoopen: openChildren, openpaths:@autoopen, parent:null}))
