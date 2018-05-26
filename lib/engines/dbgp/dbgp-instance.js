'use babel'

import {parseString} from 'xml2js'
import Promise from 'promise'
import {Emitter, Disposable} from 'event-kit'
import {escapeValue, localPathToRemote, remotePathToLocal, hasRemotePathMap, hasLocalPathMap, createPreventableEvent} from '../../helpers'
import autoBind from 'auto-bind-inheritance'

export default class DbgpInstance {
  constructor (params) {
    autoBind(this);
    this._isActive = false
    this._initComplete = false
    this._socket = params.socket
    this._emitter = params.emitter
    this._services = params.services
    this._context = params.context
    this._pathMaps = []
    if (this._context == undefined || this._context == null || this._context.trim() == "") {
      throw new Error("Context cannot be empty")
    }
    this._activationQueue = []
    this._promises = []
    this._socket.on('data', this.handleData)
    this._bufferSize = 32
    this._buffers = new Array(this._bufferSize)
    this._bufferIdx = 0
    this._currentBufferReadIdx = 0
    this._bufferReadIdx = 0
    this._breakpointMap = {}
    this._sessionEnded = false
  }

  stop () {
    try {
      this._socket.end()
    } catch (err) {
      // Supress
    }
    if (!this._sessionEnded) {
      this._sessionEnded = true
      this._emitter.emit('php-debug.engine.internal.sessionEnd',{context:this.getContext()})
    }
  }

  destroy() {
    this.executeStop()
    delete this._socket
    this._isActive = false
    delete this._services
    delete this._context
    delete this._promises
    delete this._buffers
    delete this._breakpointMap
    delete this._activationQueue
  }

  syncStack (depth) {
    let options = {}
    if (depth < 0) {
      depth = 0
    }
    return new Promise((fulfill,reject) => {
      this.executeCommand('stack_get', options).then((data) => {
        let stackFrames = []
        if (data.response.stack) {
          for (frame of data.response.stack) {
            let csonFrame = {
              id:       frame.$.level,
              label:    frame.$.where,
              filepath: frame.$.filename,
              level:    frame.$.level,
              line:     frame.$.lineno,
              active:   parseInt(frame.$.level,10) == depth ? true : false
            }
            stackFrames.push(csonFrame)
          }
        }
        fulfill(stackFrames)
      });
    });
  }

  updateContextIdentifier(context) {
    if (context == undefined || context == null || context.trim() == "") {
      throw new Error("Context cannot be empty")
    }
    this._context = context
  }

  isActive() {
    return this._isActive
  }

  getContext() {
    return this._context
  }

  setPathMap(mapping) {
    for (let existing of this._pathMaps) {
      if (existing.remotePath == mapping.remotePath) {
        existing.localPath = mapping.localPath;
        return;
      }
    }
    this._pathMaps.push(mapping);
  }

  getPathMaps() {
    return this._pathMaps;
  }

  isInternallyActive() {
    return this._isActive || this._initComplete == false
  }

  activate() {
    this._isActive = true
    while (this._activationQueue.length > 0) {
      this.parseResponse(this._activationQueue.shift())
    }
  }

  nextTransactionId () {
    if (!this._transaction_id) {
      this._transaction_id = 1
    }
    return this._transaction_id++
  }

  parse () {
    var message = "";
    var messageLength = 0;
    var tempBuffer = null;
    var writeIdx = 0
    while (this._bufferReadIdx < this._bufferIdx) {
      //console.log("buffers",this._buffers);
      //console.log("buffers",this._bufferReadIdx,this._bufferIdx);
      let buffer = this._buffers[this._bufferReadIdx % this._bufferSize];
      //console.log("1.buffer.length",buffer.length, this._bufferReadIdx % this._bufferSize, this._bufferIdx % this._bufferSize);
      let idx = this._currentBufferReadIdx;
      //while (buffer.split("\0").length >= 2) {
      if (messageLength == 0) {
        // Read Length
        while (idx <= buffer.length)  {
          if (buffer[idx] === 0) {
            messageLength = buffer.toString('utf8',this._currentBufferReadIdx, idx)
            break;
          }
          idx++
        }
        messageLength = parseInt(messageLength);
        if (messageLength == 0) return;
        // Skip null zero
        idx++;
      }
      if ((buffer.length - idx) < (messageLength - writeIdx)) {
        // WARNING If a message is split over 3 or more packets
        // but the come two together and then one later
        // I believe this could result in a bug, we'd lose
        // tempBuffer. I'm not sure if this would actually
        // happen in practice though
        if (this._bufferIdx <= (this._bufferReadIdx + 1)) {
          return;
        } else {
          let available = (buffer.length - idx) + writeIdx;
          let tmpIdx = this._bufferReadIdx + 1;
          while (tmpIdx < this._bufferIdx) {
            available = available + this._buffers[tmpIdx % this._bufferSize].length;
            tmpIdx++;
          }
          if (available < messageLength) {
            return;
          }
        }
        if (tempBuffer == null) {
          tempBuffer = Buffer.allocUnsafe(messageLength);
        }
        buffer.copy(tempBuffer, writeIdx, idx, buffer.length);
        this._buffers[this._bufferReadIdx % this._bufferSize] = null;
        writeIdx = writeIdx + (buffer.length - idx);
        buffer = null;
        this._currentBufferReadIdx = 0;
        this._bufferReadIdx++;
        continue;
      }

      if (tempBuffer != null) {
        buffer.copy(tempBuffer, writeIdx, 0, (messageLength-writeIdx));
        idx = idx + (messageLength-writeIdx);
        //console.log("tmp2:",tempBuffer.length, writeIdx, (messageLength-writeIdx), idx)
        //console.log(tempBuffer);
        message = tempBuffer.toString("utf8", 0, tempBuffer.length);
      } else {
        message = buffer.toString("utf8", idx, messageLength+idx);
        idx = messageLength+idx
      }
      // Post message null zero
      idx++;
      //console.log("messagelenght",messageLength);
      //console.log("message",message);
      //console.log("message.length",message.length);
      if (atom.config.get("php-debug.server.protocolDebugging")) {
        this._emitter.emit('php-debug.engine.internal.debugDBGPMessage',{context:this.getContext(),message:message,type:"recieved"})
      }
      this.parseXml(message);
      //console.log("idx",idx)
      //console.log("buffer.length",buffer.length);
      // Complete message would leave one null zero left over
      if (buffer.length > idx) {
        this._currentBufferReadIdx = idx;
        this.parse()
        break;
      } else {
        //console.log("parse complete");
        this._buffers[this._bufferReadIdx % this._bufferSize] = null;
        buffer = null;
        this._currentBufferReadIdx = 0;
        this._bufferReadIdx++;
        messageLength = 0;
        tempBuffer = null;
        writeIdx = 0
      }
    }
    //console.log("exiting parse");
  }

  parseXml(message) {
    let o = parseString(message, (err, result) => {
      if (err) {
        console.error(err)
      } else {
        if (result == undefined || result == null) {
          console.error("An unexpected parse error occurred, received null result set", message);
          console.trace();
          return;
        }
        if (typeof result !== "object" || Object.keys(result).length <= 0) {
          console.error("An unexpected parse error occurred, result set is not object", result, message);
          console.trace();
          return;
        }
        const type = Object.keys(result)[0]
        switch (type) {
          case "init":
           this.onInit(result)
           break;
          case "response":
            if (this.isInternallyActive()) {
              this.parseResponse(result)
            } else {
              this._activationQueue.push(result)
            }
            break;
          case "stream":
            this.parseStream(result)
            break;
        }
      }
    });
  }

  parseResponse (data) {
    const result = data.response.$
    const transactionId = result.transaction_id

    if (this._promises[transactionId] != undefined) {
      this._promises[transactionId](data)
      delete this._promises[transactionId]
    }
    else {
      console.warn("Could not find promise for transaction " + transactionId)
    }
  }

  parseStream (data) {
    const result = data.stream._
    var streamData = new Buffer(result, 'base64').toString('utf8')
    if (streamData != null && streamData != "") {
      if (this._services.hasService("Console")) {
        this._services.getConsoleService().addMessage(this.getContext(), streamData)
      }
    }
  }

  handleData (data) {
    if (this._buffers == undefined || this._buffers == null) {
      return;
    }
    if (data == null) {
      console.error("null data package");
      return;
    }
    if (atom.config.get("php-debug.server.protocolDebugging")) {
      this._emitter.emit('php-debug.engine.internal.debugDBGPMessage',{context:this.getContext(),message:data.toString('hex'),type:"raw-recieved"})
    }
    this._buffers[this._bufferIdx++ % this._bufferSize] = data
    try {
      this.parse()
    } catch (err) {
      console.error("An unexpected parse error occurred, exception during parsing");
      console.error(err);
    }
  }

  executeCommand (command, options, data) {
    return this.command(command, options, data)
  }

  command (command, options, data) {
    let transactionId = this.nextTransactionId()
    return new Promise((fulfill,reject) => {
      if (this._promises == undefined || this._promises == null) {
        if (atom.config.get("php-debug.server.protocolDebugging")) {
          this._emitter.emit('php-debug.engine.internal.debugDBGPMessage',{context:this.getContext(),message:"socket already closed",type:"sent"})
        }
        fulfill(null)
        return
      }
      this._promises[transactionId] = fulfill
      if (command == "stop" && (this._socket == undefined || this._socket == null || !this._socket.writable)) {
        if (atom.config.get("php-debug.server.protocolDebugging")) {
          this._emitter.emit('php-debug.engine.internal.debugDBGPMessage',{context:this.getContext(),message:"socket already closed",type:"sent"})
        }
        delete this._promises[transactionId]
        fulfill(null)
        return
      }

      let payload = command + " -i " + transactionId
      if (options && Object.keys(options).length > 0) {
        let argu = []
        for (arg in options) {
          let val = options[arg]
          argu.push("-"+(arg) + " " + escapeValue(val))
        }
        //argu = ("-"+(arg) + " " + encodeURI(val) for arg, val of options)
        argu2 = argu.join(" ")
        payload += " " + argu2
      }
      if (data) {
        payload += " -- " + new Buffer(data, 'utf8').toString('base64')
      }
      if (this._socket != undefined && this._socket != null) {
        try {
          this._socket.write(payload + "\0")
          if (atom.config.get("php-debug.server.protocolDebugging")) {
            this._emitter.emit('php-debug.engine.internal.debugDBGPMessage',{context:this.getContext(),message:payload,type:"sent"})
          }
        } catch (error) {
          console.error("Write error", error)
          delete this._promises[transactionId]
          reject(error)
        }
      } else {
        console.error("No socket found")
        delete this._promises[transactionId]
        reject("No socket found")
      }
    })
  }

  getFeature (feature_name) {
    return this.command("feature_get", {n: feature_name})
  }

  setFeature (feature_name, value) {
    return this.command("feature_set", {n: feature_name, v: value})
  }

  setStdout (value) {
    return this.command("stdout", {c: value})
  }

  setStderr (value) {
    return this.command("stderr", {c: value})
  }

  onInit (data) {
    var handshakeStartedEvent = createPreventableEvent();
    // Not sure exactly what xdebug is trying to accomplish here so just ignore
    // these connections
    if (data.init.$.fileuri == "dbgp://stdin") {
      return this.command("detach");
    }
    this.setFeature('show_hidden', 1)
    .then( () => {
      handshakeStartedEvent = Object.assign(handshakeStartedEvent,{context:this.getContext(),fileuri:data.init.$.fileuri,idekey:data.init.$.idekey,appid:data.init.$.appid,"language":data.init.$.language,"version":data.init.$["xdebug:language_version"]})
      this._emitter.emit('php-debug.engine.internal.handshakeStarted',handshakeStartedEvent)
    })
    .then( () => {
      return this.getFeature('supported_encodings')
    })
    .then( () => {
      return this.getFeature('supports_async')
    })
    .then( () => {
      return this.setFeature('encoding', 'UTF-8')
    })
    .then( () => {
      return this.setFeature('max_depth', atom.config.get('php-debug.xdebug.maxDepth'))
    })
    .then( () => {
      return this.setFeature('max_data', atom.config.get('php-debug.xdebug.maxData'))
    })
    .then( () => {
      return this.setFeature('max_children', atom.config.get('php-debug.xdebug.maxChildren'))
    })
    .then( () => {
      if (atom.config.get('php-debug.xdebug.multipleSessions') === true || atom.config.get('php-debug.xdebug.multipleSessions') === 1) {
        return this.setFeature('multiple_sessions', 1)
      } else {
        return this.setFeature('multiple_sessions', 0)
      }
    })
    .then( () => {
      return this.setStdout('stdout', atom.config.get('php-debug.server.redirectStdout') ? 1 : 0)
    })
    .then( () => {
      return this.setStderr('stderr', atom.config.get('php-debug.server.redirectStderr') ? 1 : 0)
    })
    .then( () => {
      return new Promise( (fulfill,reject) =>{
        if (handshakeStartedEvent.isDefaultPrevented()) {
          if (handshakeStartedEvent.getPromise() == null) {
            reject("Session rejected")
            return;
          }
          handshakeStartedEvent.getPromise().then( () => {
            fulfill(this.sendAllBreakpoints())
          })
        } else {
          fulfill(this.sendAllBreakpoints())
        }
      })
    })
    .then( () => {
      return this.sendAllWatchpoints()
    })
    .then( () => {
      this._initComplete = true
      this._emitter.emit('php-debug.engine.internal.handshakeComplete',{context:this.getContext(),fileuri:data.init.$.fileuri,idekey:data.init.$.idekey,appid:data.init.$.appid,"language":data.init.$.language,"version":data.init.$["xdebug:language_version"]})
      return this.executeRun()
    }).catch( (err) => {
      if (this._services != undefined && this._services != null && this._services.hasService("Logger")) {
        this._services.getLoggerService().error(err)
      } else {
        console.error(err)
      }
    })
  }

  sendAllBreakpoints () {
    let commands = []
    if (this._services.hasService("Breakpoints")) {
      let service = this._services.getBreakpointsService()
      let breakpoints = service.getBreakpoints()

      for (breakpoint of breakpoints) {
        commands.push(this.executeBreakpoint(breakpoint))
      }

      if (atom.config.get('php-debug.exceptions.fatalError')) {
        commands.push(this.executeBreakpoint(service.createBreakpoint(null, null, {type: "exception", exception: 'Fatal error', stackDepth: -1})))
      }
      if (atom.config.get('php-debug.exceptions.catchableFatalError')) {
        commands.push(this.executeBreakpoint(service.createBreakpoint(null, null, {type: "exception", exception: 'Catchable fatal error', stackDepth: -1})))
      }
      if (atom.config.get('php-debug.exceptions.warning')) {
        commands.push(this.executeBreakpoint(service.createBreakpoint(null, null, {type: "exception", exception: 'Warning', stackDepth: -1})))
      }
      if (atom.config.get('php-debug.exceptions.strictStandards')) {
        commands.push(this.executeBreakpoint(service.createBreakpoint(null, null, {type: "exception", exception: 'Strict standards', stackDepth: -1})))
      }
      if (atom.config.get('php-debug.exceptions.xdebug')) {
        commands.push(this.executeBreakpoint(service.createBreakpoint(null, null, {type: "exception", exception: 'Xdebug', stackDepth: -1})))
      }
      if (atom.config.get('php-debug.exceptions.unknownError')) {
        commands.push(this.executeBreakpoint(service.createBreakpoint(null, null, {type: "exception", exception: 'Unknown error', stackDepth: -1})))
      }
      if (atom.config.get('php-debug.exceptions.notice')) {
        commands.push(this.executeBreakpoint(service.createBreakpoint(null, null, {type: "exception", exception: 'Notice', stackDepth: -1})))
      }

      for (exception in atom.config.get('php-debug.exceptions.customExceptions')) {
        commands.push(this.executeBreakpoint(service.createBreakpoint(null, null, {type: "exception", exception: exception, stackDepth: -1})))
      }
    }

    return Promise.all(commands)
  }

  sendAllWatchpoints () {
    let commands = []
    if (this._services.hasService("Watchpoints")) {
      let service = this._services.getWatchpointsService()
      let watchpoints = service.getWatchpoints()

      for (watchpoint of watchpoints) {
        commands.push(this.executeWatchpoint(watchpoint))
      }
    }

    return Promise.all(commands)
  }

  executeWatchpoint (watchpoint) {
    let commandOptions = null
    let commandData = null
    commandOptions = {
      t: 'watch',
    }
    commandData = watchpoint.getExpression()
    let p =  this.command("breakpoint_set", commandOptions, commandData)
    return p.then( (data) => {
      this._breakpointMap[watchpoint.getId()] = data.response.$.id
    });
  }

  executeBreakpoint (breakpoint) {
    let commandOptions = null
    let commandData = null
    switch (breakpoint.getSettingValue("type")) {
      case "exception":
        commandOptions = {
          t: 'exception',
          x: breakpoint.getSettingValue('exception')
        }
        break;
      case "line":
      default:
        let path = breakpoint.getPath()
        path = localPathToRemote(path, this._pathMaps)
        commandOptions = {
          t: 'line',
          f: encodeURI(path),
          n: breakpoint.getLine()
        }
        let conditional = ""
        let idx = 0
        for (let setting of breakpoint.getSettingValues("condition")) {
          if (idx++ > 1) {
            conditional += " && "
          }
          conditional += "(" + setting.value + ")"
        }
        if (conditional != "") {
          commandData = conditional
        }
        break;

    }
    let p =  this.command("breakpoint_set", commandOptions, commandData)
    return p.then( (data) => {
      this._breakpointMap[breakpoint.getId()] = data.response.$.id
      // attempt to source a single line from the corresponding file where the breakpoint was made
      // if we're not successful then the user has probably screwed up their config and/or PathMaps
      if (breakpoint.getSettingValue("type") !== "exception") {
        let path = breakpoint.getPath()
        path = localPathToRemote(path, this._pathMaps)
        let options = {
          f : encodeURI(path),
          //beginnng line
          b : 1,
          //end line
          e : 1
        }
        // command documentation available at https://xdebug.org/docs-dbgp.php
        return this.command("source", options, null).then((data) => {
          if (data.response.hasOwnProperty("error")) {
            for (let error of data.response.error) {
              //handle other codes as appropriate, for now we have a generic handler
              if (error.$.code == "100") {
                atom.notifications.addError(`Breakpoints were set but the corresponding server side file ${path} couldn't be opened.`
                + ` Did you properly configure your PathMaps? Server message: ${error.message}, Code: ${error.$.code}`)
              } else {
                atom.notifications.addError(`A server side error occured. Please report this to https://github.com/gwomacks/php-debug. Server message: #{error.message}, Code: #{error.$.code}`)
              }
            }
          }
        });
      }
    });
  }

  executeBreakpointRemove (breakpoint) {
    options = {
      d: this._breakpointMap[breakpoint.getId()]
    }
    return this.command("breakpoint_remove", options)
  }

  executeWatchpointRemove (watchpoint) {
    options = {
      d: this._breakpointMap[watchpoint.getId()]
    }
    return this.command("breakpoint_remove", options)
  }

  continueExecution (type) {
    this._emitter.emit('php-debug.engine.internal.running', {context:this.getContext()})
    return this.command(type).then(
      (data) => {
        let response = data.response
        switch (response.$.status) {
          case 'break':
            let messages = response["xdebug:message"]
            let message = messages[0]
            let messageData = message.$
            //console.dir data
            let filepath = remotePathToLocal(decodeURI(messageData['filename']), this._pathMaps)

            let lineno = messageData['lineno']
            var type = 'break'
            var exceptionType = null
            if (messageData.exception) {
              if (message._) {
                if (this._services.hasService("Console")) {
                  this._services.getConsoleService().addMessage(this.getContext(), messageData.exception + ": " + message._)
                }
              }
              type = "error";
              exceptionType = messageData.exception;
            }
            if (this._services.hasService("Breakpoints")) {
              const breakpoint = this._services.getBreakpointsService().createBreakpoint(filepath,lineno,{type:type,exceptionType:exceptionType})
              this._emitter.emit('php-debug.engine.internal.break', {context:this.getContext(),breakpoint:breakpoint})
            }
            this.syncCurrentContext(-1)
            break;
          case 'stopping':
            this._emitter.emit('php-debug.engine.internal.sessionEnding', {context:this.getContext()})
            this.executeStop()
            break;
          default:
            console.dir(response)
            console.error("Unhandled status: " + response.$.status)
          }
    }).catch((err) => {
      if (this._services != undefined && this._services != null && this._services.hasService("Logger")) {
        this._services.getLoggerService().error(err)
      } else {
        console.error(err)
      }
    });
  }

  syncCurrentContext (depth) {
    let p2 = this.getContextNames(depth).then(
      (data) => {
        return this.processContextNames(depth,data)
    })

    let p3 = p2.then(
      (data) => {
        return this.updateWatches(data)
    })

    let p4 = p3.then (
      (data) => {
        return this.syncStack(depth)
    })

    let p5 = p4.then(
      (data) => {
        if (this._services.hasService("Stack")) {
          this._services.getStackService().setStack(this.getContext(), data)
        }
        return
    })

    return p5.done()
  }

  getContextNames (depth) {
    let options = {}
    if (depth >= 0) {
      options.d = depth
    }
    return this.command("context_names", options)
  }

  processContextNames (depth, data) {
    let commands = []
    for (let context of data.response.context) {
      if (this._services.hasService("Scope")) {
        const scopeService = this._services.getScopeService()
        scopeService.registerScope(this.getContext(), context.$.id, context.$.name)
        commands.push(this.updateContext(depth, context.$.id))
      }
    }
    return Promise.all(commands)
  }

  executeDetach () {
        this.command('detach').then((data) => {
            this.stop();
        });
        this.stop();
  }

  executeStopDetach () {
    this.command('status').then((data) => {
      if (data.response.$.status == 'break') {
        if (this._services.hasService("Breakpoints")) {
          let breakpoints = this._services.getBreakpointsService().getBreakpoints()
          for (let breakpoint of breakpoints) {
            this.executeBreakpointRemove(breakpoint)
          }
        }
        this.command('run').then((data) => {
          this.command('detach').then((data) => {
            this.executeStop()
          });
        });
      } else if (data.response.$.status == 'stopped') {
        this.executeStop()
      } else {
        this.command('detach').then((data) => {
            this.executeStop()
        });
      }
    });
  }

  updateWatches (data) {
    let commands = []
    if (this._services.hasService("Watches")) {
      for (watch of this._services.getWatchesService().getWatches()) {
        commands.push(this.evalWatch(watch))
      }
    }
    return Promise.all(commands)
  }


  evalExpression (expression) {
      let p = this.command("eval", null, expression)
      return p.then((data) => {
        let datum = null
        if (data.response.error) {
          datum = {
            name : "Error",
            fullname : "Error",
            type: "error",
            value: data.response.error[0].message[0],
            label: ""
          }
        } else {
          datum = this.parseVariableExpression(data.response.property[0])
        }
        if (typeof datum == "object" && datum.type == "error") {
          datum = datum.name + ": " + datum.value
        }
        //else
        //  datum = datum.replace(/\\"/mg, "\"").replace(/\\'/mg, "'").replace(/\\n/mg, "\n");
        return datum;
        //this.globalContext.notifyConsoleMessage(datum)
      });
  }

  evalWatch(watch) {
    let p = this.command("eval", null, watch.getExpression())
    return p.then((data) => {
      let datum = null
      if (data.response.error) {
        datum = {
          name : "Error",
          fullname : "Error",
          type: "error",
          value: data.response.error[0].message[0],
          label: ""
        }
      } else {
        datum = this.parseContextVariable(data.response.property[0])
      }
      datum.label = watch.getExpression()
      watch.setValue(this.getContext(), datum)
    });
  }

  updateContext (depth, scopeId) {
    let p = this.contextGet(depth, scopeId)
    return p.then( (data) => {
      let context = this.buildContext(data)
      if (this._services.hasService("Scope")) {
        this._services.getScopeService().setData(this.getContext(), scopeId, context)
      }
    });
  }

  contextGet (depth, scopeId) {
    let options = { c : scopeId }
    if (depth >= 0) {
      options.d = depth
    }
    return this.command("context_get", options)
  }

  buildContext (response) {
    let data = {}
    data.type = 'context'
    data.context = response.response.$.context
    data.variables = []
    if (response.response.property) {
      for (let property of response.response.property) {
        let v = this.parseContextVariable(property)
        data.variables.push(v)
      }
    }
    return data
  }

  executeRun () {
    return this.continueExecution("run")
  }

  executeStop () {
    if (this._socket != undefined && this._socket != null) {
      try {
        this.command("stop")
      } catch(err) {
        throw err
      } finally {
        this.stop()
      }
    }
  }

  parseVariableExpression (variable) {
    let result = ""
    if (variable.$.fullname) {
      result = "\"" + variable.$.fullname + "\" => "
    } else if (variable.$.name) {
      result = "\"" + variable.$.name  + "\" => "
    }

    switch (variable.$.type) {
      case "string":
        switch (variable.$.encoding) {
          case "base64":
            if (!variable._) {
              return result + '(string)""'
            } else {
              return result + '(string)"' + new Buffer(variable._, 'base64').toString('utf8') + '"'
            }
            break;
          default:
            console.error("Unhandled context variable encoding: " + variable.$.encoding)
        }
        break;
      case "array":
        {
          let values = ""
          if (variable.property) {
            for (let property of variable.property) {
              values += this.parseVariableExpression(property) + ",\n"
            }
            values = values.substring(0,values.length-2)
          }
          return result + "(array)[" + values + "] size("+variable.$.numchildren+")"
        }
        break;
      case "object":
        {
          let values = ""
          let className = "stdClass"
          if (variable.$.classname) {
            className = variable.$.classname
          }
          if (variable.property) {
            for (let property of variable.property) {
              values += this.parseVariableExpression(property) + ",\n"
            }
            values = values.substring(0,values.length-2)
          }
          return result + "(object["+className+"])" + values
        }
        break;
      case "resource":
        return result + "(resource)" + variable._
        break;
      case "int":
        return result + "(numeric)" + variable._
        break;
      case "error":
        return result + ""
        break;
      case "uninitialized":
        return result + "(undefined)null"
      case "null":
        return result + "(null)null"
      case "bool":
        return result + "(bool)" + variable._
      case "float":
        return result + "(numeric)" + variable._
      default:
        console.dir(variable)
        console.error("Unhandled context variable type: " + variable.$.type)
      }
    return datum
  }

  parseContextVariable (variable) {
    let datum = {
      name : variable.$.name,
      fullname : variable.$.fullname,
      type: variable.$.type
    }

    if (variable.$.name) {
      datum.label = variable.$.name
    } else if (variable.$.fullname) {
      datum.label = variable.$.fullname
    }

    switch (variable.$.type) {
      case "string":
        switch (variable.$.encoding) {
          case "base64":
            if (!variable._) {
              datum.value = ""
            } else {
              datum.value = new Buffer(variable._, 'base64').toString('utf8')
            }
            break;
          default:
            console.error("Unhandled context variable encoding: " + variable.$.encoding)
        }
        break;
      case "array":
        datum.value = []
        datum.length = variable.$.numchildren
        if (variable.property) {
          for (let property of variable.property) {
            datum.value.push(this.parseContextVariable(property))
          }
        }
        break;
      case "object":
        datum.value = []
        if (variable.$.classname) {
          datum.className = variable.$.classname
        }
        if (variable.property) {
          for (let property of variable.property) {
            datum.value.push(this.parseContextVariable(property))
          }
        }
        break;
      case "resource":
        datum.type = "resource"
        datum.value = variable._
        break;
      case "int":
        datum.type = "numeric"
        datum.value = variable._
        break;
      case "error":
        datum.value = ""
        break;
      case "uninitialized":
        datum.value = undefined
        break;
      case "null":
        datum.value = null
        break;
      case "bool":
        datum.value = variable._
        break;
      case "float":
        datum.type = "numeric"
        datum.value = variable._
        break;
      default:
        console.dir(variable)
        console.error("Unhandled context variable type: " + variable.$.type)
    }
    return datum
  }
}
