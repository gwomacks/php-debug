{View} = require 'atom-space-pen-views'

module.exports =
class WatchView extends View

  @content: =>
    @div class: 'thing', =>
      @div outlet: 'expression'
      @div outlet: 'value'

  initialize: (watchpoint) ->
    @watchpoint = watchpoint
    @render()

  render: ->
    @expression.append @watchpoint.getExpression()
    @value.append @watchpoint.getValue()
