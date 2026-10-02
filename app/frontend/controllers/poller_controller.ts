import { Controller } from "@hotwired/stimulus"

// Reloads the enclosing Turbo frame from `url` every `interval` ms, so a page
// follows a running job without a manual reload (the import run page). The
// server leaves the controller out once there is nothing left to follow; the
// new frame content then stops the polling.
export default class extends Controller<HTMLElement> {
  static values = { url: String, interval: { type: Number, default: 3000 } }

  declare readonly urlValue: string
  declare readonly intervalValue: number

  private timer?: number

  connect(): void {
    this.timer = window.setTimeout(() => this.reload(), this.intervalValue)
  }

  disconnect(): void {
    window.clearTimeout(this.timer)
  }

  private reload(): void {
    const frame = this.element.closest("turbo-frame")
    if (!frame) return

    if (frame.getAttribute("src") === this.urlValue) {
      ;(frame as HTMLElement & { reload(): void }).reload()
    } else {
      frame.setAttribute("src", this.urlValue)
    }
  }
}
