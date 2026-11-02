import { Controller } from "@hotwired/stimulus"
import { PressedFocus } from "../lib/reaction_focus"

const pressed = new PressedFocus()

// A reaction bar is replaced by the server's answer: the button pressed gets the focus back.
export default class extends Controller<HTMLElement> {
  connect(): void {
    const kind = pressed.take(this.element.id, Date.now())
    if (kind) this.element.querySelector<HTMLElement>(`[data-reaction-kind="${kind}"]`)?.focus()
  }

  press(event: Event): void {
    const button = event.target instanceof Element ? event.target.closest<HTMLElement>("[data-reaction-kind]") : null
    if (button?.dataset.reactionKind) pressed.remember(this.element.id, button.dataset.reactionKind, Date.now())
  }
}
