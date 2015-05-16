{View} = require 'atom-space-pen-views'
ContextVariableView = require '../context/context-variable-view'
module.exports =
class WatchView extends View

  @content: =>
    @div class: 'thing', =>
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
    # datum.
    @variable.append new ContextVariableView(datum)
    # @expression.append @watchpoint.getExpression()
    # @value.append @watchpoint.getValue()
