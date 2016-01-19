{Disposable} = require 'atom'
{$, ScrollView} = require 'atom-space-pen-views'
PhpDebugContextView = require '../context/php-debug-context-view'
PhpDebugStackView = require '../stack/php-debug-stack-view'
PhpDebugWatchView = require '../watch/php-debug-watch-view'
PhpDebugBreakpointView = require '../breakpoint/php-debug-breakpoint-view'
Interact = require('interact.js')
module.exports =
class PhpDebugUnifiedView extends ScrollView
  @content: ->
    @div class: 'php-debug', tabindex: -1, =>
      @div class: 'php-debug-unified-view', =>
        @div class: 'block', =>
          @button class: "btn octicon icon-playback-play inline-block-tight",    disabled: 'disabled', 'data-action':'continue', "Continue"
          @button class: "btn octicon icon-steps inline-block-tight",            disabled: 'disabled', 'data-action':'step', "Step Over"
          @button class: "btn octicon icon-sign-in inline-block-tight",          disabled: 'disabled', 'data-action':'in', "Step In"
          @button class: "btn octicon icon-sign-out inline-block-tight",         disabled: 'disabled', 'data-action':'out', "Step Out"
          @button class: "btn octicon icon-primitive-square inline-block-tight", disabled: 'disabled', 'data-action':'stop', "Stop"
          @span outlet: 'connectStatus'
        @div class: 'tabs-view', =>
          @div outlet: 'stackView', class:'php-debug-tab'
          @div outlet: 'contextView', class:'php-debug-tab'
          @div outlet: 'watchpointView', class:'php-debug-tab'
          @div outlet: 'breakpointView', class:'php-debug-tab'

  constructor: (params) ->
    super
    @GlobalContext = params.context
    @contextList = []
    @GlobalContext.onBreak () =>
      @find('button').enable()
    @GlobalContext.onRunning () =>
      @find('button').disable()
    @GlobalContext.onSessionEnd () =>
      @find('button').disable()

    Interact(this.element).resizable({edges: { top: true }})
      .on('resizemove', (event) ->
        target = event.target
        if event.rect.height < 25
          if event.rect.height < 1
            target.style.width = target.style.height = null
          else
            return # No-Op
        else
          target.style.width  = event.rect.width + 'px'
          target.style.height = event.rect.height + 'px'
      )
      .on('resizeend', (event) ->
        event.target.style.width = 'auto'
      )

    @setConnected(false)

    @visible = false
    @panel = atom.workspace.addBottomPanel({item: this.element, visible: @visible, priority: 400})

  serialize: ->
    deserializer: @constructor.name
    uri: @getURI()

  getURI: -> @uri

  getTitle: -> "Debugging"
  


  setConnected: (isConnected) =>
    @panel?.item?.style.height = @panel?.item?.clientHeight + 'px'
    if isConnected
      @connectStatus.text('Connected')
    else
      serverPort = atom.config.get('php-debug.ServerPort')
      @connectStatus.text("Listening on port #{serverPort}...")

  setVisible: (@visible) =>
    if @visible
      @panel.show()
    else
      @panel.hide()

  isVisible: () =>
    @visible

  initialize: (params) =>
    super
    @stackView.append(new PhpDebugStackView(context: params.context))
    @contextView.append(new PhpDebugContextView(context: params.context))
    @watchpointView.append(new PhpDebugWatchView(context: params.context))
    @breakpointView.append(new PhpDebugBreakpointView(context: params.context))

    @on 'click', '[data-action]', (e) =>
      action = e.target.getAttribute('data-action')
      switch action
        when 'continue'
          @GlobalContext.getCurrentDebugContext().continue "run"
        when 'step'
          @GlobalContext.getCurrentDebugContext().continue "step_over"
        when 'in'
          @GlobalContext.getCurrentDebugContext().continue "step_into"
        when 'out'
          @GlobalContext.getCurrentDebugContext().continue "step_out"
        when 'stop'
          @GlobalContext.getCurrentDebugContext().executeDetach()

        else
          console.error "unknown action"
          console.dir action
          console.dir this

  openWindow: ->
    atom.workspace.addBottomPanel({
      item: this
      visible: true
    })

  onDidChangeTitle: -> new Disposable ->
  onDidChangeModified: -> new Disposable ->

  destroy: =>
    if @GlobalContext.getCurrentDebugContext()
      @GlobalContext.getCurrentDebugContext().executeDetach()

  isEqual: (other) ->
    other instanceof PhpDebugUnifiedView
