{$, View} = require 'atom-space-pen-views'
module.exports =
class PhpDebugStatusView extends View
  @content: ->
    @div click: 'toggleDebugging', class: 'php-debug-status-view', =>
      @span class: 'icon icon-bug'
      @text('PHP Debug')

  constructor: (statusBar, @phpDebug) ->
    super
    statusBar.addLeftTile(item: @element, priority: -100)

  toggleDebugging: ->
    @phpDebug.toggleDebugging()

  setActive: (active) ->
    if active
      @element.className = 'php-debug-status-view active'
    else
      @element.className = 'php-debug-status-view'
