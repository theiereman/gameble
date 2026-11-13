import { Controller } from "@hotwired/stimulus"
import { groupDigits } from "../lib/amount"
import { writeText } from "../lib/dom_writes"
import type { Terms } from "../lib/annonce"

const MINIMUM_ID = "annonce-minimum"
const TERMS_ATTRIBUTES = ["minimum", "available", "own-maximum", "price", "unusual-multiple", "answered"].map(
  (name) => `data-annonce-field-${name}-value`,
)

export default class AnnonceFieldController extends Controller<HTMLElement> {
  static targets = ["input", "error"]
  static values = {
    minimum: Number,
    available: Number,
    ownMaximum: Number,
    price: Number,
    unusualMultiple: Number,
    answered: Boolean,
  }

  declare readonly inputTarget: HTMLInputElement
  declare readonly hasErrorTarget: boolean
  declare readonly errorTarget: HTMLElement
  declare readonly minimumValue: number
  declare readonly availableValue: number
  declare readonly ownMaximumValue: number
  declare readonly priceValue: number
  declare readonly unusualMultipleValue: number
  declare readonly answeredValue: boolean

  private watcher?: MutationObserver

  connect(): void {
    this.watcher = new MutationObserver(() => this.dispatch("retermed"))
    this.watcher.observe(this.element, { attributes: true, attributeFilter: TERMS_ATTRIBUTES })
  }

  disconnect(): void {
    this.watcher?.disconnect()
    this.watcher = undefined
  }

  terms(): Terms {
    return {
      minimum: this.minimumValue,
      available: this.availableValue,
      ownMaximum: this.ownMaximumValue > 0 ? this.ownMaximumValue : null,
      price: this.priceValue,
      unusualMultiple: this.unusualMultipleValue,
    }
  }

  get answered(): boolean {
    return this.answeredValue
  }

  get input(): HTMLInputElement {
    return this.inputTarget
  }

  get text(): string {
    return this.inputTarget.value
  }

  get focused(): boolean {
    return document.activeElement === this.inputTarget
  }

  release(): void {
    this.unpin()
    this.inputTarget.value = ""
  }

  // A permanent input would survive the answer's stream and keep the stale text and error state.
  unpin(): void {
    this.inputTarget.removeAttribute("data-turbo-permanent")
  }

  focus(): void {
    this.inputTarget.focus()
  }

  type(): void {
    this.clearError()
    this.dispatch("typed", { detail: { text: this.inputTarget.value } })
  }

  fill({ params }: { params: { amount?: number } }): void {
    if (params.amount === undefined) return
    this.inputTarget.value = groupDigits(String(params.amount), document.documentElement.lang)
    this.type()
    this.inputTarget.focus()
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
