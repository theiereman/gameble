import { Controller } from "@hotwired/stimulus"
import { overflowsSideways } from "../lib/overflow_focus"

// A row that scrolls sideways only on narrow screens is one tab stop while it
// overflows, so the arrow keys scroll it; when it fits, it takes no tab stop.
export default class extends Controller<HTMLElement> {
  private resizes?: ResizeObserver

  connect(): void {
    this.update()
    this.resizes = new ResizeObserver(() => this.update())
    this.resizes.observe(this.element)
  }

  disconnect(): void {
    this.resizes?.disconnect()
    this.resizes = undefined
    this.element.removeAttribute("tabindex")
  }

  private update(): void {
    if (overflowsSideways(this.element)) this.element.tabIndex = 0
    else this.element.removeAttribute("tabindex")
  }
}
