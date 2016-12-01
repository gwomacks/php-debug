{View} = require 'atom-space-pen-views'
GlobalContext = require '../models/global-context'
ConsoleItemView = require './console-item-view'

module.exports =
class ConsoleView extends View

  @content: ->
      @ul class: "console-list-view", =>
        @div outlet: "consoleItemList"

  initialize: (params) ->
    @GlobalContext = params.context
    @lastMessageIdx = 0
    @updateConsole()
    @GlobalContext.onConsoleMessage (message) =>
       @updateConsole()

  clear: ->
    @consoleItemList?.empty()

  updateConsole: ->
    {lines,total} = @GlobalContext.getConsoleMessages(@lastMessageIdx)
    @lastMessageIdx = total
    for line in lines
      line = line
      @consoleItemList?.append(new ConsoleItemView(line))
    if this.element.parentElement?
      if this.element.parentElement.scrollHeight
        this.element.parentElement.scrollTop = this.element.parentElement.scrollHeight - this.element.parentElement.clientHeight
  
    
