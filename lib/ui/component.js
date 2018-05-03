'use babel'
/** @jsx etch.dom */

import { CompositeDisposable } from 'atom'
import etch from 'etch'
import { shallowEqual } from '../helpers'

export default class UiComponent {
  constructor (props, children) {
    this.subscriptions = new CompositeDisposable();
    this.props = props
    this.children = children

    const { bindFns } = this.constructor
    if (bindFns) {
      bindFns.forEach((fn) => { this[fn] = this[fn].bind(this) })
    }

    this.init()
  }

  init () {
    etch.initialize(this)
  }

  shouldUpdate (newProps) {
    return !shallowEqual(this.props, newProps)
  }

  update (props, children, force) {
    if ((force == undefined || force == false) && !this.shouldUpdate(props)) {
      return Promise.resolve()
    }
    this.props = Object.assign({}, this.props, props)
    this.children = children
    return etch.update(this)
  }

  destroy (removeNode = false) {
    this.subscriptions.dispose();
    etch.destroy(this, removeNode)
  }

  dispose () {
    this.destroy()
  }

  render () {
    throw new Error('Ui components must implement a `render` method')
  }
}

etch.setScheduler(atom.views)
