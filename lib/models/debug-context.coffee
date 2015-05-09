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
    console.log "setting stack"
    console.dir stack
    @stackFrameList = stack

  getStack: () ->
    console.log "getting stack"
    console.dir @stackFrameList
    return @stackFrameList

  clear: () ->
    console.log "meow?"
    @scopeList = {}

  getScopes: ->
    return @scopeList
