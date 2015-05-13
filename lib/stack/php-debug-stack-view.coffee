{$, ScrollView} = require 'atom-space-pen-views'

StackFrameView = require('./stack-frame-view')
GlobalContext = require '../models/global-context'

module.exports =
class PhpDebugStackView extends ScrollView
  @content: ->
    @div class: 'php-debug php-debug-context-view pane-item native-key-bindings', style: "overflow:auto;", tabindex: -1, =>
      @div class: "panel-heading", "Stack"
      @ul outlet: 'stackFrameViewList', class:'php-debug-contexts'

  initialize: (params) ->
    super
    @GlobalContext = params.context
    @GlobalContext.onContextUpdate @showStackFrames

  showStackFrames: =>
    if @stackFrameViewList
      @stackFrameViewList.empty()
    context = @GlobalContext.getCurrentDebugContext()
    for index, stackFrame of context.getStack()
      if stackFrame == undefined
        continue
      @stackFrameViewList.append(new StackFrameView(stackFrame))
