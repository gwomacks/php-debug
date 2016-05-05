parseString = require('xml2js').parseString
Q = require 'q'
{Emitter, Disposable} = require 'event-kit'

DebugContext = require '../../models/debug-context'
Watchpoint = require '../../models/watchpoint'
DbgpInstance = require './dbgp-instance'

module.exports =
class Dbgp
  constructor: (params) ->
    @emitter = new Emitter
    @buffer = ''
    @GlobalContext = params.context
    @serverPort = params.serverPort

  setPort: (port) ->
    @serverPort = port

  listening: ->
    return @server != undefined

  running: ->
    return @socket && @socket.readyState == 1

  listen: (options) ->

    @debugContext = new DebugContext
    net = require "net"
    buffer = ''
    try
      console.log "Listening on Port " + @serverPort
      @server = net.createServer( (socket) =>

        socket.setEncoding('ascii');
        if !@GlobalContext.getCurrentDebugContext()
          console.log "Session initiated"
          instance = new DbgpInstance(socket:socket, context:@GlobalContext)
        else
          console.log "New session rejected"
          socket.end()
      )
      @server?.on 'error', (err) =>
        console.error "Socket Error:", err
        atom.notifications.addWarning "Could not bind socket, do you already have an instance of the debugger open?"
        @close()
        @GlobalContext.notifySocketError()
        return false
        
      @server?.listen @serverPort
      return true
    catch e
      console.error "Socket Error:", e
      atom.notifications.addWarning "Could not bind socket, do you already have an instance of the debugger open?"
      @close()
      @GlobalContext.notifySocketError()
      return false
      # body...

  close: (options) ->
    @GlobalContext.getCurrentDebugContext()?.stop()
    unless !@socket
      @socket.end()
      delete @socket
    unless !@server
      @server.close()
      delete @server
    console.log("closed")
