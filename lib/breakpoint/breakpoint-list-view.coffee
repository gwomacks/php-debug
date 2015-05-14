{View} = require 'atom-space-pen-views'
BreakpointItemView = require './breakpoint-item-view'

module.exports =
class BreakpointListView extends View

  @content: =>
      @ul class: "breakpoint-list-view", =>
        @div outlet: "breakpointItemList"

  initialize: (breakpoints) ->
    @breakpoints = breakpoints
    @render()

  render: ->
    for breakpoint in @breakpoints
      @breakpointItemList.append(new BreakpointItemView(breakpoint))
