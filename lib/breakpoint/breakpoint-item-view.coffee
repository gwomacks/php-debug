{View} = require 'atom'

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
    console.dir @breakpoint
    @path.append @breakpoint.getPath()
    @line.append @breakpoint.getLine()
