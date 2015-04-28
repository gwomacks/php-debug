{View} = require 'atom'
ContextVariableListView = require './context-variable-list-view'

module.exports =
class ContextView extends View

  @content: =>
    @div class: 'thing', =>
      @div outlet: 'contextListView'

  initialize: (context) ->
    @context = context
    console.dir @context
    console.log "Constructed"
    @render()

  render: ->
    console.dir @context
    console.log "rendering"
    @contextListView.append(new ContextVariableListView(@context.context.variables))
    #@contextListView.append "List View"
