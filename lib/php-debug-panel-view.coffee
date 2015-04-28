{View} = require 'atom'

module.exports =
class PhpDebugPanel extends View
  @content: ->
    @div class: "php-debug panel", =>
      @div class: "panel-heading", "Node Debugger"
      @div class: "panel-body padded" 
