helpers = require '../helpers.coffee'
{Emitter, Disposable} = require 'event-kit'

module.exports =
class GlobalContext
  atom.deserializers.add(this)
  constructor: ->
    @emitter = new Emitter
    @breakpoints = []
    @watchpoints = []
    @debugContexts = []

  serialize: -> {
    deserializer: 'GlobalContext'
    data: {
      breakpoints: @breakpoints
      watchpoints: @watchpoints
    }
  }

  deserialize: ({data}) ->
    @breakpoints = data.breakpoints
    @watchpoints = data.watchpoints


  addBreakpoint: (breakpoint) ->
    helpers.insertOrdered  @breakpoints, breakpoint

  setBreakpoints: (breakpoints) ->
    @breakpoints = breakpoints

  setWatchpoints: (watchpoints) ->
    @watchpoints = watchpoints

  getBreakpoints: ->
    return @breakpoints

  addDebugContext: (debugContext) ->
    @debugContexts.push debugContext

  getCurrentDebugContext: () =>
    console.log "getting context"
    return @debugContexts[0]

  addWatchpoint: (watchpoint) ->
    helpers.insertOrdered  @watchpoints, watchpoint
    @notifyWatchpointsChange()

  getWatchpoints: ->
    return @watchpoints

  setContext: (context) ->
    console.log "setting context"
    console.dir context
    @context = context

  getContext: ->
    return @context

  clearContext: ->


  onBreakpointsChange: (callback) ->
    @emitter.on 'php-debug.breakpointsChange', callback

  notifyBreakpointsChange: (data) ->
    @emitter.emit 'php-debug.breakpointsChange', data

  onWatchpointsChange: (callback) ->
    @emitter.on 'php-debug.watchpointsChange', callback

  notifyWatchpointsChange: (data) ->
    @emitter.emit 'php-debug.watchpointsChange', data

  onBreak: (callback) ->
    @emitter.on 'php-debug.break', callback

  notifyBreak: (data) ->
    @emitter.emit 'php-debug.break', data

  onContextUpdate: (callback) ->
    @emitter.on 'php-debug.contextUpdate', callback

  notifyContextUpdate: (data) ->
    @emitter.emit 'php-debug.contextUpdate', data
