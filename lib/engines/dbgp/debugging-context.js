'use babel'

import autoBind from 'auto-bind-inheritance'
import DbgpInstance from './dbgp-instance'
import {Emitter, Disposable} from 'event-kit'
import {CompositeDisposable} from 'atom'
import path from 'path'
import Promise from 'promise'
import PathMapsView from '../../pathmaps/pathmaps-view'
import helpers from '../../helpers'

export default class DebbuggingContext {
  constructor (services, identifier, uiService) {
    autoBind(this);
    this._emitter = new Emitter()
    this._services = services
    this._identifier = identifier
    this._uiService = uiService
    this._socket = null
    this._instance = null
    this._redirectingStdout = atom.config.get('php-debug.server.redirectStdout');
    this._redirectingStderr = atom.config.get('php-debug.server.redirectStderr');
    this._subscriptions = new CompositeDisposable()
    this._persistentSubscriptions = new CompositeDisposable()
    this.handleUIEvents();
  }

  getIdentifier() {
    return this._identifier
  }

  getUIService() {
    return this._uiService
  }

  setUIService(service) {
    this._uiService = service
    this.handleUIEvents();
    if (this.isValidForContext(this._identifier)) {
      if (!this._instance.isActive()) {
        if (this._services.hasService("Stack")) {
          this._services.getStackService().registerStack(this._identifier)
        }
        if (this._services.hasService("Console")) {
          this._services.getConsoleService().addMessage(this._identifier,"Session Initialized: " + this._identifier)
        }
        this._instance.activate()
      }
    }
  }

  activate(socket) {
    if (socket == undefined || socket == null) return
    if (this._socket != undefined && this._socket != null) {
      throw new Error("Cannot assign socket to an already bound context")
    }
    this._socket = socket
    if (this._subscriptions == undefined || this._subscriptions == null) {
      this._subscriptions = new CompositeDisposable()
    }
    this.bindEvents()

    this._subscriptions.add(this.onHandshakeStarted((event) => {
      if (this._services.hasService("Actions")) {
        this._services.getActionsService().registerButton("pathmaps", this._identifier, "debug", "Path Maps",["btn","mdi","mdi-map","inline-block-tight", "btn-no-deactive","pathmaps-btn"], (clickEvent) => {
            this.handlePathMapsClick(clickEvent.context, event.fileuri);
        })
        this._services.getActionsService().registerButton("redirect_stdout", this._identifier, "console", "Stdout",["btn","mdi","mdi-shuffle-variant","inline-block-tight", "btn-no-deactive","redirect-stdout-btn", this._redirectingStdout ? 'btn-active':''], (clickEvent) => {
            if (this.isValidForContext(this._identifier)) {
              this._redirectingStdout = !this._redirectingStdout
              if (this._redirectingStdout) {
                this._services.getActionsService().updateButton("redirect_stdout", this._identifier, "console", "Stdout",["btn","mdi","mdi-shuffle-variant","inline-block-tight", "btn-no-deactive","redirect-stdout-btn","btn-active"]);
                this._services.getLoggerService().info("Redirecting Stdout")
                this._instance.setStdout(1)
              } else {
                this._services.getActionsService().updateButton("redirect_stdout", this._identifier, "console", "Stdout",["btn","mdi","mdi-shuffle-variant","inline-block-tight", "btn-no-deactive","redirect-stdout-btn"]);
                this._services.getLoggerService().info("No longer redirecting Stdout")
                this._instance.setStdout(0)
              }
            }
        })
        this._services.getActionsService().registerButton("redirect_stderr", this._identifier, "console", "Stderr",["btn","mdi","mdi-shuffle-variant","inline-block-tight", "btn-no-deactive","redirect-stderr-btn", this._redirectingStdout ? 'btn-active':''], (clickEvent) => {
          if (this.isValidForContext(this._identifier)) {
            this._redirectingStderr = !this._redirectingStderr
            if (this._redirectingStderr) {
              this._services.getActionsService().registerButton("redirect_stderr", this._identifier, "console", "Stderr",["btn","mdi","mdi-shuffle-variant","inline-block-tight", "btn-no-deactive","redirect-stderr-btn","btn-active"]);
              this._services.getLoggerService().info("Redirecting Stderr")
              this._instance.setStderr(1)
            } else {
              this._services.getActionsService().registerButton("redirect_stderr", this._identifier, "console", "Stderr",["btn","mdi","mdi-shuffle-variant","inline-block-tight", "btn-no-deactive","redirect-stderr-btn"]);
              this._services.getLoggerService().info("No longer redirecting Stderr")
              this._instance.setStderr(0)
            }
          }
        })
      }
      var currentMaps = atom.config.get('php-debug.xdebug.pathMaps')
      if (currentMaps == undefined || currentMaps == null || currentMaps == "") {
        currentMaps = []
      } else {
        try {
          currentMaps = JSON.parse(currentMaps)
        } catch (err) {
          currentMaps = [];
          this._services.getLoggerService().info("Couldn't parse pathmaps");
        }
        if (typeof currentMaps !== "object") {
          currentMaps = []
        }
      }
      let requestListings = [];
      const rankedListing = helpers.generatePathMaps(event.fileuri, currentMaps)
      if (rankedListing.type !== undefined && rankedListing.type != null && rankedListing.type != "list") {
        if (rankedListing.results.localPath == "!") {
          event.preventDefault(null);
          if (this._instance != undefined && this._instance != null) {
            this._instance.executeDetach()
          }
          return;
        }
        this._instance.setPathMap(rankedListing.results)

        this.checkBreakpointPathMaps(requestListings, currentMaps);
        if (requestListings == 0) {
          return
        }
      } else {
        requestListings.push({path:event.fileuri, rankedListing: rankedListing});
        this.checkBreakpointPathMaps(requestListings, currentMaps);
      }

      const serialize = (funcs) => {
        return funcs.reduce((promise,func) =>
          promise.then((result) => func().then(Array.prototype.concat.bind(result))),
          Promise.resolve([]))
      };

      const funcs = requestListings.map(rl => () => new Promise((fulfill,reject) => {
        if (helpers.hasLocalPathMap(rl.path,this._instance.getPathMaps())) {
          fulfill();
          return;
        }
        this._pathMapsView = this.createPathmapsView(currentMaps, rl.rankedListing, fulfill, rl.path, true);
        this._pathMapsView.attach()
        })
      );

      var satisfyPromise = null
      var p = new Promise( (fulfill,reject) => {
        satisfyPromise = fulfill
      })
      event.preventDefault(p);
      serialize(funcs).then( () => {
        satisfyPromise();
      });
    }))

    this._subscriptions.add(this.onRequestPathMap((event) => {
      var currentMaps = atom.config.get('php-debug.xdebug.pathMaps')
      if (currentMaps == undefined || currentMaps == null || currentMaps == "") {
        currentMaps = []
      } else {
        try {
          currentMaps = JSON.parse(currentMaps)
        } catch (err) {
          currentMaps = []
          this._services.getLoggerService().info("Couldn't parse pathmaps")
        }
        if (typeof currentMaps !== "object") {
          currentMaps = []
        }
      }
      let searchPath = ""
      let flag = false;
      if (event.hasOwnProperty("remotePath")) {
        searchPath = event.remotePath;
      } else {
        searchPath = event.localPath;
        flag = true;
      }
      const rankedListing = helpers.generatePathMaps(searchPath, currentMaps, null, flag)
      if (rankedListing.type !== undefined && rankedListing.type != null && rankedListing.type != "list") {
        if (rankedListing.results.localPath == "!") {
          event.preventDefault(null);
          if (this._instance != undefined && this._instance != null) {
            this._instance.executeDetach()
          }
          return;
        }
        this._instance.setPathMap(rankedListing.results)
        return;
      }


      var satisfyPromise = null
      var p = new Promise( (fulfill,reject) => {
        satisfyPromise = fulfill
      })
      event.preventDefault(p);
      this._pathMapsView = this.createPathmapsView(currentMaps, rankedListing, satisfyPromise, searchPath, true);
      this._pathMapsView.attach()
    }))


    this._subscriptions.add(this.onHandshakeComplete((event) => {
      this._emitter.emit('php-debug.engine.internal.sessionStart',event)
      if (this._uiService == undefined || this._uiService == null) {
        this._identifier = event.appid
        if (this.isValidForContext(this._identifier)) {
          this._instance.updateContextIdentifier(event.appid)
        }
      } else {
        if (this.isValidForContext(this._identifier)) {
          if (this._services.hasService("Stack")) {
            this._services.getStackService().registerStack(this._identifier)
          }
          this._instance.activate()
          if (this._services.hasService("Console")) {
            this._services.getConsoleService().addMessage(this._identifier,"Session Initialized: " + this._identifier)
          }
        }
      }
    }))
    this._instance = new DbgpInstance({socket:socket, emitter:this._emitter, services:this._services, context:this._identifier})
  }

  checkBreakpointPathMaps(requestListings, currentMaps) {
    if (this._services.hasService("Breakpoints")) {
      let service = this._services.getBreakpointsService()
      let breakpoints = service.getBreakpoints()

      for (breakpoint of breakpoints) {
        let path = breakpoint.getPath()
        if (!helpers.hasLocalPathMap(path,this._instance.getPathMaps())) {
          const bprankedListing = helpers.generatePathMaps(path, currentMaps, null, true)
          if (bprankedListing.type !== undefined && bprankedListing.type != null && bprankedListing.type != "list") {
            this._instance.setPathMap(bprankedListing.results)
          } else {
            let add = true;
            for (let rl of requestListings) {
              if (rl.path == path) {
                add = false;
                break;
              }
            }
            if (add) {
              requestListings.push({path:path, rankedListing: bprankedListing})
            }
          }
        }
      }
    }
  }

  handlePathMapsClick(context, fileuri) {
    if (this._pathMapsView != undefined || this._pathMapsView != null) {
      return;
    }
    if (this._identifier != context) {
      return
    }
    var currentMaps = atom.config.get('php-debug.xdebug.pathMaps')
    if (currentMaps == undefined || currentMaps == null || currentMaps == "") {
      currentMaps = []
    } else {
      try {
        currentMaps = JSON.parse(currentMaps)
      } catch (err) {
        currentMaps = []
        this._services.getLoggerService().info("Couldn't parse pathmaps")
      }
      if (typeof currentMaps !== "object") {
        currentMaps = []
      }
    }
    const rankedListing = helpers.generatePathMaps(fileuri, currentMaps, true)
    this._pathMapsView = this.createPathmapsView(currentMaps, rankedListing, null, null, false)
    this._pathMapsView.attach()
  }

  createPathmapsView(currentMaps, rankedListing, completionPromise, uri, showDetach) {
    var pathOptions = [];
    if (rankedListing.hasOwnProperty("list")) {
      pathOptions = rankedListing["list"].results;
    } else if (rankedListing.hasOwnProperty('type') && rankedListing.type == "list") {
      pathOptions = rankedListing.results;
    }
    var defaultValue = null;
    if (rankedListing.hasOwnProperty("existing")) {
      defaultValue = rankedListing["existing"].results
    }  else if (rankedListing.hasOwnProperty("direct")) {
      defaultValue = rankedListing["direct"].results
    }
    var options = {
      onCancel: () => {
          if (this._instance != undefined && this._instance != null) {
            this._instance.executeDetach()
          }
      },
      onIgnore: (mapping, previous) => {
        atom.config.set('php-debug.xdebug.pathMaps',JSON.stringify(currentMaps))
        if (this._instance != undefined && this._instance != null) {
          mapping.localPath = "!"
          this.updatePathmapsConfig(mapping, previous, currentMaps)
          this._instance.executeDetach()
        }
      },
      showDetach: showDetach,
      pathOptions:pathOptions,
      default: defaultValue,
      uri: uri,
      onSave: (mapping, previous) => {
        this.updatePathmapsConfig(mapping, previous, currentMaps)
        if (this._instance != undefined && this._instance != null) {
          this._instance.setPathMap(mapping)
        }
        if (completionPromise != undefined && completionPromise != null) {
          completionPromise()
        }
        this._pathMapsView.destroy()
        delete this._pathMapsView
      }
    }
    return new PathMapsView(options)
  }

  updatePathmapsConfig(mapping, previous, currentMaps) {
    var replaced = false;
    if (previous != undefined && previous != null) {
      if (mapping.remotePath != "" || mapping.localPath != "") {
        for (let mapItem in currentMaps) {
          if (currentMaps[mapItem] == previous) {
            currentMaps[mapItem] = mapping
            replaced = true;
            break;
          }
        }
      }
    }
    if (!replaced) {
      if (mapping.remotePath != "" || mapping.localPath != "") {
                  currentMaps.push(mapping)
      }
    }
    atom.config.set('php-debug.xdebug.pathMaps',JSON.stringify(currentMaps))
  }

  bindEvents() {
    if (this._subscriptions == undefined || this._subscriptions == null) {
      this._subscriptions = new CompositeDisposable()
    }
    this._subscriptions.add(this.onSessionEnd( (event) => {
      if (this._services != undefined && this._services != null) {
        this._services.getLoggerService().info("Session Ended",event)
        if (this._services.hasService("Console")) {
          this._services.getConsoleService().addMessage(this._identifier,"Session Terminated: " + this._identifier)
        }
      }
      this.stop()
    }))
    this._subscriptions.add(this.onSessionStart( (event) => {
      if (this._services.hasService("Status")) {
        this._services.getStatusService().setStatus(this._identifier,"Session Started")
      }
    }))
    this._subscriptions.add(this.onBreak( (event) => {
      if (this._services.hasService("Console")) {
        if (event.breakpoint != undefined && event.breakpoint != null) {
          let exceptionType = event.breakpoint.getSettingValue("exceptionType");
          if (exceptionType != null) {
            this._services.getConsoleService().addMessage(this._identifier,"Breakpoint hit: EXCEPTION " + exceptionType + " " + event.breakpoint.toString())
          } else {
            this._services.getConsoleService().addMessage(this._identifier,"Breakpoint hit: " + event.breakpoint.toString())
          }
        }
      }
      if (this._services.hasService("Status")) {
        if (event.breakpoint != undefined && event.breakpoint != null) {
          let exceptionType = event.breakpoint.getSettingValue("exceptionType");
          if (exceptionType != null) {
            this._services.getStatusService().setStatus(this._identifier,"Session Active: BREAK - " + exceptionType)
            return;
          }
        }
        this._services.getStatusService().setStatus(this._identifier,"Session Active: BREAK")
      }
    }))
    this._subscriptions.add(this.onDebugDBGPMessage( (event) => {
      switch (event.type) {
        case "recieved":
              this._services.getLoggerService().debug("XDebug ->", event.context, event.message)
              break;
        case "raw-recieved":
              this._services.getLoggerService().debug("XDebug RAW -> ", event.context, event.message)
              break;
        case "sent":
              this._services.getLoggerService().debug("XDebug <-", event.context, event.message)
              break;
        default:
              this._services.getLoggerService().debug("XDebug <->", event.context, event.message)
              break;
      }
    }))
    if (this._services.hasService("Stack")) {
      this._subscriptions.add(this._services.getStackService().onFrameSelected((event) => {
        if (this._instance != undefined && this._instance != null) {
          if (this.isValidForContext(event.context)) {
            this._services.getLoggerService().debug("Changing Stack",event)
            this._instance.syncCurrentContext(event.codepoint.getStackDepth());
            if (this._services.hasService("Breakpoints")) {
              let codepoint = this._services.getBreakpointsService().createCodepoint(helpers.remotePathToLocal(event.codepoint.getPath(), this._instance._pathMap), event.codepoint.getLine(), event.codepoint.getStackDepth())
              this._services.getBreakpointsService().doCodePoint(event.context, codepoint);
            }
          }
        }
      }))
    }
    if (this._services.hasService("Console")) {
      this._subscriptions.add(this._services.getConsoleService().onExecuteExpression((event) => {
        if (this.isValidForContext(event.context)) {
          this._instance.evalExpression(event.expression).then((data) => {
            if (this._services.hasService("Console")) {
              this._services.getConsoleService().addMessage(this._identifier, data)
            }
          });
        }
      }))
    }
    if (this._services.hasService("Breakpoints")) {
        let service = this._services.getBreakpointsService()
        this._subscriptions.add(service.onBreakpointAdded((event) => {
          if (this.isValidForContext(this._identifier)) {
            this._instance.executeBreakpoint(event.added)
          }
        }))
        this._subscriptions.add(service.onBreakpointChanged((event) => {
          if (this.isValidForContext(this._identifier)) {
            this._instance.executeBreakpointRemove(event.breakpoint)
            this._instance.executeBreakpoint(event.breakpoint)
          }
        }))
        this._subscriptions.add(service.onBreakpointRemoved((event) => {
          if (this.isValidForContext(this._identifier)) {
            this._instance.executeBreakpointRemove(event.removed)
          }
        }))
        this._subscriptions.add(service.onBreakpointsCleared((event) => {
          if (this.isValidForContext(this._identifier)) {
            for (let breakpoint of event.removed) {
              this._instance.executeBreakpointRemove(breakpoint)
            }
          }
        }))
    }
    if (this._services.hasService("Watchpoints")) {
      let service = this._services.getWatchpointsService()
      this._subscriptions.add(service.onWatchpointAdded((event) => {
        if (this.isValidForContext(this._identifier)) {
          this._instance.executeWatchpoint(event.added)
        }
      }))
      this._subscriptions.add(service.onWatchpointRemoved((event) => {
        if (this.isValidForContext(this._identifier)) {
          this._instance.executeWatchpointRemove(event.removed)
        }
      }))
      this._subscriptions.add(service.onWatchpointsCleared((event) => {
        if (this.isValidForContext(this._identifier)) {
          for (let watchpoint of event.removed) {
            this._instance.executeWatchpointRemove(watchpoint)
          }
        }
      }))
    }
    if (this._services.hasService("Actions")) {
      let service = this._services.getActionsService()
      this._subscriptions.add(service.onContinue((event) => {
        if (this.isValidForContext(event.context)) {
          this._instance.continueExecution('run')
        }
      }))
      this._subscriptions.add(service.onStepOver((event) => {
        if (this.isValidForContext(event.context)) {
          this._instance.continueExecution('step_over')
        }
      }))
      this._subscriptions.add(service.onDetach((event) => {
        if (this.isValidForContext(event.context)) {
          this._instance.executeDetach()
        }
      }))
      this._subscriptions.add(service.onStepInto((event) => {
        if (this.isValidForContext(event.context)) {
          this._instance.continueExecution('step_into')
        }
      }))
      this._subscriptions.add(service.onStepOut((event) => {
        if (this.isValidForContext(event.context)) {
          this._instance.continueExecution('step_out')
        }
      }))
      this._subscriptions.add(service.onStop((event) => {
        if (this.isValidForContext(event.context)) {
          this._instance.executeStopDetach()
        }
      }))
    }
  }

  handleUIEvents() {
    if (this.hasUIService()) {
      this._persistentSubscriptions.add(this._uiService.onDebuggerDeactivated((e) => {
        if (e.close) {
          if (!this._uiService.hasPanels()) {
            this._uiService.destroy()
            this.destroy()
          }
        }
      }));
      this._persistentSubscriptions.add(this._uiService.onConsoleDeactivated((e) => {
        if (e.close) {
          if (!this._uiService.hasPanels()) {
            this._uiService.destroy()
            this.destroy()
          }
        }
      }));
      this._persistentSubscriptions.add(this._uiService.onDestroyed((e) => {
        this.destroy()
      }));
    }
  }

  executeRun() {
    if (this.isValid()) {
      return this._instance.continueExecution('run')
    }
  }

  evalExpression(expression) {
    if (this.isValid()) {
      return this._instance.evalExpression(expression);
    }
  }

  executeStepInto() {
    if (this.isValid()) {
      return this._instance.continueExecution('step_into')
    }
  }

  executeStepOver() {
    if (this.isValid()) {
      return this._instance.continueExecution('step_over')
    }
  }

  executeStepOut() {
    if (this.isValid()) {
      return this._instance.continueExecution('step_out')
    }
  }

  isValid() {
    return (this._instance != undefined && this._instance != null && this.isActive())
  }

  isValidForContext(context) {
    return (context == this._identifier && this._instance != undefined && this._instance != null && this.isActive())
  }

  hasUIService() {
    return this._uiService != undefined && this._uiService != null
  }

  isActive() {
    return this._socket != undefined && this._socket != null
  }

  getSocket() {
    return this._socket
  }

  onSessionStart(callback) {
    return this._emitter.on('php-debug.engine.internal.sessionStart', callback)
  }

  onDebugDBGPMessage(callback) {
    return this._emitter.on('php-debug.engine.internal.debugDBGPMessage', callback)
  }

  onHandshakeStarted(callback) {
    return this._emitter.on('php-debug.engine.internal.handshakeStarted', callback)
  }

  onRequestPathMap(callback) {
    return this._emitter.on('php-debug.engine.internal.requestPathMap', callback)
  }

  onHandshakeComplete(callback) {
    return this._emitter.on('php-debug.engine.internal.handshakeComplete', callback)
  }

  onReceivedDBGPMessage(callback) {
    return this._emitter.on('php-debug.engine.internal.receivedDBGPMessage', callback)
  }

  onRunning(callback) {
    return this._emitter.on('php-debug.engine.internal.running', callback)
  }

  onBreak(callback) {
    return this._emitter.on('php-debug.engine.internal.break', callback)
  }

  onSessionEnd(callback) {
    return this._emitter.on('php-debug.engine.internal.sessionEnd', callback)
  }

  onDestroyed(callback) {
    return this._emitter.on('php-debug.engine.internal.destroyed', callback)
  }

  stop() {
    if (this.isValidForContext(this._identifier)) {
      if (this._services.hasService("Status")) {
        this._services.getStatusService().setStatus(this._identifier,"Session Ended, Listening for new sessions")
      }
      if (this._services.hasService("Scope")) {
          this._services.getScopeService().clearScopes(this._identifier)
      }
      if (this._services.hasService("Stack")) {
        this._services.getStackService().unregisterStack(this._identifier)
      }
      if (this._instance != undefined && this._instance != null) {
        this._instance.destroy()
        delete this._instance
      }
      if (this._socket != undefined && this._socket != null) {
        delete this._socket
      }
      if (this._subscriptions != undefined && this._subscriptions != null) {
        this._subscriptions.dispose()
        delete this._subscriptions;
      }
    }
  }

  destroy() {
    this.stop()
    delete this._uiService
    delete this._services
    if (this._emitter != undefined && this._emitter != null) {
      this._emitter.emit('php-debug.engine.internal.destroyed', {context:this._identifier})
    }
    delete this._identifier
    delete this._subscriptions

    if (this._persistentSubscriptions != undefined && this._persistentSubscriptions != null) {
      this._persistentSubscriptions.dispose()
      delete this._persistentSubscriptions;
    }

    if (this._emitter != undefined && this._emitter != null) {
      if (typeof this._emitter.destroy === "function") {
        this._emitter.destroy()
      }
      this._emitter.dispose()
    }
    delete this._emitter

  }

  dispose() {
    this.destroy()
  }

}
