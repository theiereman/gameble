import { Controller } from "@hotwired/stimulus"
import { onGameble } from "../lib/events"

// The counter-proposal's actions (EXPERIENCE.md, Counter-proposal in
// progress; story 5.7): the send button waits for a card on each side. It
// follows the trade board island's `gameble:trade-changed`; while a side is
// empty the button is disabled and its reason, "Choisissez les cartes de
// chaque côté.", shows beside it (EXPERIENCE.md, Buttons). Until the island
// tells it anything, the button stays as the server drew it. The listener
// goes on disconnect.
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
