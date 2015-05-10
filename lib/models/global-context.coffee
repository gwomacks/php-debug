helpers = require '../helpers.coffee'
{Emitter, Disposable} = require 'event-kit'

module.exports =
class GlobalContext
  atom.deserializers.add(this)
  # @version = '1a'
  constructor: ->
    @emitter = new Emitter
    @breakpoints = []
    @watchpoints = []
    @debugContexts = []

  serialize: -> {
    deserializer: 'GlobalContext'
    data: {
      version: @constructor.version
      breakpoints: helpers.serializeArray(@getBreakpoints())
      watchpoints: helpers.serializeArray(@getWatchpoints())
    }
  }

  @deserialize: ({data}) ->
    context = new GlobalContext()
    console.dir data
    breakpoints = helpers.deserializeArray(data.breakpoints)
    context.setBreakpoints(breakpoints)
    watchpoints = helpers.deserializeArray(data.watchpoints)
    context.setWatchpoints(watchpoints)
    console.dir context
    return context



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
    return @debugContexts[0]

  addWatchpoint: (watchpoint) ->
    helpers.insertOrdered  @watchpoints, watchpoint
    @notifyWatchpointsChange()

  getWatchpoints: ->
    return @watchpoints

  setContext: (context) ->
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
