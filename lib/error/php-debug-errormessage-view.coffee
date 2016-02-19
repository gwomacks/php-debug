{View, $$} = require 'atom-space-pen-views'

errorMap = (text) ->
  text.slice(0,
    if ~text.indexOf(' ') then text.indexOf(' ') else text.length
  ).toLowerCase()


module.exports =
class PhpDebugErrormessageView extends View

  @content: ->
    @div class: 'php-debug php-debug-errormessage-view pane-item', =>
      @div class: 'panel-heading', 'Error Message'
      @div outlet: 'errorMessage', class: 'panel-content'

  initialize: (params) ->
    @GlobalContext = params.context
    @GlobalContext.onBreak @showErrorType
    @GlobalContext.onSessionEnd () => @errorMessage.empty()

  showErrorType: (data) =>
    @errorMessage.empty()
    if !data.exception then return
    @errorMessage.append $$ ->
      @li =>
        @div class: errorMap(data.exception), data.exception
        @span data.message
