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

  listening: ->
    return @server != undefined

  running: ->
    return @socket && @socket.readyState == 1

  listen: (options) ->

    @debugContext = new DebugContext
    net = require "net"
    console.log("listening")
    buffer = ''
    @server = net.createServer( (socket) =>

      socket.setEncoding('utf8');
      instance = new DbgpInstance(socket:socket, context:@GlobalContext)
    ).listen 9000

  close: (options) ->
    unless !@socket
      @socket.end()
      delete @socket
    unless !@server
      @server.close()
      delete @server
    console.log("closed")
