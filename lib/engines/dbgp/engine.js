'use babel'

import helpers from '../../helpers'
import DebugEngine from '../../models/debug-engine'
import Server from './server'
import DebuggingContext from './debugging-context'
import {Emitter, Disposable} from 'event-kit'
import autoBind from 'auto-bind-inheritance'
import uuid from 'uuid'
import {CompositeDisposable} from 'atom'

export default class PHPDebugEngine extends DebugEngine {
  constructor () {
    super()
    autoBind(this);
    this._destroyed = false
    this._subscriptions = new CompositeDisposable()
    this._emitter = new Emitter()
    this.initializeServer()
    this._debugContexts = {}
  }

  initializeServer() {
    if (this._server == undefined || this._server == null) {
      this._server = new Server({serverAddress:atom.config.get('php-debug.server.serverAddress'), serverPort:atom.config.get('php-debug.server.serverPort')})
      this._subscriptions.add(this._server.onServerListening(this.handleServerListening))
      this._subscriptions.add(this._server.onServerError(this.handleServerError))
      this._subscriptions.add(this._server.onlistenerClosed(this.handleListenerClosed))
      this._subscriptions.add(this._server.onNewConnection(this.handleNewConnection))
      this._subscriptions.add(this._server.onConnectionEnded(this.handleConnectionEnded))
      this._subscriptions.add(this._server.onConnectionClosed(this.handleConnectionEnded))
      this._subscriptions.add(this._server.onConnectionError(this.handleConnectionError))
    }
  }

  setUIServices(services) {
    this._services = services
  }

  getUIServices() {
    return this._services
  }

  getName() {
    return "PHP Debug"
  }

  getContextForSocket(socket) {
    for (let context in this._debugContexts) {
      if (this._debugContexts[context].getSocket() == socket) {
        return this._debugContexts[context]
      }
    }
    return null
  }

  hasContext(context) {
    return this._debugContexts.hasOwnProperty(context)
  }

  hasUIServices() {
    return this._services != undefined && this._services != null;
  }

  tryGetContext() {
    // Maybe we'll get lucky
    let paneItem = atom.workspace.getActivePaneItem()
    if (paneItem != null && typeof paneItem.getURI === "function") {
      if (paneItem.getURI().indexOf("php-debug://debug-view") === 0) {
        let contextID = paneItem.getURI().substring(23)
        if (this.hasContext(contextID)) {
          return this._debugContexts[contextID]
        }
      }
      if (paneItem.getURI().indexOf("php-debug://console-view") === 0) {
        let contextID = paneItem.getURI().substring(25)
        if (this.hasContext(contextID)) {
          return this._debugContexts[contextID]
        }
      }
    }
    // Try each dock
    let docks = [atom.workspace.getBottomDock(),atom.workspace.getLeftDock(), atom.workspace.getRightDock()];
    for (let dock of docks) {
      let paneItem = dock.getActivePaneItem()
      if (paneItem != null && typeof paneItem.getURI === "function") {
        if (paneItem.getURI().indexOf("php-debug://debug-view") === 0) {
          let contextID = paneItem.getURI().substring(23)
          if (this.hasContext(contextID)) {
            return this._debugContexts[contextID]
          }
        }
        if (paneItem.getURI().indexOf("php-debug://console-view") === 0) {
          let contextID = paneItem.getURI().substring(25)
          if (this.hasContext(contextID)) {
            return this._debugContexts[contextID]
          }
        }
      }
    }
    if (this.hasContext("default")) {
      return this._debugContexts["default"];
    }
    return null;
  }

  onSessionStart(callback) {
    return this._emitter.on('php-debug.engine.sessionStart', callback)
  }

  onRunning(callback) {
    return this._emitter.on('php-debug.engine.running', callback)
  }

  onBreak(callback) {
    return this._emitter.on('php-debug.engine.break', callback)
  }

  onSessionEnd(callback) {
    return this._emitter.on('php-debug.engine.sessionEnd', callback)
  }

  assignSocketToContext(socket) {
    if (!this.hasUIServices()) {
      return
    }
    if (!this._debugContexts.hasOwnProperty("default")) {
      this.createDebuggingContext("default", socket)
      this._services.getLoggerService().debug("Assigned socket to default context")
      return
    }
    if (!this._debugContexts.default.isActive()) {
      this._debugContexts.default.activate(socket)
      this._services.getLoggerService().debug("Assigned socket to default context")
      return
    } else {
      // Create a new context with a temporary ID
      const identifier = uuid.v4()
      this._debugContexts[identifier] = new DebuggingContext(this.getUIServices(),identifier)
      const disposable = this._debugContexts[identifier].onSessionStart((event) => {
        // Update it with a DBGP context identifier
        this._debugContexts[event.appid] = this._debugContexts[identifier]
        delete this._debugContexts[identifier]
        this.createUIContext(event.appid).then( (context) => {
          context.getUIService().activateDebugger()
        }).catch( (err) => {
          console.log('Failed to property initialize active debugger')
        });
        this._services.getLoggerService().debug("New context with identifier: " + event.appid + " from " + identifier)
        disposable.dispose()
      })
      this.bindContextEvents(this._debugContexts[identifier])
      this._debugContexts[identifier].activate(socket)
      this._services.getLoggerService().debug("Created new context with temporary identifier: " + identifier)
    }
  }

  createUIContext(identifier) {
    return new Promise ((fulfill,reject) => {
      if (!this.hasUIServices()) {
        reject("no ui services")
        return
      }

      this._services.getDebugViewService().createContext(identifier,{'allowAutoClose':true,'allowActionBar':false}).then((service) => {
        this._debugContexts[identifier].setUIService(service)
        service.activateDebugger()
        service.activateConsole()
        fulfill(this._debugContexts[identifier])
      }).catch((err) => {
        this._services.getLoggerService().error(err)
        reject(err)
      })
    })
  }

  createDebuggingContext(identifier, socket) {
    return new Promise( (fulfill,reject) => {

      if (!this.hasUIServices()) {
        reject("no ui services")
        return
      }

      if (this._debugContexts.hasOwnProperty(identifier)) {
        if (this._debugContexts[identifier].hasUIService()) {
          fulfill(this._debugContexts[identifier])
          return
        }
      }
      let options = {'allowAutoClose':true,'allowActionBar':false}
      if (identifier == "default") {
        options.allowActionBar = true
        options.allowAutoClose = false
      }
      this._services.getDebugViewService().createContext(identifier, options).then((service) => {
        this._debugContexts[identifier] = new DebuggingContext(this.getUIServices(), identifier, service)
        this.bindContextEvents(this._debugContexts[identifier])
        if (socket != undefined && socket != null) {
          this._debugContexts[identifier].activate(socket)
        }
        if (!this._server.isListening()) {
          this._server.listen()
        }
        service.activateDebugger()
        service.activateConsole()
        fulfill(this._debugContexts[identifier])
      }).catch((err) => {
        this._services.getLoggerService().error(err)
        reject(err)
      })
    })
  }

  bindContextEvents(context) {
    this._subscriptions.add(context.onRunning((event) => {
      this._emitter.emit('php-debug.engine.running',event)
    }))
    this._subscriptions.add(context.onBreak((event) => {
      this._emitter.emit('php-debug.engine.break',event)
    }))
    this._subscriptions.add(context.onSessionEnd((event) => {
      this._emitter.emit('php-debug.engine.sessionEnd',event)
    }))
    this._subscriptions.add(context.onSessionStart((event) => {
      this._emitter.emit('php-debug.engine.sessionStart',event)
    }))
    this._subscriptions.add(context.onDestroyed((event) => {
      if (this._debugContexts != undefined && this._debugContexts != null) {
        if (this._services != undefined && this._services != null) {
          this._services.getDebugViewService().removeContext(event.context);
        }
        delete this._debugContexts[event.context];
        remainingContexts = Object.keys(this._debugContexts).length;
        if (remainingContexts == 0) {
          if (atom.config.get('php-debug.server.keepAlive') === true || atom.config.get('php-debug.server.keepAlive') === 1) {
            return;
          }
          if (this._server != undefined && this._server != null) {
            this._server.close()
          }
        }
      }
    }))
  }

  getGrammars() {
    return ["text.html.php"]
  }

  handleServerError(err) {
    if (this._services != undefined && this._services != null) {
      this._services.getLoggerService().warn("Server Error", err)
      if (this._services.hasService("Console")) {
        this._services.getConsoleService().broadcastMessage("Server Error: " + err)
      }
      for (let context in this._debugContexts) {
        this._debugContexts[context].stop()
      }
    }
  }
  handleServerListening () {
    if (this._services != undefined && this._services != null) {
      this._services.getLoggerService().info("Listening on " + this._server.getAddress() + ':' + this._server.getPort())
      if (this._services.hasService("Console")) {
        this._services.getConsoleService().broadcastMessage("Listening on Address:Port " + this._server.getAddress() +":" + this._server.getPort())
      }
    }
  }
  handleNewConnection(socket) {
    if (this._services != undefined && this._services != null) {
      this._services.getLoggerService().info("Session initiated")
      this.assignSocketToContext(socket)
    }
  }
  handleListenerClosed() {
    if (this._services != undefined && this._services != null) {
      this._services.getLoggerService().info("Listener Closed")
      if (this._services.hasService("Console")) {
        this._services.getConsoleService().broadcastMessage("No longer listening on Address:Port " + this._server.getAddress() +":" + this._server.getPort())
      }
      for (let context in this._debugContexts) {
        this._debugContexts[context].stop()
      }
    }
  }
  handleConnectionEnded(socket) {
    if (this._services != undefined && this._services != null) {
      this._services.getLoggerService().info("Connection Closed")
      const context = this.getContextForSocket(socket)
      if (context != null) {
        context.stop()
      }
    }
  }
  handleConnectionError(event) {
    if (this._services != undefined && this._services != null) {
      this._services.getLoggerService().warn("Connection error",event.error)
      const context = this.getContextForSocket(event.socket)
      if (context != null) {
        context.stop()
      }
    }
  }

  isDestroyed() {
    return this._isDestroyed
  }

  destroy(fromServiceManager) {
    this._destroyed = true
    if (this._server != undefined && this._server != null) {
      this._server.destroy()
      delete this._server
    }
    for (let context in this._debugContexts) {
      this._debugContexts[context].destroy()
      delete this._debugContexts[context]
    }
    delete this._debugContexts
    if (typeof this._emitter.destroy === "function") {
      this._emitter.destroy()
    }
    this._emitter.dispose()
    this._subscriptions.dispose()
  }

  dispose() {
    this.destroy()
  }

}
