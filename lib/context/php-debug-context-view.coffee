{Disposable} = require 'atom'
{$, ScrollView} = require 'atom-space-pen-views'
ContextView = require './context-view'

module.exports =
class PhpDebugContextView extends ScrollView
  @content: ->
    @div class: 'php-debug php-debug-context-view pane-item native-key-bindings padded', tabindex: -1, =>
      @button class: 'btn btn-collapse-all', 'Collapse All Sections'
      @div outlet: 'contextViewList', class:'php-debug-contexts'

  constructor: ->
    super()
    @contextList = []

  serialize: ->
    deserializer: @constructor.name
    uri: @getURI()

  getURI: -> @uri

  getTitle: -> "Context"

  onDidChangeTitle: -> new Disposable ->
  onDidChangeModified: -> new Disposable ->

  isEqual: (other) ->
    other instanceof PhpDebugContextView

  setDebugContext: (context) ->
    @debugContext = context
    @showContexts()

  showContexts: ->
    @contextViewList.empty()
    for index, context of @debugContext.scopeList
      console.dir context
      if context == undefined
        continue
      @contextViewList.append(new ContextView(context))
