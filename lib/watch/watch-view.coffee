{View} = require 'atom-space-pen-views'
ContextVariableView = require '../context/context-variable-view'
GlobalContext = require '../models/global-context'

module.exports =
class WatchView extends View

  @content: ->
    @div class: 'native-key-bindings', =>
      @div class: 'watch-item', =>
        @div outlet: 'variable'
        @span click: 'remove', class: 'close-icon'

  initialize: (params) ->
    @watchpoint = params.watchpoint
    @autoopen = params.autoopen
    @GlobalContext = params.context
    @render()

  remove: ->
    @GlobalContext.removeWatchpoint @watchpoint

  render: ->
    datum = @watchpoint.getValue()
    if not datum?
      datum = {
        label : @watchpoint.getExpression()
        type: 'uninitialized'
      }
    @variable.append new ContextVariableView({variable:datum,parent:null,openpaths:@autoopen})
