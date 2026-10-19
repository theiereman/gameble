import { Controller } from "@hotwired/stimulus"
import { formatLocalTime, isLocalTimeStyle } from "../lib/local_time"

export default class extends Controller<HTMLTimeElement> {
  static values = { style: { type: String, default: "datetime" }, suffix: String }

  declare readonly styleValue: string
  declare readonly suffixValue: string

  connect(): void {
    // A morph refresh writes the server's text back without reconnecting the controller.
    this.element.addEventListener("turbo:morph-element", this.render)
    this.render()
  }

  disconnect(): void {
    this.element.removeEventListener("turbo:morph-element", this.render)
  }

  private readonly render = (): void => {
    if (!isLocalTimeStyle(this.styleValue)) return
    const local = formatLocalTime(this.element.dateTime, this.styleValue, { locale: document.documentElement.lang })
    if (local === null) return
    const text = local + this.suffixValue
    if (this.element.textContent !== text) this.element.textContent = text
  }
}
