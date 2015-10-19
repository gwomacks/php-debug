{$, View} = require 'atom-space-pen-views'
BreakpointItemView = require './breakpoint-item-view'
helpers        = require '../helpers'

module.exports =
class BreakpointListView extends View

  @content: =>
      @ul class: "breakpoint-list-view", =>
        @div outlet: "breakpointItemList"

  initialize: (breakpoints) ->
    @breakpointItemList.on 'mousedown', 'li', (e) =>
      @selectBreakPoint($(e.target).closest('li'))
      e.preventDefault()
      false

    @breakpointItemList.on 'mouseup', 'li', (e) =>
      e.preventDefault()
      false

    @breakpoints = breakpoints
    @render()

  render: ->
    for breakpoint in @breakpoints
      @breakpointItemList.append(new BreakpointItemView(breakpoint))

  selectBreakPoint: (view) ->
    return unless view.length
    filepath = view.find('.breakpoint-path').data('path')

    filepath = helpers.remotePathToLocal(filepath)

    atom.workspace.open(filepath,{searchAllPanes: true, activatePane:true}).then (editor) =>
      line = view.find('.breakpoint-line').data('line')
      range = [[line-1, 0], [line-1, 0]]
      editor.scrollToBufferPosition([line-1,0])
      editor.setCursorScreenPosition([line-1,0])
