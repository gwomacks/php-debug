{CompositeDisposable} = require 'atom'
{Emitter} = require 'event-kit'
events = require 'events'

Breakpoint    = require './models/breakpoint'
GlobalContext = require './models/global-context'

PhpDebugContextUri = "phpdebug://context"
PhpDebugStackUri = "phpdebug://stack"
PhpDebugBreakpointsUri = "phpdebug://breakpoints"
PhpDebugWatchUri = "phpdebug://watch"
PhpDebugUnifiedUri = "phpdebug://unified"

createContextView =  (state) ->
  PhpDebugContextView = require './context/php-debug-context-view'
  @contextView = new PhpDebugContextView(state)

createBreakpointsView =  (state) ->
  PhpDebugBreakpointView = require './breakpoint/php-debug-breakpoint-view'
  @breakpointView = new PhpDebugBreakpointView(state)

createWatchView =  (state) ->
  PhpDebugWatchView = require './watch/php-debug-watch-view'
  @watchView = new PhpDebugWatchView(state)

createUnifiedView =  (state) ->
  PhpDebugUnifiedView = require './unified/php-debug-unified-view'
  return new PhpDebugUnifiedView(state)

module.exports = PhpDebug =
  subscriptions: null

  config:
    PathMaps:
      type: 'array'
      default:
        from: 'meow'
        to: 'poop'
      items:
        type: 'PathMap'
        properties:
          from:
            type: 'string'
          to:
            type: 'string'
    TestArray:
      type: 'array'
      default: []
      items:
        type: 'string'



  activate: (state) ->
    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'php-debug:toggleBreakpoint': => @toggleBreakpoint()
    @subscriptions.add atom.commands.add 'atom-workspace', 'php-debug:toggleDebugging': => @toggleDebugging()
    @subscriptions.add atom.commands.add 'atom-workspace', 'php-debug:run': => @run()
    @subscriptions.add atom.commands.add 'atom-workspace', 'php-debug:stepOver': => @stepOver()
    @subscriptions.add atom.commands.add 'atom-workspace', 'php-debug:stepIn': => @stepIn()
    @subscriptions.add atom.commands.add 'atom-workspace', 'php-debug:stepOut': => @stepOut()
    @subscriptions.add atom.workspace.addOpener (filePath) ->
      switch filePath
        when PhpDebugContextUri
          createContextView(uri: PhpDebugContextUri)
        when PhpDebugBreakpointsUri
          createBreakpointsView(uri: PhpDebugBreakpointsUri)
        when PhpDebugWatchUri
          createWatchView(uri: PhpDebugWatchUri)
        when PhpDebugUnifiedUri
          createUnifiedView(uri: PhpDebugUnifiedUri)
    Dbgp = require './engines/dbgp/dbgp'
    @dbgp = new Dbgp()
    # @dbgp.onDebugContextChange @updateDebugContext
    GlobalContext.onBreak @doBreak

  deactivate: ->
    @modalPanel.destroy()
    @subscriptions.dispose()

  updateDebugContext: (data) ->
    @contextView.setDebugContext(data)

  doBreak: (breakpoint) ->
    console.log "Doing break"
    console.dir breakpoint
    #Workspace.open(breakpoint.getPath(),{searchAllPanes: true, activatePane:true})
    atom.workspace.open("C:/Users/gabriel/Documents/test.php",{searchAllPanes: true, activatePane:true})
    GlobalContext.getCurrentDebugContext().syncCurrentContext()

  toggle: ->
    editor = atom.workspace.getActivePaneItem()
    range = editor.getSelectedBufferRange()
    marker = editor.markBufferRange(range)

  toggleDebugging: ->
    @showWindows()
    @dbgp.listen()

  run: ->
    GlobalContext.getCurrentDebugContext()
      .continue "run"

  stepOver: ->
    GlobalContext.getCurrentDebugContext()
      .continue "step_over"
  stepIn: ->
    GlobalContext.getCurrentDebugContext()
      .continue "step_in"
  stepOut: ->
    GlobalContext.getCurrentDebugContext()
      .continue "step_out"

  showWindows: ->
    editor = atom.workspace.getActivePane()
    # atom.workspace.open(PhpDebugContextUri)
    # atom.workspace.open(PhpDebugBreakpointsUri)
    # atom.workspace.open(PhpDebugWatchUri)
    # atom.workspace.addBottomPanel()
    editor.splitDown()
    atom.workspace.open(PhpDebugUnifiedUri)
    #createUnifiedView().openWindow()

  toggleBreakpoint: ->
    editor = atom.workspace.getActivePaneItem()
    range = editor.getSelectedBufferRange()
    marker = editor.markBufferRange(range)
    path = editor.getPath()
    breakpoint = new Breakpoint(path, marker)
    decoration = editor.decorateMarker(marker, {type: 'line-number', class: 'php-debug-breakpoint'})
    GlobalContext.addBreakpoint breakpoint
