{CompositeDisposable} = require 'atom'
{Emitter} = require 'event-kit'
{$} = require 'atom-space-pen-views'
events = require 'events'
multimatch = require 'multimatch'

Codepoint    = require './models/codepoint'
Breakpoint    = require './models/breakpoint'
BreakpointMarker    = require './models/breakpoint-marker'
Watchpoint    = require './models/watchpoint'
GlobalContext = require './models/global-context'
helpers        = require './helpers'
PhpDebugDebugView = require './status/php-debug-debug-view'
PhpDebugConsoleStatusView = require './status/php-debug-console-status-view'

PhpDebugContextUri = "phpdebug://context"
PhpDebugConsoleUri = "phpdebug://console"
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

checkIgnoreFile =  (filepath) ->
  WhiteList = atom.config.get('php-debug.SteppingFilter').split("\\").join("/")
  WhiteList = WhiteList.split(";")
  IgnoreThisFile = multimatch(filepath, WhiteList, { matchBase: true })
  if IgnoreThisFile.length > 0
    return false
  else
    return true

module.exports = PhpDebug =
  subscriptions: null

  config:
    EnableStatusbarButtons:
      title: "Enable buttons on status bar"
      type: 'boolean'
      default: true
      description: "Enable buttons on status bar"
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
    AutoExpandLocals:
      title: "Auto expand the locals section of the context"
      type: 'boolean'
      default: false
      description: "Will cause locals to auto open when starting a new debugging session"
    ActivateWindow:
        title: "Activate Atom window after break is hit."
        type: 'boolean'
        default: true
    SteppingFilter:
      type: 'string'
      default: "**"
      description: "Prevents stopping in library files while stepping through.  White list everything with ``**``, then remove glob matches using ``!`` (eg ``**;!C:\\projects\\thislib\\**``) or whitelist only project files. (eg ``C:\\projects\\project1\\**;!C:\\projects\\project1\\frame-work.php;C:\\projects\\project2\\**;!C:\\projects\\project2\\frame-work\\**``)"
    DebugXDebugMessages:
      title: "Output raw xdebug messages to the Atom debugger"
      type: 'boolean'
      default: false
      description: "Will output the xdebug xml to the Atom debugger"
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
    ServerAddress:
      type: 'string'
      default: '127.0.0.1'
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
    @subscriptions.add atom.commands.add 'atom-workspace', 'php-debug:toggleConsole': => @toggleConsole()
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
    @dbgp = new Dbgp(context: @GlobalContext, serverPort: atom.config.get('php-debug.ServerPort'), serverAddress: atom.config.get('php-debug.ServerAddress'))
    @GlobalContext.onBreak (breakpoint) =>
      @doCodePoint(breakpoint)

    @GlobalContext.onStackChange (codepoint) =>
      @doCodePoint(codepoint)

    @GlobalContext.onSocketError () =>
      @toggleDebugging()

    @GlobalContext.onSessionEnd () =>
      @getUnifiedView().setConnected(false)
      if @currentCodePointDecoration
        @currentCodePointDecoration.destroy?()

    @GlobalContext.onRunning () =>
      if @currentCodePointDecoration
        @currentCodePointDecoration.destroy?()

    @GlobalContext.onWatchpointsChange () =>
      if @GlobalContext.getCurrentDebugContext()
        @GlobalContext.getCurrentDebugContext().syncCurrentContext(0)

    @GlobalContext.onBreakpointsChange (event) =>
      if @GlobalContext.getCurrentDebugContext()
        if event.removed
          for breakpoint in event.removed
            @GlobalContext.getCurrentDebugContext().executeBreakpointRemove(breakpoint)
            if breakpoint.getMarker()
              breakpoint.getMarker().destroy?()
        if event.added
          for breakpoint in event.added
            @GlobalContext.getCurrentDebugContext().executeBreakpoint(breakpoint)
      if event.removed
        for breakpoint in event.removed
          if breakpoint.getMarker()
            breakpoint.getMarker().destroy?()

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
            if (!editor || !editor.getSelectedText)
              return false
            expression = editor?.getSelectedText()
            if !!expression then return true else return false
      },
      {
        label: 'Breakpoint settings'
        command: 'php-debug:breakpointSettings'
        shouldDisplay: =>
          editor = atom.workspace.getActivePaneItem()
          return false if !editor
          return false if !editor.getSelectedBufferRange
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
    atom.config.observe "php-debug.EnableStatusbarButtons", (enable) =>
      if enable
        @debugView = new PhpDebugDebugView(statusBar, this)
        @consoleStatusView = new PhpDebugConsoleStatusView(statusBar, this)
      else
        @consoleStatusView?.destroy?()
        @consoleStatusView = null
        @debugView?.destroy?()
        @debugView = null


  getUnifiedView: ->
    unless @unifiedView
      PhpDebugUnifiedView = require './unified/php-debug-unified-view'
      @unifiedView = new PhpDebugUnifiedView(context: @GlobalContext)

    return @unifiedView

  getConsoleView: ->
    unless @consoleView
      PhpDebugConsoleView = require './console/php-debug-console-view'
      @consoleView = new PhpDebugConsoleView(context: @GlobalContext)

    return @consoleView

  serialize: ->
    @GlobalContext.serialize()

  deactivate: ->
    @unifiedView?.setConnected(false)
    @debugView?.destroy?()
    @debugView = null
    @consoleStatusView?.destroy?()
    @consoleStatusView = null
    @unifiedView?.destroy?()
    @consoleView?.destroy?()
    @subscriptions.dispose()
    @dbgp?.close()

  updateDebugContext: (data) ->
    @contextView.setDebugContext(data)

  doCodePoint: (point) ->
      filepath = point.getPath()

      filepath = helpers.remotePathToLocal(filepath)

      if checkIgnoreFile(filepath)
        if @currentCodePointDecoration
          @currentCodePointDecoration.destroy?()
        if @GlobalContext.getCurrentDebugContext()
          @GlobalContext.getCurrentDebugContext().continue "step_out"
      else
        atom.workspace.open(filepath,{searchAllPanes: true, activatePane:true}).then (editor) =>
          if @currentCodePointDecoration
            @currentCodePointDecoration.destroy?()
          line = point.getLine()
          range = [[line-1, 0], [line-1, 0]]
          marker = editor.markBufferRange(range, {invalidate: 'surround'})

          type = point.getType?() ? 'generic'
          @currentCodePointDecoration = editor.decorateMarker(marker, {type: 'line', class: 'debug-break-'+type})
          editor.scrollToBufferPosition([line-1,0])
          if (atom.config.get('php-debug.ActivateWindow'))
            atom.focus()
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
      if (!editor || !editor.gutterWithName)
        return
      if create == false
        if (editor?.gutterWithName('php-debug-gutter') != null)
          gutter = editor?.gutterWithName('php-debug-gutter')
          gutter?.destroy?()
      else
        if recreate
          if (editor?.gutterWithName('php-debug-gutter') != null)
            gutter = editor?.gutterWithName('php-debug-gutter')
            gutter?.destroy?()
        if (editor?.gutterWithName('php-debug-gutter') == null)
          @createGutter(editor)


  createGutter: (editor) ->
    if (!editor)
      editor = atom.workspace.getActivePaneItem()

    if (!editor || !editor.gutterWithName)
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
      @currentCodePointDecoration.destroy?()

    if @settingsView
      @settingsView?.close()
      @settingsView?.destroy?()

    if !@getUnifiedView().isVisible()
      @getUnifiedView().setVisible(true)
      @debugView?.setActive(true)
      if !@dbgp.listening()
        @dbgp.setPort atom.config.get('php-debug.ServerPort')
        if !@dbgp.listen()
          console.log "failed"
          @getUnifiedView().setVisible(false)
          @debugView?.setActive(false)
          return

      @createGutter()

    else
      @getUnifiedView().setVisible(false)
      @debugView?.setActive(false)
      @dbgp?.close()

  toggleConsole: ->
    if !@getConsoleView().isVisible()
      @consoleStatusView?.setActive(true)
      @getConsoleView().setVisible(true)
    else
      @getConsoleView().setVisible(false)
      @consoleStatusView?.setActive(false)


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
        removed.getMarker().destroy?()
    else
      marker = @addBreakpointMarker(line, editor)
      breakpoint.setMarker(marker)
      @GlobalContext.addBreakpoint breakpoint
