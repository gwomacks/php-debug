'use babel'
/** @jsx etch.dom */
import helpers from '../helpers'
import {Emitter, Disposable} from 'event-kit'
import autoBind from 'auto-bind-inheritance'

export default class DecoratorService  {
  constructor(services,options) {
    autoBind(this);
    this._services = services
    this._options = options
    this._emitter = new Emitter()
  }

  decorate(type,ref,data) {
    switch (type) {
      case "breakpointMarker":
        return this.decorateBreakpointMarker(ref,data)
      case "debuggerTitle":
        return this.decorateDebuggerTitle(ref,data)
      case "consoleTitle":
        return this.decorateConsoleTitle(ref,data)
      case "scopeContextArraySort":
        return this.decorateScopeContextArraySort(ref,data)
      case "variableLabels":
        return this.decorateVariableLabels(ref, data)
      case "variableRenderer":
        return this.decorateVariableRenderer(ref,data)
      default:
        return data
    }
  }

  decorateVariableRenderer(ref,data) {
    // let this be handled by the default renderer
    return data
  }

  decorateScopeContextArraySort(ref,data) {
    if (atom.config.get('php-debug.display.sortArray')) {
        this.fnWalkVar(data.data.variables);
    }
    return data
  }

  fnWalkVar (contextVar) {
    if (Array.isArray(contextVar)) {
      for (let item in contextVar) {
        if (Array.isArray(item.value)) {
          this.fnWalkVar(item.value)
        }
      }
      contextVar.sort(this.cbDeepNaturalSort)
    }
  }

  cbDeepNaturalSort (a,b) {
    let aIsNumeric = /^\d+$/.test(a.name)
    let bIsNumeric = /^\d+$/.test(b.name)
    // cannot exist two equal keys, so skip case of returning 0
    if (aIsNumeric && bIsNumeric) { // order numbers
      if (parseInt(a.name, 10) < parseInt(b.name, 10)) {
        return -1
      } else {
        return 1
      }
    } else if (!aIsNumeric && !bIsNumeric) { // order strings
      if (a.name < b.name) {
        return -1
      } else {
        return 1
      }
    } else { // string first (same behavior that PHP's `ksort`)
      if (aIsNumeric) {
        return 1
      } else {
        return -1
      }
    }
  }

  decorateVariableLabels(ref,data) {
    let variable = ref.variable;
    let parent = ref.parent;
    if (parent == undefined || parent == null) {
      parent = ""
    }
    let labels = [];
    let identifierClasses = 'variable php syntax--php';
    if (!variable.label && variable.name) {
      var identifier = variable.name;
    } else {
      var identifier = variable.label;
    }
    const numericIdentifier = /^\d+$/.test(identifier)
    if (!parent) { // root taxonomy (Locals,Globals)
      identifierClasses += ' syntax--type'
    } else if (parent == 'User derfined constants') {
      identifierClasses += ' syntax--constant'
    } else if (parent.indexOf('.') == -1) { // Variable
      identifierClasses += ' syntax--variable'
    } else {
      identifierClasses += ' syntax--property'
      if (numericIdentifier) {
        identifierClasses += ' syntax--constant syntax--numeric'
      } else {
        identifierClasses += ' syntax--string'
      }
      label = '"' + identifier + '"'
    }

    let typeClasses = 'type php syntax--php syntax--' + variable.type;
    switch (variable.type) {
      case "array":
        typeClasses += ' syntax--support syntax--function'
        break;
      case "object":
        typeClasses += ' syntax--entity syntax--name syntax--type'
        break;
    }

    labels.push({text:identifier,classes:identifierClasses})
    if (variable.type) {
      switch (variable.type) {
        case "array":
          labels.push({text:'array[' + (variable.length ? variable.length : variable.value.length) + ']',classes:typeClasses});
          break;
        case "object":
          labels.push({text:'object',classes:typeClasses});
          labels.push({text:"["+variable.className+"]",classes:'variable php syntax--php syntax--entity syntax--name syntax--class'});
          break;
      }

      let value = null;
      let valueClasses = 'syntax--php';
      switch (variable.type) {
        case "string":
          valueClasses += ' syntax--quoted syntax--string syntax--double '
          value = '"' + helpers.escapeHtml(variable.value) + '"';
          break;
        case 'resource':
        case 'error':
          valueClasses += ' syntax--quoted syntax--double syntax--constant'
          value = '"' + helpers.escapeHtml(variable.value) + '"';
          break;
        case 'bool':
          if (variable.value == 0) {
            value = 'false'
          } else {
            value = 'true';
          }
          valueClasses += ' syntax--constant syntax--language syntax--bool'
          break;
        case 'null':
          value = 'null';
          valueClasses += ' syntax--constant syntax--language syntax--null'
          break;
        case 'numeric':
          value = variable.value;
          valueClasses += ' syntax--constant syntax--numeric'
          break;
        case 'uninitialized':
          value = '?';
          valueClasses += ' syntax--constant syntax--language'
          break;
      }
      if (value) {
        labels.push({text:value,classes:valueClasses})
      }
    }



    return labels;
  }

  decorateDebuggerTitle(ref,data) {
    if (ref != "default") {
      data = data + "("+ ref +")"
    }
    return data
  }

  decorateConsoleTitle(ref,data) {
    if (ref != "default") {
      data = data + "("+ ref +")"
    }
    return data
  }

  decorateBreakpointMarker(ref, data) {
    if (typeof ref.getSettingValue === "function") {
      switch (ref.getSettingValue("type")) {
        case "line":
          data.class= 'debug-break-line';
          break;
        case "exception":
        case "error":
          data.class= 'debug-break-exception';
          break;
      }
    }
    return data
  }

  destroy() {
    if (typeof this._emitter.destroy === "function") {
      this._emitter.destroy()
    }
    this._emitter.dispose()
    delete this._emitter;
    delete this._services;
    delete this._options;


  }

  dispose() {
    this.destroy()
  }

}
