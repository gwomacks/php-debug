{View} = require 'atom-space-pen-views'

module.exports =
class StackFrameView extends View

  @content: (params) =>
    @li =>
      @div class: 'stack-frame-label text-info inline-block-tight', params.label
      @div class: 'stack-frame-filepath text-smaller inline-block-tight', params.filepath
      @div class: 'stack-frame-line text-smaller inline-block-tight', params.line
