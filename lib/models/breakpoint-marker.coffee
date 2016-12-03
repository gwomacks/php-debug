

module.exports =
class BreakpointMarker
  constructor: (@editor,@range,@gutter) ->
    @markers = {}
    enableGutters = atom.config.get('php-debug.GutterBreakpointToggle')

    if enableGutters && @gutter
      gutterMarker = @editor.markBufferRange(@range, {invalidate: 'inside'})
      @markers.gutter = gutterMarker
    
    lineMarker = @editor.markBufferRange(@range)
    @markers.line = lineMarker 
    
  decorate: ->
    item = document.createElement('span')
    item.className = "highlight php-debug-gutter php-debug-highlight"

    if @markers.gutter
      @gutter.decorateMarker(@markers.gutter, {class: 'php-debug-gutter-marker',item})
    
    if @markers.line
      @editor.decorateMarker(@markers.line, {type: 'line-number', class: 'php-debug-breakpoint'})
    
  destroy: ->
    for type,marker of @markers
      marker?.destroy()
      
  getStartBufferPosition: ->
    for type,marker of @markers
      if marker
        return marker.getStartBufferPosition()
    
