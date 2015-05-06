{Disposable} = require 'atom'
{$, ScrollView} = require 'atom-space-pen-views'
ContextView = require './context-view'
GlobalContext = require '../models/global-context'

module.exports =
class PhpDebugContextView extends ScrollView
  @content: ->
    @div class: 'php-debug php-debug-context-view pane-item native-key-bindings padded', style: "overflow:auto;", tabindex: -1, =>
      @div outlet: 'contextViewList', class:'php-debug-contexts'

  constructor: ->
    super()
    @contextList = []

  serialize: ->
    deserializer: @constructor.name
    uri: @getURI()

  getURI: -> @uri

  getTitle: -> "Context"

  initialize: (@editor) ->
    super
    GlobalContext.onContextUpdate @showContexts

  onDidChangeTitle: -> new Disposable ->
  onDidChangeModified: -> new Disposable ->

  isEqual: (other) ->
    other instanceof PhpDebugContextView

  setDebugContext: (context) ->
    @debugContext = context
    @showContexts()

  showContexts: =>
    if @contextViewList
      @contextViewList.empty()
    contexts = GlobalContext.getCurrentDebugContext()
    for index, context of contexts.scopeList
      if context == undefined
        continue
      @contextViewList.append(new ContextView(context))
