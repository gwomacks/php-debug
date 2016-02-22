module.exports =
  GutterBreakpointToggle:
    title: "Enable breakpoint markers in the gutter"
    type: 'boolean'
    default: true
    description: "Enable breakpoints to be toggled and displayed via the gutter"
  GutterPosition:
    type: 'string'
    default: "Right"
    description: "Display breakpoint gutter to the left or right of the line numbers"
    enum: ["Left","Right"]
  CustomExceptions:
    type: 'array'
    default: []
    items:
      type: 'string'
    description: "Custom Exceptions to break on"
  PathMaps:
    type: 'array'
    default: []
    items:
      type: 'string'
    description: "Paths in the format of remote;local (eg \"/var/www/project;C:\\projects\\mycode\")"
  ServerPort:
    type: 'integer'
    default: 9000
  MaxChildren:
    type: 'integer'
    default: 32
  MaxData:
    type: 'integer'
    default: 1024
  MaxDepth:
    type: 'integer'
    default: 4
  PhpException:
    type: 'object'
    properties:
      FatalError:
        type: 'boolean'
        default: true
      CatchableFatalError:
        type: 'boolean'
        default: true
      Notice:
        type: 'boolean'
        default: true
      Warning:
        type: 'boolean'
        default: true
      Deprecated:
        type: 'boolean'
        default: true
      StrictStandards:
        type: 'boolean'
        default: true
      ParseError:
        type: 'boolean'
        default: true
      Xdebug:
        type: 'boolean'
        default: true
      UnknownError:
        type: 'boolean'
        default: true
