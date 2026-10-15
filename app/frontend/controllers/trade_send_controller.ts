import { Controller } from "@hotwired/stimulus"
import { onGameble } from "../lib/events"
import { sendable } from "../lib/trade_board"

export default class extends Controller<HTMLElement> {
  static targets = ["reason"]

  declare readonly reasonTarget: HTMLElement

  private stopListening?: () => void

  connect(): void {
    this.stopListening = onGameble("gameble:trade-changed", (detail) => {
      const blocked = !sendable(detail)
      const button = this.element.querySelector<HTMLButtonElement>("button[type=submit]")
      if (button) {
        button.disabled = blocked
        if (blocked) button.setAttribute("aria-describedby", this.reasonTarget.id)
        else button.removeAttribute("aria-describedby")
      }
      this.reasonTarget.hidden = !blocked
    })
  }

  disconnect(): void {
    this.stopListening?.()
    this.stopListening = undefined
  }
}
