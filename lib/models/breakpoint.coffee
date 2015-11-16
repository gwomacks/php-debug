Codepoint = require('./codepoint')

module.exports =
class Breakpoint extends Codepoint
  atom.deserializers.add(this)
  @version: '1d'
  @breakpointId: 1
  @breakpointSettingId: 1
  @TYPE_LINE = 'line'
  @TYPE_EXCEPTION = 'exception'


  @getNextBreakpointId: () ->
    return @breakpointId++

  @getNextBreakpointSettingId: () ->
    return @breakpointSettingId++

  constructor: ({filepath, marker, line, @type, @exception, @settings}) ->
    super
    if !@type
      @type =  Breakpoint.TYPE_LINE
    @id = Breakpoint.getNextBreakpointId()


  serialize: -> {
    deserializer: 'Breakpoint'
    version: @constructor.version
    data: {
      filepath: @getPath()
      line: @getLine()
      settings: JSON.stringify(@getSettings())
    }
  }

  @deserialize: ({data}) ->
    return new Breakpoint(filepath: data.filepath, line: data.line, settings: Breakpoint.parseSettings(data.settings))

  @parseSettings: (settings) ->
    parsedSettings = JSON.parse(settings)
    for type,settings of parsedSettings
        for ts, idx in settings
          parsedSettings[type][idx].id = Breakpoint.getNextBreakpointSettingId()
    return parsedSettings



  getId: ->
    return @id

  getSettings: ->
    if !@settings
      @settings = {}
    return @settings

  getSettingsValues: (type) ->
    if !@settings
      @settings = {}
      return []
    if !@settings[type]
      return []
    return @settings[type]

  addSetting: (type,value) ->
    if !@settings
      @settings = {}
    if !@settings[type]
      @settings[type] = []
    value.id =  Breakpoint.getNextBreakpointSettingId()
    @settings[type].push(value)
    return value

  removeSetting: (setting) ->
    return if !setting || !setting.id
    return if !@settings
    for type,settings of @settings
      for ts, idx in settings
        if ts.id == setting.id
          @settings[type].splice(idx,1)
          return

  getType: ->
    return @type

  getException: ->
    return @exception

  isLessThan: (other) ->
    return true if !other instanceof Breakpoint
    return true if other.getPath() < @getPath()
    return true if other.getLine() < @getLine()

  isEqual: (other) ->
    return false if !other instanceof Breakpoint
    return false if other.getPath() != @getPath()
    return false if other.getLine() != @getLine()
    return true

  isGreaterThan: (other) ->
    return !@isLessThan(other) && !@isEqual(other)

  @fromMarker: (marker) ->
