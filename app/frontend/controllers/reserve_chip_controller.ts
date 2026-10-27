import { Controller } from "@hotwired/stimulus"
import { onGameble } from "../lib/events"
import { formatNumber, t, type Template } from "../lib/i18n"

export default class extends Controller<HTMLElement> {
  static targets = ["count", "label"]
  static values = { delimiter: { type: String, default: "," }, templates: Object }

  declare readonly countTarget: HTMLElement
  declare readonly hasLabelTarget: boolean
  declare readonly labelTarget: HTMLElement
  declare readonly delimiterValue: string
  declare readonly templatesValue: Template

  private stopListening?: () => void

  connect(): void {
    this.stopListening = onGameble("gameble:bank-changed", ({ available }) => {
      if (typeof available !== "number") return
      this.countTarget.textContent = formatNumber(available, this.delimiterValue)
      if (this.hasLabelTarget && this.templatesValue)
        this.labelTarget.textContent = t(this.templatesValue, { count: available, number: "" }).trim()
    })
  }

  disconnect(): void {
    this.stopListening?.()
    this.stopListening = undefined
  }
}
