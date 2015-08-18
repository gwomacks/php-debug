{$, ScrollView} = require 'atom-space-pen-views'

StackFrameView = require('./stack-frame-view')
GlobalContext = require '../models/global-context'
Codepoint = require '../models/codepoint'
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
    @GlobalContext.onSessionEnd () =>
      if @stackFrameViewList
        @stackFrameViewList.empty()

    @stackFrameViewList.on 'mousedown', 'li', (e) =>
      @selectStackFrame($(e.target).closest('li'))
      e.preventDefault()
      false

    @stackFrameViewList.on 'mouseup', 'li', (e) =>
      e.preventDefault()
      false

  showStackFrames: =>
    if @stackFrameViewList
      @stackFrameViewList.empty()
    context = @GlobalContext.getCurrentDebugContext()
    for index, stackFrame of context.getStack()
      if stackFrame == undefined
        continue
      @stackFrameViewList.append(new StackFrameView(stackFrame))

  selectStackFrame: (view) ->
    return unless view.length
    @stackFrameViewList.find('.selected').removeClass('selected')
    view.addClass('selected')
    @GlobalContext.notifyStackChange(new Codepoint(filepath: view.find('.stack-frame-filepath').data('path'), line: view.find('.stack-frame-line').data('line') , stackdepth: view.find('.stack-frame-level').data('level')))
