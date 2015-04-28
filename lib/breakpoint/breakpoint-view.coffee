{View} = require 'atom'
BreakpointListView = require './breakpoint-list-view'

module.exports =
class BreakpointView extends View

  @content: =>
    @div class: 'thing', =>
      @div outlet: 'breakpointListView'

  initialize: (breakpoints) ->
    @breakpoints = breakpoints
    @render()

  render: ->
    @breakpointListView.append(new BreakpointListView(@breakpoints))
    #@contextListView.append "List View"
