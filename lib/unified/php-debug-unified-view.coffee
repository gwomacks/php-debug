{Disposable} = require 'atom'
{$, ScrollView} = require 'atom-space-pen-views'
PhpDebugContextView = require '../context/php-debug-context-view'
GlobalContext = require '../models/global-context'
module.exports =
class PhpDebugUnifiedView extends ScrollView
  @content: ->
    @div class: 'php-debug php-debug-unified-view pane-item native-key-bindings padded', tabindex: -1, =>
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
    @contextView.append(new PhpDebugContextView())
    # GlobalContext.onBreak @doUpdate

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
