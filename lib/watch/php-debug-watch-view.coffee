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
    @div class: "panel", =>
      @section class: 'watchpoint-panel section', =>
        @div class: 'editor-container', =>
          @subview 'newWatchpointEditor', new TextEditorView()
        @div outlet: 'watchpointViewList', class:'php-debug-watchpoints'

  constructor: ->
    super()
    @watchList = []

  serialize: ->
    deserializer: @constructor.name
    uri: @getURI()

  getURI: -> @uri

  getTitle: -> "Watch"

  onDidChangeTitle: -> new Disposable ->
  onDidChangeModified: -> new Disposable ->


  initialize: ->
    @newWatchpointEditor.getModel().onWillInsertText @submitWatchpoint
    GlobalContext.onWatchpointsChange @showWatches

  submitWatchpoint: (event) =>
    return unless event.text is "\n"
    expression = @newWatchpointEditor
      .getModel()
      .getText()
    w = new Watchpoint(expression)
    GlobalContext.addWatchpoint(w)
    @newWatchpointEditor
      .getModel()
      .setText('')
    event.cancel()

  isEqual: (other) ->
    other instanceof PhpDebugWatchView

  setContext: (watch, data) ->
    @watchList[watch] = data
    @showWatches()

  showWatches: =>
    @watchpointViewList.empty()
    for watch in GlobalContext.getWatchpoints()
      if watch == undefined
        continue
      @watchpointViewList.append(new WatchView(watch))
