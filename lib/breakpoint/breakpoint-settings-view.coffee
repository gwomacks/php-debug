{$, View} = require 'atom-space-pen-views'
{TextEditorView} = require 'atom-space-pen-views'
BreakpointSettingsConditionView = require './breakpoint-settings-condition-view'
GlobalContext = require '../models/global-context'

module.exports =
class BreakpoinSettingsView extends View
  @content: =>
    @div class: 'breakpoint-settings-view', =>
      @span click: 'close', class: 'atom-pair-exit-view close-icon'
      @div class: 'breakpoint-settings setting-conditions', =>
        @div class: 'breakpoint-settings-existing setting-conditions-existing'
        @div class: 'breakpoint-setting setting-condition setting-new', =>
          @span class: 'setting-label', "Condition:"
          @subview 'newConditionField', new TextEditorView(mini: true, placeholderText:'x == 1')
          @span click: 'addCondition', class:'setting-add setting-condition-add', "Add condition"

  initialize: (params) ->
    @GlobalContext = params.context
    @breakpoint = params.breakpoint
    @render()

  attach: ->
    @panel = atom.workspace.addModalPanel(item: this.element)

  addCondition: ->
    setting = @breakpoint.addSetting("condition",{value:@newConditionField.getText()})
    existing = @find('.breakpoint-settings-existing.setting-conditions-existing')
    view = new BreakpointSettingsConditionView(setting)
    fn = do (setting,@breakpoint,@removeSetting) ->
      fn = (e) =>
        @removeSetting(e,setting)
    view.find('.setting-remove').on 'click', fn

    existing.append(view)
    @newConditionField.setText("")

  close: ->
    # Cycle the breakpoint so changes take effect if we have an active debug session
    @GlobalContext.removeBreakpoint @breakpoint
    @GlobalContext.addBreakpoint @breakpoint

    panelToDestroy = @panel
    @panel = null
    panelToDestroy?.destroy()

  removeSetting: (e,setting) ->
    $(e.target).parents('.breakpoint-setting').remove()
    @breakpoint.removeSetting(setting)

  render: ->
    existing = @find('.breakpoint-settings-existing.setting-conditions-existing')
    for type,settings of @breakpoint.getSettings()
      switch type
        when "condition"
          for setting in settings
            view = new BreakpointSettingsConditionView(setting)
            fn = do (setting,@breakpoint,@removeSetting) ->
              fn = (e) =>
                @removeSetting(e,setting)
            view.find('.setting-remove').on 'click', fn
            existing.append(view)
