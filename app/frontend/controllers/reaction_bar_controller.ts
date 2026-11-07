import { Controller } from "@hotwired/stimulus"
import { PressedFocus } from "../lib/reaction_focus"

const pressed = new PressedFocus()

// A bar replaced by the server's answer gives the focus back to the button holding or adding the reaction.
export default class extends Controller<HTMLElement> {
  connect(): void {
    if (pressed.take(this.element.id, Date.now()))
      this.element.querySelector<HTMLElement>("[data-reaction-return]")?.focus()
  }

  press(event: Event): void {
    const target = event.target instanceof Element ? event.target : null
    const toggle = target?.closest<HTMLElement>("[data-reaction-toggle]")
    if (toggle) {
      toggle.setAttribute("aria-expanded", toggle.getAttribute("aria-expanded") === "true" ? "false" : "true")
      return
    }

    const button = target?.closest<HTMLElement>("[data-reaction-kind]")
    if (button?.dataset.reactionKind) pressed.remember(this.element.id, button.dataset.reactionKind, Date.now())
  }
}
