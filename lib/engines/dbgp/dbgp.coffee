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
    @serverAddress = params.serverAddress

  setPort: (port) ->
    @serverPort = port

  setAddress: (address) ->
    @serverAddress = address

  listening: ->
    return @server != undefined

  running: ->
    return @socket && @socket.readyState == 1

  listen: (options) ->

    @debugContext = new DebugContext
    net = require "net"
    buffer = ''
    try
      @GlobalContext?.notifyConsoleMessage "Listening on Address:Port " + @serverAddress + ":" + @serverPort
      console.log "Listening on Address:Port " + @serverAddress + ":" + @serverPort
      @server = net.createServer( (socket) =>

        socket.setEncoding('ascii');
        if !@GlobalContext.getCurrentDebugContext()
          @GlobalContext?.notifyConsoleMessage "Session initiated"
          console.log "Session initiated"
          instance = new DbgpInstance(socket:socket, context:@GlobalContext)
        else
          @GlobalContext?.notifyConsoleMessage "New session rejected"
          console.log "New session rejected"
          socket.end()
      )
      @server?.on 'error', (err) =>
        @GlobalContext?.notifyConsoleMessage "Error: " + "Socket Error:", err
        console.error "Socket Error:", err
        atom.notifications.addWarning "Could not bind socket, do you already have an instance of the debugger open?"
        @close()
        @GlobalContext.notifySocketError()
        return false

      @server?.listen @serverPort, @serverAddress
      return true
    catch e
      @GlobalContext?.notifyConsoleMessage "Error: " + "Socket Error:", e
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
    @GlobalContext?.notifyConsoleMessage "Closed"
    console.log("closed")
