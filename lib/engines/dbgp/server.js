'use babel'


import {Emitter, Disposable} from 'event-kit'
import net from "net"
import autoBind from 'auto-bind-inheritance'
export default class Server {
  constructor (params) {
    autoBind(this)
    this._emitter = new Emitter()
    this._serverPort = params.serverPort;
    this._serverAddress = params.serverAddress;
    this._sockets = []
  }

  getPort() {
    return this._serverPort
  }

  getAddress() {
    return this._serverAddress
  }

  setPort (port) {
    if (port != this._serverPort) {
      this._serverPort = port
      if (this.isListening()) {
        this.close()
        this.listen()
      }
    }
  }

  setAddress (address) {
    if (address != this._serverAddress) {
      this._serverAddress = address
      if (this.isListening()) {
        this.close()
        this.listen()
      }
    }
  }

  setAddressPort (address,port) {
    if (port != this._serverPort || address != this._serverAddress) {
      this._serverPort = port
      this._serverAddress = address
      if (this.isListening()) {
        this.close()
        this.listen()
      }
    }
  }

  isListening () {
    return this._server != undefined;
  }

  listen (options) {
    try {
      if (this.isListening()) {
        this.close()
      }
      this._sockets = []
      this._server = net.createServer( (socket) => {
        //socket.setEncoding('utf8');
        socket.on('error', (err) => {
          this._emitter.emit('php-debug.engine.internal.connectionError', {socket:socket,error:err})
          try {
            socket.end()
          } catch (err) {
            // Supress
          }
          if (this._sockets == undefined || this._sockets == null) return;
          this._sockets = this._sockets.filter(item => item !== socket)
        })
        socket.on('close', () => {
          this._emitter.emit('php-debug.engine.internal.connectionClosed', socket)
          if (this._sockets == undefined || this._sockets == null) return;
          this._sockets = this._sockets.filter(item => item !== socket)
        })
        socket.on('end', () => {
          this._emitter.emit('php-debug.engine.internal.connectionEnded', socket)
          if (this._sockets == undefined || this._sockets == null) return;
          this._sockets = this._sockets.filter(item => item !== socket)
        })
        if (atom.config.get('php-debug.xdebug.multipleSessions') !== true && atom.config.get('php-debug.xdebug.multipleSessions') !== 1) {
          if (this._sockets.length >= 1) {
            console.log("Rejecting session")
            try {
            socket.end();
          } catch (err) {
            console.error(err);
          }
            return;
          }
        }
        this._sockets.push(socket)
        this._emitter.emit('php-debug.engine.internal.newConnection', socket)
      });

      if (this._server) {
        this._server.on('error', (err) => {
          this._emitter.emit('php-debug.engine.internal.serverError', err)
          this.close()
          return false
        });
      }

      let serverOptions = {}
      serverOptions.port = this._serverPort
      if (this._serverAddress != "*") {
        serverOptions.host = this._serverAddress
      }
      if (this._server) {
        this._server.listen(serverOptions, () => {
          this._emitter.emit('php-debug.engine.internal.serverListening')
        });
      }
      return true
    } catch (e) {
      this._emitter.emit('php-debug.engine.internal.serverError', e)
      this.close()
      return false
    }
  }

  close () {
    this._emitter.emit('php-debug.engine.internal.listenerClosing')
    if (this._sockets != undefined && this._sockets != null) {
      for (let socket of this._sockets) {
        try {
          socket.end()
        } catch (err) {
          // Supress
        }
      }
      delete this._sockets
    }
    if (this._server != undefined && this._server != null) {
      this._server.close()
      delete this._server
    }
    this._emitter.emit('php-debug.engine.internal.listenerClosed')
  }

  onServerListening(callback) {
    return this._emitter.on('php-debug.engine.internal.serverListening', callback)
  }
  onServerError(callback) {
    return this._emitter.on('php-debug.engine.internal.serverError', callback)
  }
  onlistenerClosed(callback) {
    return this._emitter.on('php-debug.engine.internal.listenerClosed', callback)
  }
  onlistenerClosing(callback) {
    return this._emitter.on('php-debug.engine.internal.listenerClosing', callback)
  }
  onNewConnection(callback) {
    return this._emitter.on('php-debug.engine.internal.newConnection', callback)
  }
  onConnectionError(callback) {
    return this._emitter.on('php-debug.engine.internal.connectionError', callback)
  }
  onConnectionClosed(callback) {
    return this._emitter.on('php-debug.engine.internal.connectionClosed', callback)
  }
  onConnectionEnded(callback) {
    return this._emitter.on('php-debug.engine.internal.connectionEnded', callback)
  }

  destroy() {
    this.close()
    if (typeof this._emitter.destroy === "function") {
      this._emitter.destroy()
    }
    this._emitter.dispose()
  }
}
