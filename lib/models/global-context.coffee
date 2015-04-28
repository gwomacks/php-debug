helpers = require '../helpers.coffee'
{Emitter, Disposable} = require 'event-kit'

class GlobalContext
  constructor: ->
    @emitter = new Emitter
    @breakpoints = []
    @watchpoints = []

  addBreakpoint: (breakpoint) ->
    # index = helpers.getInsertIndex(@breakpoints, breakpoint)
    # @breakpoints.splice(index,0, breakpoint)
    helpers.insertOrdered  @breakpoints, breakpoint

  getBreakpoints: ->
    return @breakpoints

  addWatchpoint: (watchpoint) ->
    # index = getInsertIndex(@watchpoints, watchpoint)
    # @watchpoints.splice(index,0, watchpoint)
    helpers.insertOrdered  @watchpoints, watchpoint
    @notifyWatchpointsChange()

  getWatchpoints: ->
    return @watchpoints

  onBreakpointsChange: (callback) ->
    @emitter.on 'php-debug.breakpointsChange', callback

  notifyBreakpointsChange: (data) ->
    @emitter.emit 'php-debug.breakpointsChange', data

  onWatchpointsChange: (callback) ->
    @emitter.on 'php-debug.watchpointsChange', callback

  notifyWatchpointsChange: (data) ->
    @emitter.emit 'php-debug.watchpointsChange', data


module.exports = new GlobalContext
