helpers = require '../helpers.coffee'

module.exports =

class DebugContext

  constructor: () ->
    @scopeList = {}
    @watchpointList = []

  addScope: (scopeId, name) ->
    @scopeList[scopeId] = { name: name, scopeId: scopeId, context: {} }

  setScopeContext: (scopeId, context) ->
    @scopeList[scopeId].context = context

  addWatchpoint: (watchpoint) ->
    index = helpers.getInsertIndex(@watchpointList, watchpoint)
    @watchpointList.push({watchpoint: watchpoint, value: undefined})

  setWatchpointValue: (watchpoint, value) ->

  clear: () ->
    console.log "meow?"
    @scopeList = {}

  getScopes: ->
    return @scopeList
