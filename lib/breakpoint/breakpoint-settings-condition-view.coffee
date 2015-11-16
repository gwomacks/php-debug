{View} = require 'atom-space-pen-views'
{TextEditorView} = require 'atom-space-pen-views'

module.exports =
class BreakpointSettingsConditionView extends View
  @content: (params) ->
    @div class: 'breakpoint-setting setting-condition setting-existing', =>
      @span class: 'setting-label', "Condition:"
      @div class: 'setting-container', =>
        @subview 'conditionField', new TextEditorView(mini: true)
        @span class:'setting-action setting-remove setting-condition-remove', "Remove"

  initialize: (@setting) ->
    @conditionField.getModel().onDidInsertText @submitSetting
    @render()

  submitSetting: (event) =>
    expression = @conditionField.getText()
    @setting.value = expression

  getSetting: ->
    @setting.value = @conditionField.getText()
    return @setting

  render: ->
    @conditionField.setText(@setting.value)
