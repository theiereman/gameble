import { Controller } from "@hotwired/stimulus"
import { writeText } from "../lib/dom_writes"
import { onGameble } from "../lib/events"
import { formatNumber, t, type Template } from "../lib/i18n"

export default class extends Controller<HTMLElement> {
  static targets = ["count", "label", "special", "specialCount", "specialLabel", "specialReason"]
  static values = { delimiter: { type: String, default: "," }, templates: Object, specialTemplates: Object }

  declare readonly hasCountTarget: boolean
  declare readonly countTarget: HTMLElement
  declare readonly hasLabelTarget: boolean
  declare readonly labelTarget: HTMLElement
  declare readonly hasSpecialTarget: boolean
  declare readonly specialTarget: HTMLElement
  declare readonly hasSpecialCountTarget: boolean
  declare readonly specialCountTarget: HTMLElement
  declare readonly hasSpecialLabelTarget: boolean
  declare readonly specialLabelTarget: HTMLElement
  declare readonly hasSpecialReasonTarget: boolean
  declare readonly specialReasonTarget: HTMLElement
  declare readonly delimiterValue: string
  declare readonly templatesValue: Template
  declare readonly specialTemplatesValue: Template

  private stopListening?: () => void

  connect(): void {
    this.stopListening = onGameble("gameble:bank-changed", ({ available, special }) => {
      if (typeof available === "number") this.showStandard(available)
      if (typeof special === "number") this.showSpecial(special)
    })
  }

  disconnect(): void {
    this.stopListening?.()
    this.stopListening = undefined
  }

  private showStandard(available: number): void {
    if (this.hasCountTarget) writeText(this.countTarget, formatNumber(available, this.delimiterValue))
    if (this.hasLabelTarget && this.templatesValue)
      writeText(this.labelTarget, t(this.templatesValue, { count: available, number: "" }).trim())
  }

  private showSpecial(special: number): void {
    const none = special === 0
    if (this.hasSpecialCountTarget) writeText(this.specialCountTarget, formatNumber(special, this.delimiterValue))
    if (this.hasSpecialLabelTarget && this.specialTemplatesValue)
      writeText(this.specialLabelTarget, t(this.specialTemplatesValue, { count: special }))
    if (this.hasSpecialReasonTarget) this.specialReasonTarget.hidden = !none
    if (!this.hasSpecialTarget) return
    this.specialTarget.toggleAttribute("data-empty", none)
    if (this.specialTarget.tagName !== "A") return
    if (none) {
      this.specialTarget.setAttribute("aria-disabled", "true")
      this.specialTarget.tabIndex = -1
    } else {
      this.specialTarget.removeAttribute("aria-disabled")
      this.specialTarget.removeAttribute("tabindex")
    }
  }
}
