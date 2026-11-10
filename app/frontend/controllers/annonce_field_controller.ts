import { Controller } from "@hotwired/stimulus"
import { writeText } from "../lib/dom_writes"
import type { Terms } from "../lib/annonce"

const MINIMUM_ID = "annonce-minimum"

export default class AnnonceFieldController extends Controller<HTMLElement> {
  static targets = ["input", "error"]
  static values = { minimum: Number, available: Number, buyNow: Number, ownMaximum: Number, answered: Boolean }

  declare readonly inputTarget: HTMLInputElement
  declare readonly hasErrorTarget: boolean
  declare readonly errorTarget: HTMLElement
  declare readonly minimumValue: number
  declare readonly availableValue: number
  declare readonly buyNowValue: number
  declare readonly ownMaximumValue: number
  declare readonly answeredValue: boolean

  terms(): Terms {
    return {
      minimum: this.minimumValue,
      available: this.availableValue,
      buyNow: this.buyNowValue > 0 ? this.buyNowValue : null,
      ownMaximum: this.ownMaximumValue > 0 ? this.ownMaximumValue : null,
    }
  }

  get answered(): boolean {
    return this.answeredValue
  }

  get text(): string {
    return this.inputTarget.value
  }

  focus(): void {
    this.inputTarget.focus()
  }

  type(): void {
    this.clearError()
    this.dispatch("typed", { detail: { text: this.inputTarget.value } })
  }

  keydown(event: KeyboardEvent): void {
    if (event.key !== "Enter") return
    event.preventDefault()
    this.dispatch("entered")
  }

  private clearError(): void {
    if (!this.hasErrorTarget || this.errorTarget.hidden) return
    this.errorTarget.hidden = true
    writeText(this.errorTarget, "")
    this.inputTarget.removeAttribute("aria-invalid")
    this.inputTarget.setAttribute("aria-describedby", MINIMUM_ID)
  }
}
