{Disposable} = require 'atom'
{$, ScrollView} = require 'atom-space-pen-views'
ContextView = require './context-view'

module.exports =
class PhpDebugContextView extends ScrollView
  @content: ->
    @div class: 'php-debug-context-view pane-item native-key-bindings', style: "overflow:auto;", tabindex: -1, =>
      @div class: "panel-heading", =>
        @span class: "heading-label", "Context"
        @span class: 'close-icon'
      @div outlet: 'contextViewList', class:'php-debug-contexts php-debug-contents native-key-bindings'

  serialize: ->
    deserializer: @constructor.name
    uri: @getURI()

  getURI: -> @uri

  getTitle: -> "Context"

  initialize: (params) ->
    super
    @GlobalContext = params.context
    @GlobalContext.onContextUpdate @showContexts
    @GlobalContext.onSessionEnd () =>
      if @contextViewList
        @contextViewList.empty()
  onDidChangeTitle: -> new Disposable ->
  onDidChangeModified: -> new Disposable ->

  isEqual: (other) ->
    other instanceof PhpDebugContextView

  showContexts: =>
    if @contextViewList
      @autoopen = []
      if (atom.config.get('php-debug.AutoExpandLocals'))
        @autoopen.push('locals')
        @autoopen.push('Locals')

      @contextViewList.find("details[open]").each (_,el) =>
        item = $(el)
        added = false
        for open,index in @autoopen
          if item.data('name').indexOf(open) == 0
            @autoopen[index] = item.data('name')
            added = true
            break
        if !added
          @autoopen.push(item.data('name'))
      @contextViewList.empty()
    contexts = @GlobalContext.getCurrentDebugContext()
    for index,context of contexts.scopeList
      if context == undefined
        continue
      @contextViewList.append(new ContextView(context,@autoopen))
