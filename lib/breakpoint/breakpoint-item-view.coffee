{View} = require 'atom-space-pen-views'

module.exports =
class BreakpointItemView extends View
  @content: =>
    @li class: 'meow', =>
      @div class: 'meow', =>
        @span outlet: 'path'
        @span outlet: 'line'

  initialize: (breakpoint) ->
    @breakpoint = breakpoint
    @render()

  render: ->
    @path.append @breakpoint.getPath()
    @line.append @breakpoint.getLine()
