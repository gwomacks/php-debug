'use babel'
/** @jsx etch.dom */

import etch from 'etch'
import UiComponent from '../ui/component'
import DefaultBreakpointItemView from './default-breakpoint-item-view'
import helpers from '../helpers'

export default class DefaultBreakpointListView extends UiComponent {

  constructor (props,children) {
    super(props,children)
    this._services = props.services;
    this.subscriptions.add(atom.config.onDidChange("php-debug.exceptions", this.breakpointsUpdated))
  }

  render () {
    const {services,state} = this.props;
    const breakpointComponents = Object.keys(state.breakpoints).map((breakpointType,index) => {
      let breakpoint = state.breakpoints[breakpointType];
      let status = atom.config.get('php-debug.exceptions.'+breakpointType)
      return <DefaultBreakpointItemView key={index} services={services} type={breakpointType} breakpoint={breakpoint} status={status} onchange={this.breakpointChanged} />
    });
    return <section className="default-breakpoints-view atom-debug-ui-default-breakpoints atom-debug-ui-contents">
        <span class="default-breakpoints-header">Exceptions: </span>
        <ul className="default-breakpoint-list-view native-key-bindings" attributes={{"tabindex":"-1"}}>
          {breakpointComponents}
        </ul>
      </section>
  }

  breakpointsReady() {
  }

  breakpointsUpdated(event) {
    var changed = false;
    for (let key in event.newValue) {
      if (event.newValue[key] != event.oldValue[key]) {
        changed = true;
      }
    }
    if (changed) {
      this.update({state:this.props.state}, this.children, true);
    }
  }

  init () {
    if (!this.props.state) {
      let config = atom.config.getSchema('php-debug.exceptions').properties;
      this.props.state = {
        breakpoints: config
      };
    }
    super.init();
  }

  breakpointChanged(type, checked) {
    atom.config.set('php-debug.exceptions.'+type, checked)
  }
}
DefaultBreakpointListView.bindFns = ["breakpointsReady","breakpointChanged","breakpointsUpdated"]
