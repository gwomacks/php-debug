helpers = require '../helpers.coffee'
{Emitter, Disposable} = require 'event-kit'

class GlobalContext
  constructor: ->
    @emitter = new Emitter
    @breakpoints = []
    @watchpoints = []

  addBreakpoint: (breakpoint) ->
    helpers.insertOrdered  @breakpoints, breakpoint

  getBreakpoints: ->
    return @breakpoints

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


module.exports = new GlobalContext
