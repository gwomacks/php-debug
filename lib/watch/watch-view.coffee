{View} = require 'atom'

module.exports =
class WatchView extends View

  @content: =>
    @div class: 'thing', =>
      @div outlet: 'watchItemView'

  initialize: (watchpoint) ->
    @watchpoint = watchpoint
    @render()

  render: ->
    @watchItemView.append @watchpoint.getExpression()
