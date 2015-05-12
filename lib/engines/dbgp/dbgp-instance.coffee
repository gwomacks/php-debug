parseString = require('xml2js').parseString
Q = require 'q'
{Emitter, Disposable} = require 'event-kit'

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

  syncStack: ->
    return @executeCommand('stack_get').then (data) =>
      stackFrames = []
      for frame in data.response.stack
        csonFrame = {
          id:       frame.$.level
          label:    frame.$.where
          filepath: frame.$.filename
          line:     frame.$.lineno
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
      message = buffer.slice(n+1, n+1+len)
      buffer = buffer.slice(n+2+len)
      o = parseString message, (err, result) =>
        type = Object.keys(result)[0]
        switch type
          when "init" then @onInit result
          when "response"
            @parseResponse result
    return buffer

  parseResponse: (data) =>
    result = data.response.$
    transactionId = result.transaction_id
    # if data.response.$.status == "break"
    #   GlobalContext.notifyBreak(data)
      #@notifyResponseBreak data
    # if data.response.$.command == "context_get"
    #   context = @buildContext(data)
    #   @notifyContextChange(context)

    if @promises[transactionId] != undefined
      @promises[transactionId].resolve(data)
      delete @promises[transactionId]
    else
      console.warn "Could not find promise for transaction " + transactionId


  stuff: (data) =>
    message = @parse(data)
    # @getFeature('language_supports_threads')


  executeCommand: (command, options, data) ->
    @command(command, options, data)

  command: (command, options, data) =>

    transactionId = @nextTransactionId()
    deferred = Q.defer();
    @promises[transactionId] = deferred

    payload = command + " -i " + transactionId
    if options && Object.keys(options).length > 0
      argu = ("-"+arg + " " + val for arg, val of options)
      argu2 = argu.join(" ")
      payload += " " + argu2

    if data
      payload += " -- " + new Buffer(data, 'ascii').toString('base64')
    if @socket
      @socket.write(payload + "\0")
    else
      console.error "No socket found"
    return deferred.promise

  getFeature: (feature_name) =>
    @command("feature_get", {n: feature_name})

  setFeature: (feature_name, value) =>
    return @command("feature_set", {n: feature_name, v: value})

  onInit: (data) =>
    @setFeature('show_hidden', 1)
    .then () =>
      @sendAllBreakpoints()
    .then () =>
      return @continue("run")


  sendAllBreakpoints: =>
    breakpoints = @GlobalContext.getBreakpoints()
    commands = []
    for breakpoint in breakpoints
      options = {
        t: 'line',
        f: breakpoint.getPath(), #'file://C:/Users/gabriel/Documents/test.php',
        n: breakpoint.getLine()
      }
      commands.push @command("breakpoint_set", options)
    return Q.all(commands)

  executeBreakpoint: (breakpoint) =>
    options = {
      t: 'line',
      f: breakpoint.getPath(),
      n: breakpoint.getLine()
    }
    return @command("breakpoint_set", options)

  continue: (type) =>
    return @command(type).then(
      (data) =>
        response = data.response
        messages = response["xdebug:message"]
        message = messages[0]
        thing = message.$
        filepath = thing['filename'].replace("file:///", "")
        lineno = thing['lineno']
        breakpoint = new Breakpoint(filepath: filepath, line:lineno)
        @GlobalContext.notifyBreak(breakpoint)
    )

  syncCurrentContext: () ->

    console.log "syncing context"
    p2 = @getContextNames().then(
      (data) =>
        return @processContextNames(data)
    )

    p3 = p2.then(
      (data) =>
        return @updateWatchpoints(data)
    )

    p4 = p3.then (
      (data) =>
        @syncStack()
    )

    p5 = p4.then(
      (data) =>
        return @GlobalContext.notifyContextUpdate()
    )

    p5.done()

  getContextNames: () ->
    return @command("context_names")

  processContextNames: (data) =>
    #GlobalContext.setContext(new DebugContext())
    for context in data.response.context
      @addScope(context.$.id,context.$.name)
    commands = []
    scopes = @getScopes()
    for index, scope of scopes
      commands.push(@updateContext(scope))
    # for watchpoint in GlobalContext.getWatchpoints
    #   commands.push @evalWatchpoint(watchpoint)
    return Q.all(commands)

  executeDetach: () =>
    @command('detach')
    .then () =>
      @continue("run")

  updateWatchpoints: (data) =>
    @clearWatchpoints()
    commands = []
    for watch in @GlobalContext.getWatchpoints()
      commands.push @evalWatchpoint(watch)

    # for watchpoint in GlobalContext.getWatchpoints
    #   commands.push @evalWatchpoint(watchpoint)
    return Q.all(commands)


  executeEval: (expression) ->
    return @command("eval", null, expression)

  evalWatchpoint: (watchpoint) ->
    p = @command("eval", null, watchpoint.getExpression())
    return p.then (data) =>
      watchpoint.setValue(data.response.property[0]._)
      @addWatchpoint(watchpoint)

  updateContext: (scope) =>
    p = @contextGet(scope.scopeId)
    return p.then (data) =>
      context = @buildContext data
      @setScopeContext(scope.scopeId, context)

  contextGet: (scope) =>
    return @command("context_get", {c: scope})


  buildContext: (response) =>
    data = {}
    data.type = 'context'
    data.context = response.response.$.context
    data.variables = []
    for property in response.response.property
      v = @parseContextVariable(property)
      data.variables.push v
    return data



  parseContextVariable: (variable) ->
    datum = {
      name : variable.$.name
      fullname : variable.$.fullname
    }
    datum.type = variable.$.type
    switch variable.$.type
      when "string"
        switch variable.$.encoding
          when "base64"
            datum.value = new Buffer(variable._, 'base64').toString('ascii')
          else
            console.error "Unhandled context variable encoding: " + variable.$.encoding
      when "array"
        datum.value = []
        if variable.property
          for property in variable.property
            datum.value.push @parseContextVariable(property)
      when "object"
        datum.value = []
        if variable.property
          for property in variable.property
            datum.value.push @parseContextVariable(property)
      when "int"
        datum.value = variable._
      when "uninitialized"
        datum.value = undefined
      when "null"
        datum.value = null
      else
        console.error "Unhandled context variable type: " + variable.$.type
    return datum
