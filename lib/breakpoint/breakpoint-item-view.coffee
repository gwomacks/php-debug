{View} = require 'atom-space-pen-views'

module.exports =
class BreakpointItemView extends View
  @content: =>
    @li class: 'meow', =>
      @div class: 'meow', =>
        @span class: 'breakpoint-path', outlet: 'path'
        @span class: 'breakpoint-line', outlet: 'line'

  initialize: (breakpoint) ->
    @breakpoint = breakpoint
    @render()

  render: ->
    @path.append @breakpoint.getPath()
    @line.append '(' + @breakpoint.getLine() + ')'
    @find('.breakpoint-path').data('path', @breakpoint.getPath())
    @find('.breakpoint-line').data('line', @breakpoint.getLine())
