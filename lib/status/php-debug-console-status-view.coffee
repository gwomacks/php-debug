{$, View} = require 'atom-space-pen-views'
module.exports =
class PhpDebugConsoleStatusView extends View
  @content: ->
    @div click: 'toggleConsole', class: 'php-debug-console-view', =>
      @span class: 'icon icon-terminal'
      @text('PHP Console')


  constructor: (statusBar, @phpDebug) ->
    super
    @tile = statusBar.addLeftTile(item: @element, priority: -99)

  toggleConsole: ->
    @phpDebug.toggleConsole()

  setActive: (active) ->
    if active
      @element.className = 'php-debug-console-view active'
    else
      @element.className = 'php-debug-console-view'

  destroy: ->
    @tile?.destroy?()
