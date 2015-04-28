{View} = require 'atom'
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
      console.log breakpoint.getLine()
      @breakpointItemList.append(new BreakpointItemView(breakpoint))
