import { Controller } from "@hotwired/stimulus"
import { onGameble } from "../lib/events"

export default class extends Controller<HTMLElement> {
  private stopListening?: () => void
  private locked = false

  private readonly swallow = (event: Event): void => {
    if (!this.locked) return
    const control = (event.target as Element | null)?.closest("a[href], button")
    if (!control || !this.element.contains(control)) return
    event.preventDefault()
    event.stopImmediatePropagation()
  }

  connect(): void {
    this.element.addEventListener("click", this.swallow, { capture: true })
    this.stopListening = onGameble("gameble:navigation-locked", ({ locked }) => this.lock(locked === true))
  }

  disconnect(): void {
    this.stopListening?.()
    this.stopListening = undefined
    this.element.removeEventListener("click", this.swallow, { capture: true })
    this.lock(false)
  }

  private lock(on: boolean): void {
    if (on === this.locked) return
    this.locked = on
    for (const control of this.element.querySelectorAll<HTMLElement>("a[href], button")) {
      if (on) {
        if (control.getAttribute("aria-disabled") === "true") continue
        control.setAttribute("aria-disabled", "true")
        control.dataset.navigationLocked = ""
      } else if (control.dataset.navigationLocked !== undefined) {
        control.removeAttribute("aria-disabled")
        delete control.dataset.navigationLocked
      }
    }
  }
}
