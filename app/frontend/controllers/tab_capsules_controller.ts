import { Controller } from "@hotwired/stimulus"
import { writeText } from "../lib/dom_writes"
import { onGameble } from "../lib/events"
import { formatNumber, t, type Template } from "../lib/i18n"

export default class extends Controller<HTMLElement> {
  static targets = ["badge", "label"]
  static values = { available: Number, special: Number, delimiter: { type: String, default: "," }, templates: Object }

  declare readonly badgeTarget: HTMLElement
  declare readonly labelTarget: HTMLElement
  declare availableValue: number
  declare specialValue: number
  declare readonly delimiterValue: string
  declare readonly templatesValue: Template

  private stopListening?: () => void

  connect(): void {
    this.stopListening = onGameble("gameble:bank-changed", ({ available, special }) => {
      if (typeof available === "number") this.availableValue = available
      if (typeof special === "number") this.specialValue = special
      this.show()
    })
  }

  disconnect(): void {
    this.stopListening?.()
    this.stopListening = undefined
  }

  private show(): void {
    const ready = this.availableValue + this.specialValue
    const number = formatNumber(ready, this.delimiterValue)
    this.element.hidden = ready === 0
    writeText(this.badgeTarget, number)
    writeText(this.labelTarget, t(this.templatesValue, { count: ready, number }))
  }
}
