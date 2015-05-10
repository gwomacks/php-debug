{Disposable} = require 'atom'
{$, ScrollView} = require 'atom-space-pen-views'
BreakpointView = require './breakpoint-view'

GlobalContext = require '../models/global-context'

module.exports =
class PhpDebugBreakpointView extends ScrollView
  @content: ->
    @div class: 'php-debug php-debug-breakpoint-view pane-item native-key-bindings padded', tabindex: -1, =>
      @div outlet: 'breakpointViewList', class:'php-debug-breakpoints'

  constructor: (params) ->
    super
    @contextList = []

  serialize: ->
    deserializer: @constructor.name
    uri: @getURI()

  getURI: -> @uri

  getTitle: -> "Breakpoints"

  onDidChangeTitle: -> new Disposable ->
  onDidChangeModified: -> new Disposable ->

  isEqual: (other) ->
    other instanceof PhpDebugBreakpointView

  initialize: (params) =>
    @GlobalContext = params.context
    @showBreakpoints()
    @GlobalContext.onBreakpointsChange @showBreakpoints

  showBreakpoints: =>
    if @breakpointViewList
      @breakpointViewList.empty()
    breakpoints = @GlobalContext.getBreakpoints()
    @breakpointViewList.append(new BreakpointView(breakpoints))
