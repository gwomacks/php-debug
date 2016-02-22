helpers = require '../helpers.coffee'

module.exports =

class DebugContext

  constructor: () ->
    @scopeList = {}
    @watchpointList = []
    @stackFrameList = []

  addScope: (scopeId, name) ->
    @scopeList[scopeId] = { name: name, scopeId: scopeId, context: {} }

  setScopeContext: (scopeId, context) ->
    @scopeList[scopeId].context = context

  addWatchpoint: (watchpoint) ->
    index = helpers.getInsertIndex(@watchpointList, watchpoint)
    @watchpointList.push(watchpoint)

  clearWatchpoints: () ->
    @watchpointList = []

  getWatchpoints: () ->
    return @watchpointList

  setStack: (stack) ->
    @stackFrameList = stack

  getStack: () ->
    return @stackFrameList

  clear: () ->
    @scopeList = {}

  getScopes: ->
    return @scopeList
    
  stop: ->
    
