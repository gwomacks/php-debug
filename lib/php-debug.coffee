{CompositeDisposable} = require 'atom'
{Emitter} = require 'event-kit'
events = require 'events'

Breakpoint    = require './models/breakpoint'
Watchpoint    = require './models/watchpoint'
GlobalContext = require './models/global-context'
helpers        = require './helpers'

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


module.exports = PhpDebug =
  subscriptions: null

  config:
    CustomExceptions:
      type: 'array'
      default: []
      items:
        type: 'string'
      description: "Custom Exceptions to break on"
    PathMaps:
      type: 'array'
      default: []
      items:
        type: 'object'
        properties:
          from:
            type: 'string'
          to:
            type: 'string'
    ServerPort:
      type: 'integer'
      default: 9000
    MaxChildren:
      type: 'integer'
      default: 32
    MaxData:
      type: 'integer'
      default: 1024
    MaxDepth:
      type: 'integer'
      default: 4
    PhpException:
      type: 'object'
      properties:
        FatalError:
          type: 'boolean'
          default: true
        CatchableFatalError:
          type: 'boolean'
          default: true
        Notice:
          type: 'boolean'
          default: true
        Warning:
          type: 'boolean'
          default: true
        Deprecated:
          type: 'boolean'
          default: true
        StrictStandards:
          type: 'boolean'
          default: true
        ParseError:
          type: 'boolean'
          default: true
        Xdebug:
          type: 'boolean'
          default: true
        UnknownError:
          type: 'boolean'
          default: true

  activate: (state) ->
    if state
      @GlobalContext = atom.deserializers.deserialize(state)

    if !@GlobalContext
      @GlobalContext = new GlobalContext()
    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'php-debug:toggleBreakpoint': => @toggleBreakpoint()
    @subscriptions.add atom.commands.add 'atom-workspace', 'php-debug:toggleDebugging': => @toggleDebugging()
    @subscriptions.add atom.commands.add 'atom-workspace', 'php-debug:run': => @run()
    @subscriptions.add atom.commands.add 'atom-workspace', 'php-debug:stepOver': => @stepOver()
    @subscriptions.add atom.commands.add 'atom-workspace', 'php-debug:stepIn': => @stepIn()
    @subscriptions.add atom.commands.add 'atom-workspace', 'php-debug:stepOut': => @stepOut()
    @subscriptions.add atom.commands.add 'atom-workspace', 'php-debug:clearAllBreakpoints': => @clearAllBreakpoints()
    @subscriptions.add atom.commands.add 'atom-workspace', 'php-debug:clearAllWatchpoints': => @clearAllWatchpoints()
    @subscriptions.add atom.workspace.addOpener (filePath) =>
      switch filePath
        when PhpDebugContextUri
          createContextView(uri: PhpDebugContextUri)
        when PhpDebugBreakpointsUri
          createBreakpointsView(uri: PhpDebugBreakpointsUri)
        when PhpDebugWatchUri
          createWatchView(uri: PhpDebugWatchUri)
        when PhpDebugUnifiedUri
          @createUnifiedView(uri: PhpDebugUnifiedUri, context: @GlobalContext)
    Dbgp = require './engines/dbgp/dbgp'
    @dbgp = new Dbgp(context: @GlobalContext, serverPort: atom.config.get('php-debug.ServerPort'))
    @GlobalContext.onBreak (breakpoint) =>
      @doBreak(breakpoint)

    @GlobalContext.onRunning () =>
      if @currentBreakDecoration
        @currentBreakDecoration.destroy()

    @GlobalContext.onWatchpointsChange () =>
      if @GlobalContext.getCurrentDebugContext()
        @GlobalContext.getCurrentDebugContext().syncCurrentContext()

    @GlobalContext.onBreakpointsChange (event) =>
      if @GlobalContext.getCurrentDebugContext()
        if event.removed
          for breakpoint in event.removed
            @GlobalContext.getCurrentDebugContext().executeBreakpointRemove(breakpoint)
        if event.added
          for breakpoint in event.added
            @GlobalContext.getCurrentDebugContext().executeBreakpoint(breakpoint)
    atom.workspace.observeTextEditors (editor) =>
      for breakpoint in @GlobalContext.getBreakpoints()
        if breakpoint.getPath() == editor.getPath()
          marker = @addBreakpointMarker(breakpoint.getLine(), editor)
          breakpoint.setMarker(marker)

  createUnifiedView: (state) ->
    PhpDebugUnifiedView = require './unified/php-debug-unified-view'
    return new PhpDebugUnifiedView(state)

  serialize: ->
    @GlobalContext.serialize()

  deactivate: ->
    @modalPanel.destroy()
    @subscriptions.dispose()

  updateDebugContext: (data) ->
    @contextView.setDebugContext(data)

  doBreak: (breakpoint) ->
    filepath = breakpoint.getPath()

    filepath = helpers.remotePathToLocal(filepath)

    atom.workspace.open(filepath,{searchAllPanes: true, activatePane:true}).then (editor) =>
      if @currentBreakDecoration
        @currentBreakDecoration.destroy()
      line = breakpoint.getLine()
      range = [[line-1, 0], [line-1, 0]]
      marker = editor.markBufferRange(range, {invalidate: 'surround'})
      type = breakpoint.getType()
      @currentBreakDecoration = editor.decorateMarker(marker, {type: 'line', class: 'debug-break-'+type})
      editor.scrollToBufferPosition([line-1,0])
    @GlobalContext.getCurrentDebugContext().syncCurrentContext()

  addBreakpointMarker: (line, editor) =>
    range = [[line-1, 0], [line-1, 0]]
    marker = editor.markBufferRange(range)
    decoration = editor.decorateMarker(marker, {type: 'line-number', class: 'php-debug-breakpoint'})
    return marker

  toggle: ->
    editor = atom.workspace.getActivePaneItem()
    range = editor.getSelectedBufferRange()
    marker = editor.markBufferRange(range)

  toggleDebugging: ->
    if @currentBreakDecoration
      @currentBreakDecoration.destroy()
    pane = atom.workspace.paneForItem(@unifiedWindow)
    if !pane
      @showWindows()
      if !@dbgp.listening()
        @dbgp.listen()
    else
      pane.destroy()
      delete @unifiedWindow
      @dbgp.close()

  run: ->
    if @GlobalContext.getCurrentDebugContext()
      @GlobalContext.getCurrentDebugContext()
        .executeRun()

  stepOver: ->
    if @GlobalContext.getCurrentDebugContext()
      @GlobalContext.getCurrentDebugContext()
        .continue "step_over"
  stepIn: ->
    if @GlobalContext.getCurrentDebugContext()
      @GlobalContext.getCurrentDebugContext()
        .continue "step_into"
  stepOut: ->
    if @GlobalContext.getCurrentDebugContext()
      @GlobalContext.getCurrentDebugContext()
        .continue "step_out"

  clearAllBreakpoints: ->
    @GlobalContext.setBreakpoints([])

  clearAllWatchpoints: ->
    @GlobalContext.setWatchpoints([])

  showWindows: ->
    editor = atom.workspace.getActivePane()
    editor.splitDown()
    atom.workspace.open(PhpDebugUnifiedUri)
      .then (unifiedWindow) =>
        @unifiedWindow = unifiedWindow

  toggleBreakpoint: ->
    editor = atom.workspace.getActivePaneItem()
    range = editor.getSelectedBufferRange()
    path = editor.getPath()
    breakpoint = new Breakpoint({filepath:path, line:range.getRows()[0]+1})
    removed = @GlobalContext.removeBreakpoint breakpoint
    if removed
      if removed.getMarker()
        removed.getMarker().destroy()
    else
      marker = @addBreakpointMarker(range.getRows()[0]+1, editor)
      breakpoint.setMarker(marker)
      @GlobalContext.addBreakpoint breakpoint
