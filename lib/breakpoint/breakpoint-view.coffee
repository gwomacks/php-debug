{View} = require 'atom-space-pen-views'
BreakpointListView = require './breakpoint-list-view'

module.exports =
class BreakpointView extends View

  @content: =>
    @div =>
      @div outlet: 'breakpointListView'

  initialize: (breakpoints) ->
    @breakpoints = breakpoints
    @render()

  render: ->
    @breakpointListView.append(new BreakpointListView(@breakpoints))
