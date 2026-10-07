import { Controller } from "@hotwired/stimulus"
import { onGameble } from "../lib/events"

export default class extends Controller<HTMLElement> {
  static targets = ["reason"]

  declare readonly reasonTarget: HTMLElement

  private stopListening?: () => void

  connect(): void {
    this.stopListening = onGameble("gameble:trade-changed", ({ give, take }) => {
      const empty = give.cards === 0 || take.cards === 0
      const button = this.element.querySelector<HTMLButtonElement>("button[type=submit]")
      if (button) {
        button.disabled = empty
        if (empty) button.setAttribute("aria-describedby", this.reasonTarget.id)
        else button.removeAttribute("aria-describedby")
      }
      this.reasonTarget.hidden = !empty
    })
  }

  disconnect(): void {
    this.stopListening?.()
    this.stopListening = undefined
  }
}
