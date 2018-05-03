'use babel'
/** @jsx etch.dom */

import etch from 'etch'
import UiComponent from '../ui/component'

export default class ConsoleView extends UiComponent {
  render() {
    const {state} = this.props;
    let classes = 'php-debug-console-view-toggle'
    if (state.active) {
      classes += ' active'
    }
    return <div onclick={this.toggleConsole} className={classes}>
      <span className='icon icon-bug' /><span className='php-debug-console-label'>PHP Console</span>
    </div>
  }

  constructor (props,children) {
      super(props,children)
      this._engine = props.engine
      this._statusBar = props.statusBar
  }

  init () {
    if (!this.props.state) {
      this.props.state = {
        active: false
      }
    }
    super.init()
    this._tile = this.props.statusBar.addLeftTile({item: this.element, priority: -99})
  }

  toggleConsole() {
    this._engine.createDebuggingContext("default").then( (context) => {
      const uiService = context.getUIService()
      if (uiService != null) {
        uiService.toggleConsole()
      }
    })
  }

  setActive (active) {
    const state = Object.assign({}, this.props.state);
    state._active = active;
    this.update({state:state});
  }

  destroy() {
    if (this._tile) {
      this._tile.destroy()
      this._tile = null
    }
    super.destroy()
  }
}
ConsoleView.bindFns = ["toggleConsole","setActive"]
