'use babel'
/** @jsx etch.dom */

import etch from 'etch'
import { TextEditor } from 'atom'

import UiComponent from './component'

export default class Editor extends UiComponent {
  constructor () {
    super(...arguments)

    let text = ''
    const explore = (elt) => {
      if (elt.text) {
        text += elt.text
      }

      if (elt.children) {
        for (const ch of elt.children) {
          explore(ch)
        }
      }
    }
    explore(this)

    this.model = this.refs.editor
    this.element = this.model.element
    this.model.setText(text)
    this.subscribeToEvents()
    if (this.props.grammar) {
      this.model.setGrammar(atom.grammars.grammarForScopeName(this.props.grammar))
    }
  }

  getText() {
    return this.model.getText()
  }

  setText(text) {
    this.model.setText(text)
  }

  render () {
    return <TextEditor ref='editor' mini={this.props.mini} placeholderText={this.props.placeholder} />
  }

  subscribeToEvents() {
    // event subscription!
    if (this.props) {
      for (const evt in this.props.on) {
        const modelEvent = `on${evt[0].toUpperCase()}${evt.substring(1)}`;
        if (this.model[modelEvent]) {
          const handler = this.props.on[evt]
          this.subscriptions.add(this.model[modelEvent](handler))
          this.props.on[evt] = null
        }
      }
    }
  }
}
