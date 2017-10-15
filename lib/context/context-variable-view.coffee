{View} = require 'atom-space-pen-views'
ContextVariableScalarView = require "./context-variable-scalar-view"
helpers        = require '../helpers'

module.exports =
class ContextVariableView extends View

  @content: =>
    @li class: 'native-key-bindings', =>
      @div class: 'native-key-bindings', tabindex: -1, outlet: 'variableView'

  initialize: ({@variable,@parent,@openpaths}) ->
    @render()

  renderScalar: ({label,value}) ->
    labelIsNumeric = /^\d+$/.test(label)
    if @parent == 'User defined constants'
      labelClass = "variable php syntax--php syntax--constant"
    else
      labelClass = 'variable php syntax--php ' + switch label[0]
        when '$' then 'syntax--variable'
        else "syntax--property #{if labelIsNumeric then 'syntax--constant syntax--numeric' else 'syntax--string'}"
      label = '"'+label+'"' if !labelIsNumeric and label[0] != '$'
    valueClass = "type php syntax--php syntax--#{@variable.type} " + switch @variable.type
      when 'bool', 'null', 'numeric' then 'syntax--constant'
      when 'object' then 'syntax--entity syntax--name syntax--type'
      when 'uninitialized' then 'syntax--comment'
      else ''
    "<span class=\"#{labelClass}\">#{label}</span><span class=\"#{valueClass}\">#{value}</span>"

  render: ->
    ContextVariableListView = require "./context-variable-list-view"
    label = @variable.label
    openChildren = false
    mapValue = {
      bool: { '0': 'false', '1': 'true' },
    }
    if @openpaths?
      for open in @openpaths
        if !!@parent
          if open.indexOf(@parent+'.'+label) == 0
            openChildren = true
            break
        else
          if open.indexOf(label) == 0
            openChildren = true
            break
    switch @variable.type
      when 'string'
        @variableView.append(@renderScalar({label:label, value: "\""+helpers.escapeHtml(@variable.value)+"\""}))
      when 'numeric'
        @variableView.append(@renderScalar({label: label, value:@variable.value}))
      when 'bool'
        @variableView.append(@renderScalar({label: label, value: mapValue.bool[@variable.value]}))
      when 'uninitialized'
        @variableView.append(@renderScalar({label:label, value:"?"}))
      when 'error'
          @variableView.append(@renderScalar({label:label, value:helpers.escapeHtml(@variable.value)}))
      when 'null'
        @variableView.append(@renderScalar({label: label, value: "null"}))
      when 'array'
        summary ="array["+(@variable.length || @variable.value.length)+"]"
        @variableView.append(new ContextVariableListView({
          name: label,
          summary: summary,
          variables: @variable.value,
          autoopen: openChildren,
          parent:@parent,
          openpaths:@openpaths,
          type: @variable.type,
        }))
      when 'object'
        summary ="object"
        if @variable.className
          summary += " ["+@variable.className+"]"
        properties = @variable.value
        @variableView.append(new ContextVariableListView({
          name:label,
          summary: summary,
          variables: properties,
          autoopen: openChildren,
          parent:@parent,
          openpaths:@openpaths,
          type: @variable.type,
        }))
      when 'resource'
        @variableView.append(@renderScalar({label:label, value: "\""+helpers.escapeHtml(@variable.value)+"\""}))
      else
        console.error "Unhandled variable type: " + @variable.type
