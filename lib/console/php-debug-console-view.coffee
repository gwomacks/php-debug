{Disposable} = require 'atom'
{$, ScrollView} = require 'atom-space-pen-views'
{$, TextEditorView, View}  = require 'atom-space-pen-views'
{Emitter, Disposable} = require 'event-kit'
ConsoleView = require './console-view'
Interact = require('interact.js')
module.exports =
class PhpDebugConsoleView extends ScrollView
  @content: ->
    @div class: "php-debug-console", tabindex: -1, =>
      @div class: 'php-debug-debug-console-view', =>
        @div class: "block actions", =>
          @span class: "panel-title", "PHP Console"
          @button class: "btn octicon icon-circle-slash inline-block-tight", 'data-action':'clear', =>
            @span class: "btn-text", "Clear Console"
        @section class: 'console-panel section', =>
          @div outlet: 'consoleViewList', class:'php-debug-console-contents php-debug-contents native-key-bindings',tabindex: -1
          @div class: 'editor-container', =>
            @subview 'consoleCommandLine', new TextEditorView()


  constructor: (params) ->
    super
    @GlobalContext = params.context
    @visible = false
    curHeight = atom.config.get('php-debug.currentConsoleHeight')
    if (curHeight)
      this.element.style.height = curHeight
      @find('.console-panel').css('height',curHeight)
    else
      this.element.style.height = '150px'
      @find('.console-panel').css('height',curHeight)
    @resizable = Interact(this.element).resizable({edges: { top: true }})

    @resizable.on('resizemove', (event) =>
        target = event.target
        if event.rect.height < 125
          if event.rect.height < 1
            target.style.width = target.style.height = null
          else
            return # No-Op
        else
          target.style.width  = event.rect.width + 'px'
          target.style.height = event.rect.height + 'px'
          @find('.console-panel').css('height',target.style.height)
      )
      .on('resizeend', (event) ->
        event.target.style.width = 'auto'
        atom.config.set('php-debug.currentConsoleHeight',event.target.style.height)
      )

    @panel = atom.workspace.addBottomPanel({item: this.element, visible: @visible, priority: 399})

  serialize: ->
    deserializer: @constructor.name
    uri: @getURI()

  getURI: -> @uri

  getTitle: -> "Console"

  onDidChangeTitle: -> new Disposable ->
  onDidChangeModified: -> new Disposable ->


  initialize: (params) ->
    @consoleCommandLine.getModel().onWillInsertText @submitCommand
    @consoleView = new ConsoleView(params)
    @consoleViewList.append(@consoleView)
    @on 'click', '[data-action]', (e) =>
      action = e.target.getAttribute('data-action')
      if e.target.tagName.toLowerCase() == "span"
        action = e.target.parentNode.getAttribute('data-action')
      switch action
        when 'clear'
          @GlobalContext.clearConsoleMessages()
          @consoleView.clear()

        else
          console.error "unknown action"
          console.dir action
          console.dir this


  isVisible: () =>
    @visible

  setVisible: (@visible) =>

    if @visible
      @panel.show()
    else
      @panel.hide()

  submitCommand: (event) =>
    return unless event.text is "\n"
    expression = @consoleCommandLine
      .getModel()
      .getText()
    @GlobalContext.notifyConsoleMessage(">" + expression)
    @GlobalContext.getCurrentDebugContext()?.evalExpression(expression)

    @consoleCommandLine
      .getModel()
      .setText('')
    event.cancel()

  isEqual: (other) ->
    other instanceof PhpDebugConsoleView
