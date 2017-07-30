parseString = require('xml2js').parseString
Q = require 'q'
{Emitter, Disposable} = require 'event-kit'
helpers = require '../../helpers.coffee'

DebugContext = require '../../models/debug-context'
Watchpoint = require '../../models/watchpoint'
Breakpoint = require '../../models/breakpoint'

module.exports =
class DbgpInstance extends DebugContext
  constructor: (params) ->
    super
    @socket = params.socket
    @GlobalContext = params.context
    @promises = []
    @socket.on 'data', @stuff
    @emitter = new Emitter
    @buffer = ''
    @GlobalContext.addDebugContext(this)
    @GlobalContext.notifySessionStart()
    @breakpointMap = {}
    @socket.on "error", (error) =>
      console.error "Socket Error:",error
      @GlobalContext.notifySessionEnd()

  stop: ->
    @socket.end()
    @GlobalContext.notifySessionEnd()

  syncStack: (depth) ->
    options = {}
    #if depth >= 0
    #  options.d = depth;
    if depth < 0
      depth = 0
    return @executeCommand('stack_get', options).then (data) =>
      stackFrames = []
      if data.response.stack?
        for frame in data.response.stack
          csonFrame = {
            id:       frame.$.level
            label:    frame.$.where
            filepath: frame.$.filename
            line:     frame.$.lineno
            active:   if parseInt(frame.$.level,10) == depth then true else false
          }
          stackFrames.push csonFrame
      @setStack(stackFrames)

  nextTransactionId: ->
    if !@transaction_id
      @transaction_id = 1
    return @transaction_id++

  parse: (buffer) =>
    while buffer.split("\0").length >= 2
      n = buffer.indexOf("\0")
      len = parseInt(buffer.slice(0, n))
      if buffer.length >= n + len + 2
        message = buffer.slice(n+1, n+1+len)
        buffer = buffer.slice(n+2+len)
        if message != ""
          if atom.config.get("php-debug.DebugXDebugMessages")
            console.log("Received",message)
          o = parseString message, (err, result) =>
            if err
              console.error err
            else
              type = Object.keys(result)[0]
              switch type
                when "init" then @onInit result
                when "response"
                  @parseResponse result
      else
        return buffer
    return buffer

  parseResponse: (data) =>
    result = data.response.$
    transactionId = result.transaction_id

    if @promises[transactionId] != undefined
      @promises[transactionId].resolve(data)
      delete @promises[transactionId]
    else
      console.warn "Could not find promise for transaction " + transactionId


  stuff: (data) =>
    @buffer = message = @parse(@buffer + data)

  executeCommand: (command, options, data) ->
    @command(command, options, data)

  command: (command, options, data) =>
    transactionId = @nextTransactionId()
    deferred = Q.defer();
    @promises[transactionId] = deferred

    payload = command + " -i " + transactionId
    if options && Object.keys(options).length > 0
      argu = ("-"+(arg) + " " + helpers.escapeValue(val) for arg, val of options)
      #argu = ("-"+(arg) + " " + encodeURI(val) for arg, val of options)
      argu2 = argu.join(" ")
      payload += " " + argu2
    if data
      payload += " -- " + new Buffer(data, 'ascii').toString('base64')
    if @socket
      if atom.config.get("php-debug.DebugXDebugMessages")
        console.log("Sending",payload)
      @socket.write(payload + "\0")
    else
      console.error "No socket found"
    return deferred.promise

  getFeature: (feature_name) =>
    @command("feature_get", {n: feature_name})

  setFeature: (feature_name, value) =>
    return @command("feature_set", {n: feature_name, v: value})

  onInit: (data) =>
    console.log "init",data
    @setFeature('show_hidden', 1)
    .then () =>
      return @setFeature('max_depth', atom.config.get('php-debug.MaxDepth'))
    .then () =>
      return @setFeature('max_data', atom.config.get('php-debug.MaxData'))
    .then () =>
      return @setFeature('max_children', atom.config.get('php-debug.MaxChildren'))
    .then () =>
      return @setFeature('multiple_sessions', 0)
    .then () =>
      return @sendAllBreakpoints()
    .then () =>
      return @executeRun()


  sendAllBreakpoints: =>
    breakpoints = @GlobalContext.getBreakpoints()
    commands = []
    for breakpoint in breakpoints
      commands.push @executeBreakpoint(breakpoint)

    if atom.config.get('php-debug.PhpException.FatalError')
      commands.push @executeBreakpoint(new Breakpoint(type: Breakpoint.TYPE_EXCEPTION, exception: 'Fatal error', stackdepth: -1))
    if atom.config.get('php-debug.PhpException.CatchableFatalError')
      commands.push @executeBreakpoint(new Breakpoint(type: Breakpoint.TYPE_EXCEPTION, exception: 'Catchable fatal error', stackdepth: -1))
    if atom.config.get('php-debug.PhpException.Warning')
      commands.push @executeBreakpoint(new Breakpoint(type: Breakpoint.TYPE_EXCEPTION, exception: 'Warning', stackdepth: -1))
    if atom.config.get('php-debug.PhpException.StrictStandards')
      commands.push @executeBreakpoint(new Breakpoint(type: Breakpoint.TYPE_EXCEPTION, exception: 'Strict standards', stackdepth: -1))
    if atom.config.get('php-debug.PhpException.Xdebug')
      commands.push @executeBreakpoint(new Breakpoint(type: Breakpoint.TYPE_EXCEPTION, exception: 'Xdebug', stackdepth: -1))
    if atom.config.get('php-debug.PhpException.UnknownError')
      commands.push @executeBreakpoint(new Breakpoint(type: Breakpoint.TYPE_EXCEPTION, exception: 'Unknown error', stackdepth: -1))
    if atom.config.get('php-debug.PhpException.Notice')
      commands.push @executeBreakpoint(new Breakpoint(type: Breakpoint.TYPE_EXCEPTION, exception: 'Notice', stackdepth: -1))

    for exception in atom.config.get('php-debug.CustomExceptions')
      console.log exception
      commands.push @executeBreakpoint(new Breakpoint(type: Breakpoint.TYPE_EXCEPTION, exception: exception, stackdepth: -1))

    return Q.all(commands)

  executeBreakpoint: (breakpoint) =>
    switch breakpoint.getType()
      when Breakpoint.TYPE_LINE
        path = breakpoint.getPath()
        path = helpers.localPathToRemote(path)
        options = {
          t: 'line'
          f: encodeURI('file://' + path)
          n: breakpoint.getLine()
        }
        conditional = ""
        idx = 0
        data = null
        for setting in breakpoint.getSettingsValues("condition")
          if idx++ > 1
            conditional += " && "
          conditional += "(" + setting.value + ")"
        if !!conditional
          data = conditional
      when Breakpoint.TYPE_EXCEPTION
        options = {
          t: 'exception'
          x: breakpoint.getException()
        }
    p =  @command("breakpoint_set", options, data)
    return p.then (data) =>
      @breakpointMap[breakpoint.getId()] = data.response.$.id
      #attempt to source a single line from the corresponding file where the breakpoint was made
      #if we're not successful then the user has probably screwed up their config and/or PathMaps
      if breakpoint.getType() == Breakpoint.TYPE_LINE
        options = {
          f : encodeURI('file://' + path)
          #beginnng line
          b : 1
          #end line
          e : 1
        }
        #command documentation available at https://xdebug.org/docs-dbgp.php
        @command("source", options, null).then (data) =>
          if data.response.hasOwnProperty("error")
            for error in data.response.error
              #handle other codes as appropriate, for now we have a generic handler
              if error.$.code == "100"
                atom.notifications.addError("Breakpoints were set but the corresponding server side file #{path} couldn't be opened.
                Did you properly configure your PathMaps? Server message: #{error.message}, Code: #{error.$.code}")
              else
                atom.notifications.addError("A server side error occured. Please report this to https://github.com/gwomacks/php-debug. Server message: #{error.message}, Code: #{error.$.code}")


  executeBreakpointRemove: (breakpoint) =>
    path = breakpoint.getPath()
    path = helpers.localPathToRemote(path)
    options = {
      d: @breakpointMap[breakpoint.getId()]
    }
    return @command("breakpoint_remove", options)

  continue: (type) =>
    @GlobalContext.notifyRunning()
    return @command(type).then(
      (data) =>
        response = data.response
        switch response.$.status
          when 'break'
            messages = response["xdebug:message"]
            message = messages[0]
            thing = message.$
            #console.dir data
            filepath = decodeURI(thing['filename']).replace("file:///", "")

            if not filepath.match(/^[a-zA-Z]:/)
              filepath = '/' + filepath

            lineno = thing['lineno']
            type = 'break'
            if thing.exception
              if (message._)
                @GlobalContext.notifyConsoleMessage(message._)
              type = "error"
            breakpoint = new Breakpoint(filepath: filepath, line:lineno, type: type)
            @GlobalContext.notifyBreak(breakpoint)
          when 'stopping'
            @executeStop()
          else
            console.dir response
            console.error "Unhandled status: " + response.$.status
    )

  syncCurrentContext: (depth) ->
    p2 = @getContextNames(depth).then(
      (data) =>
        return @processContextNames(depth,data)
    )

    p3 = p2.then(
      (data) =>
        return @updateWatchpoints(data)
    )

    p4 = p3.then (
      (data) =>
        @syncStack(depth)
    )

    p5 = p4.then(
      (data) =>
        return @GlobalContext.notifyContextUpdate()
    )

    p5.done()

  getContextNames: (depth) ->
    options = {}
    if depth >= 0
      options.d = depth
    return @command("context_names", options)

  processContextNames: (depth, data) =>
    for context in data.response.context
      @addScope(context.$.id,context.$.name)
    commands = []
    scopes = @getScopes()
    for index, scope of scopes
      commands.push(@updateContext(depth, scope))
    return Q.all(commands)

  executeDetach: () =>
    @command('status').then (data) =>
      if data.response.$.status == 'break'
        breakpoints = @GlobalContext.getBreakpoints()
        for breakpoint in breakpoints
          @executeBreakpointRemove(breakpoint)
        @command('run').then (data) =>
          @command('detach').then (data) =>
              @executeStop()
      else if data.response.$.status == 'stopped'
        @executeStop()
      else
        @command('detach').then (data) =>
            @executeStop()

  updateWatchpoints: (data) =>
    @clearWatchpoints()
    commands = []
    for watch in @GlobalContext.getWatchpoints()
      commands.push @evalWatchpoint(watch)
    return Q.all(commands)


  evalExpression: (expression) ->
      p = @command("eval", null, expression)
      return p.then (data) =>
        datum = null
        if data.response.error
          datum = {
            name : "Error"
            fullname : "Error"
            type: "error"
            value: data.response.error[0].message[0]
            label: ""
          }
        else
          datum = @parseVariableExpression({variable:data.response.property[0]})
        if (typeof datum is "object" && datum.type == "error")
          datum = datum.name + ": " + datum.value
        #else
        #  datum = datum.replace(/\\"/mg, "\"").replace(/\\'/mg, "'").replace(/\\n/mg, "\n");
        @GlobalContext.notifyConsoleMessage(datum)

  evalWatchpoint: (watchpoint) ->
    p = @command("eval", null, watchpoint.getExpression())
    return p.then (data) =>
      datum = null
      if data.response.error
        datum = {
          name : "Error"
          fullname : "Error"
          type: "error"
          value: data.response.error[0].message[0]
          label: ""
        }
      else
        datum = @parseContextVariable({variable:data.response.property[0]})
      datum.label = watchpoint.getExpression()
      watchpoint.setValue(datum)
      @addWatchpoint(watchpoint)

  updateContext: (depth, scope) =>
    p = @contextGet(depth,scope.scopeId)
    return p.then (data) =>
      context = @buildContext data
      @setScopeContext(scope.scopeId, context)

  contextGet: (depth, scope) =>
    options = { c : scope }
    if depth >= 0
      options.d = depth
    return @command("context_get", options)

  buildContext: (response) =>
    data = {}
    data.type = 'context'
    data.context = response.response.$.context
    data.variables = []
    if response.response.property
      for property in response.response.property
        v = @parseContextVariable({variable:property})
        data.variables.push v
      return data

  executeRun: () =>
    return @continue("run")

  executeStop: () =>
    @command("stop")
    @stop()

  parseVariableExpression: ({variable}) ->
    result = ""
    if variable.$.fullname?
      result = "\"" + variable.$.fullname + "\" => "
    else if variable.$.name?
      result = "\"" + variable.$.name  + "\" => "



    switch variable.$.type
      when "string"
        switch variable.$.encoding
          when "base64"
            if not variable._?
              return result + '(string)""'
            else
              return result + '(string)"' + new Buffer(variable._, 'base64').toString('ascii') + '"'
          else
            console.error "Unhandled context variable encoding: " + variable.$.encoding
      when "array"
        values = ""
        if variable.property
          for property in variable.property
            values += @parseVariableExpression({variable:property}) + ",\n"
          values = values.substring(0,values.length-2)
        return result + "(array)[" + values + "] size("+variable.$.numchildren+")"
      when "object"
        values = ""
        className = "stdClass"
        if variable.$.classname
          className = variable.$.classname
        if variable.property
          for property in variable.property
            values += @parseVariableExpression({variable:property}) + ",\n"
          values = values.substring(0,values.length-2)
        return result + "(object["+className+"])" + values
      when "resource"
        return result + "(resource)" + variable._
      when "int"
        return result + "(numeric)" + variable._
      when "error"
        return result + ""
      when "uninitialized"
        return result + "(undefined)null"
      when "null"
        return result + "(null)null"
      when "bool"
        return result + "(bool)" + variable._
      when "float"
        return result + "(numeric)" + variable._
      else
        console.dir variable
        console.error "Unhandled context variable type: " + variable.$.type
    return datum

  parseContextVariable: ({variable}) ->
    datum = {
      name : variable.$.name
      fullname : variable.$.fullname
      type: variable.$.type
    }

    if variable.$.fullname?
      datum.label = variable.$.fullname
    else if variable.$.name?
      datum.label = variable.$.name

    switch variable.$.type
      when "string"
        switch variable.$.encoding
          when "base64"
            if not variable._?
              datum.value = ""
            else
              datum.value = new Buffer(variable._, 'base64').toString('ascii')
          else
            console.error "Unhandled context variable encoding: " + variable.$.encoding
      when "array"
        datum.value = []
        datum.length = variable.$.numchildren
        if variable.property
          for property in variable.property
            datum.value.push @parseContextVariable({variable:property})
      when "object"
        datum.value = []
        if variable.$.classname
          datum.className = variable.$.classname
        if variable.property
          for property in variable.property
            datum.value.push @parseContextVariable({variable:property})
      when "resource"
        datum.type = "resource"
        datum.value = variable._
      when "int"
        datum.type = "numeric"
        datum.value = variable._
      when "error"
            datum.value = ""
      when "uninitialized"
        datum.value = undefined
      when "null"
        datum.value = null
      when "bool"
        datum.value = variable._
      when "float"
        datum.type = "numeric"
        datum.value = variable._
      else
        console.dir variable
        console.error "Unhandled context variable type: " + variable.$.type
    return datum
