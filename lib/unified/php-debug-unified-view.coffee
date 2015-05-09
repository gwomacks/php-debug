{Disposable} = require 'atom'
{$, ScrollView} = require 'atom-space-pen-views'
PhpDebugContextView = require '../context/php-debug-context-view'
PhpDebugStackView = require '../stack/php-debug-stack-view'
PhpDebugWatchView = require '../watch/php-debug-watch-view'
PhpDebugBreakpointView = require '../breakpoint/php-debug-breakpoint-view'
GlobalContext = require '../models/global-context'
module.exports =
class PhpDebugUnifiedView extends ScrollView
  @content: ->
    @div class: 'php-debug php-debug-unified-view pane-item padded', style: 'overflow:auto;', tabindex: -1, =>
      @div class: 'tabs-view', =>
        @div outlet: 'stackView', class:'php-debug-tab'
        @div outlet: 'contextView', class:'php-debug-tab'
        @div outlet: 'watchpointView', class:'php-debug-tab'
        @div outlet: 'breakpointView', class:'php-debug-tab'

  constructor: ->
    super()
    @contextList = []

  serialize: ->
    deserializer: @constructor.name
    uri: @getURI()

  getURI: -> @uri

  getTitle: -> "Unified"

  initialize: (@editor) ->
    super
    @stackView.append(new PhpDebugStackView())
    @contextView.append(new PhpDebugContextView())
    @watchpointView.append(new PhpDebugWatchView())
    @breakpointView.append(new PhpDebugBreakpointView())
    # GlobalContext.onBreak @doUpdate

  openWindow: ->
    atom.workspace.addBottomPanel({
      item: this
      visible: true
    })

  # doUpdate: =>
  #   console.log "showing context"

  onDidChangeTitle: -> new Disposable ->
  onDidChangeModified: -> new Disposable ->

  isEqual: (other) ->
    other instanceof PhpDebugContextView

  # showContexts: ->
  #   @contextViewList.empty()
  #   for index, context of @debugContext.scopeList
  #     if context == undefined
  #       continue
  #     @contextViewList.append(new ContextView(context))
