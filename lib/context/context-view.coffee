{View} = require 'atom'
ContextVariableListView = require './context-variable-list-view'

module.exports =
class ContextView extends View

  @content: =>
    @div class: 'thing', =>
      @div outlet: 'contextListView'

  initialize: (context) ->
    @context = context
    @render()

  render: ->
    @contextListView.append(new ContextVariableListView(@context.context.variables))
    #@contextListView.append "List View"
