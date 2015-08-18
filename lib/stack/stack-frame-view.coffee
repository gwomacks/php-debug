{View} = require 'atom-space-pen-views'

module.exports =
class StackFrameView extends View

  @content: (params) =>
    selection = if params.active then 'selected' else ''
    @li class: selection, =>
      @div class: 'stack-frame-level text-info inline-block-tight', 'data-level': params.id, params.id
      @div class: 'stack-frame-label text-info inline-block-tight', params.label
      @div class: 'stack-frame-filepath text-smaller inline-block-tight', 'data-path': params.filepath, params.filepath
      @div class: 'stack-frame-line text-smaller inline-block-tight', 'data-line': params.line, '(' + params.line + ')'
      
