{View} = require 'atom-space-pen-views'
ContextVariableView = require '../context/context-variable-view'
module.exports =
class WatchView extends View

  @content: ->
    @div class: 'native-key-bindings', =>
      @div outlet: 'variable'

  initialize: (watchpoint) ->
    @watchpoint = watchpoint
    @render()

  render: ->
    datum = @watchpoint.getValue()
    if not datum?
      datum = {
        label : @watchpoint.getExpression()
        type: 'uninitialized'
      }
    @variable.append new ContextVariableView(datum)
