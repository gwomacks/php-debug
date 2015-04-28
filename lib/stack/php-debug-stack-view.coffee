{View} = require 'atom'

module.exports =
class PhpDebugStackView extends View
  @content: ->
    @div class: "php-debug panel", =>
      @div class: "panel-heading", "PHP Debug Stack View"
      @div class: "panel-body padded"

  @showContexts: ->
    
