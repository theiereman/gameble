import { Controller } from "@hotwired/stimulus"
import { writeText } from "../lib/dom_writes"
import type { FootView } from "../lib/annonce_view"

export default class AnnonceFootController extends Controller<HTMLElement> {
  static targets = ["sentences", "live", "button", "panel"]

  declare readonly sentencesTarget: HTMLElement
  declare readonly liveTarget: HTMLElement
  declare readonly buttonTarget: HTMLButtonElement
  declare readonly hasPanelTarget: boolean
  declare readonly panelTarget: HTMLElement

  render({ button, name, live, sentencesHidden, panelHidden }: FootView): void {
    writeText(this.buttonTarget, button)
    if (name === null) this.buttonTarget.removeAttribute("aria-label")
    else this.buttonTarget.setAttribute("aria-label", name)
    writeText(this.liveTarget, live)
    this.sentencesTarget.hidden = sentencesHidden
    if (this.hasPanelTarget) this.panelTarget.hidden = panelHidden
  }

  get button(): HTMLButtonElement {
    return this.buttonTarget
  }

  focusSubmit(): void {
    this.buttonTarget.focus()
  }

  raise(): void {
    this.dispatch("raise")
  }
}
