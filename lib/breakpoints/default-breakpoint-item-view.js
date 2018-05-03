'use babel'
/** @jsx etch.dom */

import etch from 'etch'
import UiComponent from '../ui/component'

export default class DefaultBreakpointItemView extends UiComponent {

  render () {
    const {breakpoint,type,status} = this.props;
    let attributes = {
      value: type
    };
    if (status == true) {
      attributes.checked = "checked";
    }
    return <li className='breakpoint-list-item'>
        <div className='breakpoint-item'>
          <input type="checkbox" className='input-checkbox breakpoint-enabled' onchange={this.handleChange} attributes={attributes} />
          <span className='breakpoint-type'>{breakpoint.title}</span>
        </div>
      </li>
  }
  handleChange (event) {
    if (!this.props.onchange) {
      return
    }
    this.props.onchange(this.props.type, event.target.checked);
  }
}
DefaultBreakpointItemView.bindFns = ["handleChange"]
