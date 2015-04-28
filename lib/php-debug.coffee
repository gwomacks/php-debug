{CompositeDisposable} = require 'atom'
{Emitter} = require 'event-kit'
events = require 'events'

Breakpoint    = require './models/breakpoint'
GlobalContext = require './models/global-context'

PhpDebugContextUri = "phpdebug://context"
PhpDebugStackUri = "phpdebug://stack"
PhpDebugBreakpointsUri = "phpdebug://breakpoints"
PhpDebugWatchUri = "phpdebug://watch"

createContextView =  (state) ->
  PhpDebugContextView = require './context/php-debug-context-view'
  @contextView = new PhpDebugContextView(state)

createBreakpointsView =  (state) ->
  PhpDebugBreakpointView = require './breakpoint/php-debug-breakpoint-view'
  @breakpointView = new PhpDebugBreakpointView(state)

createWatchView =  (state) ->
  PhpDebugWatchView = require './watch/php-debug-watch-view'
  @watchView = new PhpDebugWatchView(state)

module.exports = PhpDebug =
  subscriptions: null

  activate: (state) ->
    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'php-debug:toggleBreakpoint': => @toggleBreakpoint()
    @subscriptions.add atom.commands.add 'atom-workspace', 'php-debug:toggleDebugging': => @toggleDebugging()
    @subscriptions.add atom.workspace.addOpener (filePath) ->
      switch filePath
        when PhpDebugContextUri
          createContextView(uri: PhpDebugContextUri)
        when PhpDebugBreakpointsUri
          createBreakpointsView(uri: PhpDebugBreakpointsUri)
        when PhpDebugWatchUri
          createWatchView(uri: PhpDebugWatchUri)

    Dbgp = require './engines/dbgp/dbgp'
    @dbgp = new Dbgp()
    @dbgp.onDebugContextChange @updateDebugContext

  deactivate: ->
    @modalPanel.destroy()
    @subscriptions.dispose()

  updateDebugContext: (data) ->
    console.log("Updating view context")
    @contextView.setDebugContext(data)

  toggle: ->
    editor = atom.workspace.getActivePaneItem()
    range = editor.getSelectedBufferRange()
    marker = editor.markBufferRange(range)

  toggleDebugging: ->
    @showWindows()
    @dbgp.listen()

  showWindows: ->
    editor = atom.workspace.getActivePaneItem()
    atom.workspace.open(PhpDebugContextUri)
    atom.workspace.open(PhpDebugBreakpointsUri)
    atom.workspace.open(PhpDebugWatchUri)

  toggleBreakpoint: ->
    editor = atom.workspace.getActivePaneItem()
    range = editor.getSelectedBufferRange()
    marker = editor.markBufferRange(range)
    path = editor.getPath()
    breakpoint = new Breakpoint(path, marker)
    decoration = editor.decorateMarker(marker, {type: 'gutter', class: 'php-debug-breakpoint'})
    GlobalContext.addBreakpoint breakpoint
