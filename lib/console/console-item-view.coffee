{View} = require 'atom-space-pen-views'

module.exports =
class ConsoleItemView extends View
  @content: =>
    @li class: 'console-item native-key-bindings', =>
      @div class: 'console-item-text native-key-bindings', =>
        @span class: 'line native-key-bindings',tabindex: -1, outlet: 'lineElement'

  initialize: (line) ->
    @line = line
    @render()

  render: ->
    @lineElement.append @line
