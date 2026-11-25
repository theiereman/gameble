import { Controller } from "@hotwired/stimulus"
import { writeHidden, writeText } from "../lib/dom_writes"
import { parsePrice } from "../lib/order_form"
import { picoins } from "../lib/picoins"

const LOWEST_ID = "order-lowest"

export default class OrderFormController extends Controller<HTMLFormElement> {
  static targets = ["input", "error", "amount", "button", "buttonAmount"]
  static values = { locale: String }

  declare readonly inputTarget: HTMLInputElement
  declare readonly errorTarget: HTMLElement
  declare readonly amountTargets: HTMLElement[]
  declare readonly buttonTarget: HTMLButtonElement
  declare readonly buttonAmountTarget: HTMLElement
  declare readonly localeValue: string

  private submitting = false

  type(): void {
    this.clearError()
    const price = parsePrice(this.inputTarget.value)
    const amount = picoins(price ?? 0, { locale: this.localeValue })
    for (const target of this.amountTargets) writeText(target, amount)
    writeHidden(this.buttonAmountTarget, price === null)
  }

  keydown(event: KeyboardEvent): void {
    if (event.key !== "Enter") return
    event.preventDefault()
    this.buttonTarget.focus()
  }

  submit(event: SubmitEvent): void {
    if (this.submitting) {
      event.preventDefault()
      return
    }
    this.submitting = true
  }

  submitted(): void {
    this.submitting = false
  }

  private clearError(): void {
    if (this.errorTarget.hidden) return
    this.errorTarget.hidden = true
    writeText(this.errorTarget, "")
    this.inputTarget.removeAttribute("aria-invalid")
    this.inputTarget.setAttribute("aria-describedby", LOWEST_ID)
  }
}
