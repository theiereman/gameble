import { Controller } from "@hotwired/stimulus"
import { TIER_AT_ATTRIBUTE, placeTicks } from "../lib/tier_ticks"

export default class extends Controller<HTMLElement> {
  connect(): void {
    // A morph refresh writes the server's attributes back without reconnecting the controller.
    this.element.addEventListener("turbo:morph-element", this.place)
    this.place()
  }

  disconnect(): void {
    this.element.removeEventListener("turbo:morph-element", this.place)
  }

  private readonly place = (): void => {
    placeTicks(this.element.querySelectorAll<HTMLElement>(`[${TIER_AT_ATTRIBUTE}]`))
  }
}
