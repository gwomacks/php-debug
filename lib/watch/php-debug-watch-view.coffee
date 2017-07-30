{Disposable} = require 'atom'
{$, ScrollView} = require 'atom-space-pen-views'
{$, TextEditorView, View}  = require 'atom-space-pen-views'
{Emitter, Disposable} = require 'event-kit'
WatchView = require './watch-view'
GlobalContext = require '../models/global-context'
Watchpoint = require '../models/watchpoint'
module.exports =
class PhpDebugWatchView extends ScrollView
  @content: ->
    @div class: 'php-debug-watch-view pane-item', style: "overflow:auto;", tabindex: -1, =>
      @div class: "panel-heading", =>
        @span class: "heading-label", "Watchpoints"
        @span class: 'close-icon'
      @section class: 'php-debug-watches php-debug-contents section', =>
        @div class: 'editor-container', =>
          @subview 'newWatchpointEditor', new TextEditorView()
        @div outlet: 'watchpointViewList', class:'php-debug-watchpoints'

  constructor: ->
    super

  serialize: ->
    deserializer: @constructor.name
    uri: @getURI()

  getURI: -> @uri

  getTitle: -> "Watch"

  onDidChangeTitle: -> new Disposable ->
  onDidChangeModified: -> new Disposable ->


  initialize: (params) ->
    @GlobalContext = params.context
    @newWatchpointEditor.getModel().onWillInsertText @submitWatchpoint
    @GlobalContext.onContextUpdate @showWatches
    @GlobalContext.onWatchpointsChange @showWatches
    @showWatches()

  submitWatchpoint: (event) =>
    return unless event.text is "\n"
    expression = @newWatchpointEditor
      .getModel()
      .getText()
    w = new Watchpoint(expression:expression)
    @GlobalContext.addWatchpoint(w)
    @newWatchpointEditor
      .getModel()
      .setText('')
    event.cancel()

  isEqual: (other) ->
    other instanceof PhpDebugWatchView

  showWatches: =>
    if @watchpointViewList
      @autoopen = []
      @watchpointViewList.find("details[open]").each (_,el) =>
        item = $(el)
        added = false
        for open,index in @autoopen
          if item.data('name').indexOf(open) == 0
            @autoopen[index] = item.data('name')
            added = true
            break
        if !added
          @autoopen.push(item.data('name'))
    @watchpointViewList.empty()
    if @GlobalContext.getCurrentDebugContext()
      watches = @GlobalContext.getCurrentDebugContext().getWatchpoints()
    else
      watches = @GlobalContext.getWatchpoints()
    for watch in watches
      if watch == undefined
        continue
      @watchpointViewList.append(new WatchView({watchpoint:watch,autoopen:@autoopen,context:@GlobalContext}))
