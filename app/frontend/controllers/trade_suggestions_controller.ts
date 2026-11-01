import { Controller } from "@hotwired/stimulus"
import { holdLiveRefresh } from "../lib/live_refresh_hold"

export default class extends Controller<HTMLElement> {
  private readonly focusEntered = (): void => holdLiveRefresh(this.element, true)

  private readonly focusLeft = (): void => {
    window.setTimeout(() => holdLiveRefresh(this.element, this.element.contains(document.activeElement)))
  }

  connect(): void {
    this.element.addEventListener("focusin", this.focusEntered)
    this.element.addEventListener("focusout", this.focusLeft)
    holdLiveRefresh(this.element, this.element.contains(document.activeElement))
  }

  disconnect(): void {
    this.element.removeEventListener("focusin", this.focusEntered)
    this.element.removeEventListener("focusout", this.focusLeft)
    holdLiveRefresh(this.element, false)
  }
}
