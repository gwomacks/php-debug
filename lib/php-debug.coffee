{CompositeDisposable} = require 'atom'
{Emitter} = require 'event-kit'
{$} = require 'atom-space-pen-views'
events = require 'events'

Codepoint    = require './models/codepoint'
Breakpoint    = require './models/breakpoint'
BreakpointMarker    = require './models/breakpoint-marker'
Watchpoint    = require './models/watchpoint'
GlobalContext = require './models/global-context'
helpers        = require './helpers'
PhpDebugStatusView = require './status/php-debug-status-view'

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
    GutterBreakpointToggle:
      title: "Enable breakpoint markers in the gutter"
      type: 'boolean'
      default: true
      description: "Enable breakpoints to be toggled and displayed via the gutter"
    GutterPosition:
      type: 'string'
      default: "Right"
      description: "Display breakpoint gutter to the left or right of the line numbers"
      enum: ["Left","Right"]
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
        type: 'string'
      description: "Paths in the format of remote;local (eg \"/var/www/project;C:\\projects\\mycode\")"
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
    @subscriptions.add atom.commands.add 'atom-workspace', 'php-debug:breakpointSettings': => @breakpointSettings()
    @subscriptions.add atom.commands.add 'atom-workspace', 'php-debug:toggleDebugging': => @toggleDebugging()
    @subscriptions.add atom.commands.add 'atom-workspace', 'php-debug:addWatch': => @addWatch()
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
      @doCodePoint(breakpoint)

    @GlobalContext.onStackChange (codepoint) =>
      @doCodePoint(codepoint)
    
    @GlobalContext.onSocketError () =>
      @toggleDebugging()

    @GlobalContext.onSessionEnd () =>
      @getUnifiedView().setConnected(false)
      if @currentCodePointDecoration
        @currentCodePointDecoration.destroy()

    @GlobalContext.onRunning () =>
      if @currentCodePointDecoration
        @currentCodePointDecoration.destroy()

    @GlobalContext.onWatchpointsChange () =>
      if @GlobalContext.getCurrentDebugContext()
        @GlobalContext.getCurrentDebugContext().syncCurrentContext(0)

    @GlobalContext.onBreakpointsChange (event) =>
      if @GlobalContext.getCurrentDebugContext()
        if event.removed
          for breakpoint in event.removed
            @GlobalContext.getCurrentDebugContext().executeBreakpointRemove(breakpoint)
            if breakpoint.getMarker()
              breakpoint.getMarker().destroy()
        if event.added
          for breakpoint in event.added
            @GlobalContext.getCurrentDebugContext().executeBreakpoint(breakpoint)
      if event.removed
        for breakpoint in event.removed
          if breakpoint.getMarker()
            breakpoint.getMarker().destroy()
            
    atom.workspace.observeTextEditors (editor) =>
      if (atom.config.get('php-debug.GutterBreakpointToggle'))
        @createGutter editor
      else 
        for breakpoint in @GlobalContext.getBreakpoints()
          if breakpoint.getPath() == editor.getPath()
            marker = @addBreakpointMarker(breakpoint.getLine(), editor)
            breakpoint.setMarker(marker)
            
    atom.config.observe "php-debug.GutterBreakpointToggle", (newValue) =>
      @createGutters newValue    
        
    atom.config.observe "php-debug.GutterPosition", (newValue) =>
      @createGutters atom.config.get('php-debug.GutterBreakpointToggle'),true

    atom.contextMenu.add 'atom-text-editor': [{
        label: 'Add to watch'
        command: 'php-debug:addWatch'
        shouldDisplay: =>
            editor = atom.workspace.getActivePaneItem()
            expression = editor?.getSelectedText()
            if !!expression then return true else return false
      },
      {
        label: 'Breakpoint settings'
        command: 'php-debug:breakpointSettings'
        shouldDisplay: =>
          editor = atom.workspace.getActivePaneItem()
          return false if !editor
          range = editor.getSelectedBufferRange()
          path = editor.getPath()
          line = range.getRows()[0]+1
          for breakpoint in @GlobalContext.getBreakpoints()
            if breakpoint.getPath() == path && breakpoint.getLine() == line
              return true
          return false
      }]

    @GlobalContext.onSessionStart () =>
      @getUnifiedView().setConnected(true)

  consumeStatusBar: (statusBar) ->
    @statusView = new PhpDebugStatusView(statusBar, this)

  getUnifiedView: ->
    unless @unifiedView
      PhpDebugUnifiedView = require './unified/php-debug-unified-view'
      @unifiedView = new PhpDebugUnifiedView(context: @GlobalContext)

    return @unifiedView

  serialize: ->
    @GlobalContext.serialize()

  deactivate: ->
    @unifiedView?.setConnected(false)
    @statusView?.destroy()
    @statusView = null
    @unifiedView?.destroy()
    @subscriptions.dispose()
    @dbgp?.close()

  updateDebugContext: (data) ->
    @contextView.setDebugContext(data)

  doCodePoint: (point) ->
      filepath = point.getPath()

      filepath = helpers.remotePathToLocal(filepath)
      
      atom.workspace.open(filepath,{searchAllPanes: true, activatePane:true}).then (editor) =>
        if @currentCodePointDecoration
          @currentCodePointDecoration.destroy()
        line = point.getLine()
        range = [[line-1, 0], [line-1, 0]]
        marker = editor.markBufferRange(range, {invalidate: 'surround'})

        type = point.getType?() ? 'generic'
        @currentCodePointDecoration = editor.decorateMarker(marker, {type: 'line', class: 'debug-break-'+type})
        editor.scrollToBufferPosition([line-1,0])
      @GlobalContext.getCurrentDebugContext().syncCurrentContext(point.getStackDepth())

  addBreakpointMarker: (line, editor) ->
    gutter = editor.gutterWithName("php-debug-gutter")
    range = [[line-1, 0], [line-1, 0]]
    
    marker = new BreakpointMarker(editor,range,gutter)
    marker.decorate()

    return marker
    

  breakpointSettings: ->
    BreakpointSettingsView = require './breakpoint/breakpoint-settings-view'
    editor = atom.workspace.getActivePaneItem()
    range = editor.getSelectedBufferRange()
    path = editor.getPath()
    line = range.getRows()[0]+1
    breakpoint = null
    for bp in @GlobalContext.getBreakpoints()
      if bp.getPath() == path && bp.getLine() == line
        breakpoint = bp
        break
    @settingsView = new BreakpointSettingsView({breakpoint:breakpoint,context:@GlobalContext})
    @settingsView.attach()
  
  createGutters: (create,recreate) ->
    editors = atom.workspace.getTextEditors()
    for editor in editors
      if editor
        if create == false
          if (editor?.gutterWithName('php-debug-gutter') != null)
            gutter = editor?.gutterWithName('php-debug-gutter')
            gutter?.destroy()
        else
          if recreate
            if (editor?.gutterWithName('php-debug-gutter') != null)
              gutter = editor?.gutterWithName('php-debug-gutter')
              gutter?.destroy()
          if (editor?.gutterWithName('php-debug-gutter') == null)
            @createGutter(editor)
  
  createGutter: (editor) ->
    if (!editor)
      editor = atom.workspace.getActivePaneItem()
    if (!editor)
      return
      
    gutterEnabled = atom.config.get('php-debug.GutterBreakpointToggle')
    if (!gutterEnabled)
      return
      
    gutterPosition = atom.config.get('php-debug.GutterPosition')
    if gutterPosition == "Left"
      priority = -200
    else
      priority = 200
      
    if (editor.gutterWithName('php-debug-gutter') != null)
      @gutter = editor.gutterWithName('php-debug-gutter')
      return
    else
      @gutter = editor?.gutterContainer.addGutter {name:'php-debug-gutter', priority: priority}
    
    view = atom.views.getView editor
    domNode = atom.views.getView @gutter
    $(domNode).unbind 'click.phpDebug'
    $(domNode).bind 'click.phpDebug', (event) =>
      clickedScreenRow = view.component.screenPositionForMouseEvent(event).row
      clickedBufferRow  = editor.bufferRowForScreenRow(clickedScreenRow)+1
      @toggleBreakpoint clickedBufferRow
      
    if @gutter
      for breakpoint in @GlobalContext.getBreakpoints()
        if breakpoint.getPath() == editor.getPath()
          marker = @addBreakpointMarker(breakpoint.getLine(), editor)
          breakpoint.setMarker(marker)

  toggleDebugging: ->
    if @currentCodePointDecoration
      @currentCodePointDecoration.destroy()

    if @settingsView
      @settingsView?.close()
      @settingsView?.destroy()

    if !@getUnifiedView().isVisible()
      @getUnifiedView().setVisible(true)
      @statusView?.setActive(true)
      if !@dbgp.listening()
        if !@dbgp.listen()
          console.log "failed"
          @getUnifiedView().setVisible(false)
          @statusView?.setActive(false)
          return
    
      @createGutter()
      
    else
      @getUnifiedView().setVisible(false)
      @statusView?.setActive(false)
      @dbgp?.close()

  addWatch: ->
    editor = atom.workspace.getActivePaneItem()
    return if !editor || !editor.getSelectedText()
    expression = editor.getSelectedText()
    w = new Watchpoint(expression:expression)
    @GlobalContext.addWatchpoint(w)

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

  toggleBreakpoint: (line) ->
    editor = atom.workspace.getActivePaneItem()
    if !line
      return if !editor || !editor.getSelectedBufferRange
      range = editor.getSelectedBufferRange()
      line = range.getRows()[0]+1
    path = editor.getPath()
    breakpoint = new Breakpoint({filepath:path, line:line})
    removed = @GlobalContext.removeBreakpoint breakpoint
    if removed
      if removed.getMarker()
        removed.getMarker().destroy()
    else
      marker = @addBreakpointMarker(line, editor)
      breakpoint.setMarker(marker)
      @GlobalContext.addBreakpoint breakpoint
