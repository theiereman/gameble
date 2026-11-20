import { Controller } from "@hotwired/stimulus"
import { LIVE_DELAY } from "../lib/annonce"
import { writeHidden, writeText } from "../lib/dom_writes"
import { parsePrice, reachedRarities, sentence, type Minimums, type OrderStrings, type Rarity } from "../lib/order_form"
import { picoins } from "../lib/picoins"

const LOWEST_ID = "order-lowest"

export default class OrderFormController extends Controller<HTMLFormElement> {
  static targets = ["input", "error", "chip", "sentence", "status", "amount", "button", "buttonAmount"]
  static values = { minimums: Object, strings: Object, locale: String }

  declare readonly inputTarget: HTMLInputElement
  declare readonly errorTarget: HTMLElement
  declare readonly chipTargets: HTMLElement[]
  declare readonly sentenceTarget: HTMLElement
  declare readonly statusTarget: HTMLElement
  declare readonly amountTargets: HTMLElement[]
  declare readonly buttonTarget: HTMLButtonElement
  declare readonly buttonAmountTarget: HTMLElement
  declare readonly minimumsValue: Minimums
  declare readonly stringsValue: OrderStrings
  declare readonly localeValue: string

  private timer?: ReturnType<typeof setTimeout>
  private submitting = false

  disconnect(): void {
    clearTimeout(this.timer)
  }

  type(): void {
    this.clearError()
    const price = parsePrice(this.inputTarget.value)
    const reached = reachedRarities(this.minimumsValue, price)
    for (const chip of this.chipTargets) {
      const on = reached.includes(chip.dataset.rarity as Rarity)
      chip.classList.toggle("order-reach__chip--reached", on)
      writeHidden(chip.querySelector<HTMLElement>("[data-reach=on]"), !on)
      writeHidden(chip.querySelector<HTMLElement>("[data-reach=off]"), on)
    }
    const line = sentence(this.stringsValue, this.minimumsValue, price, this.localeValue)
    writeText(this.sentenceTarget, line)
    const amount = picoins(price ?? 0, { locale: this.localeValue })
    for (const target of this.amountTargets) writeText(target, amount)
    writeHidden(this.buttonAmountTarget, price === null)

    clearTimeout(this.timer)
    this.timer = setTimeout(() => writeText(this.statusTarget, line), LIVE_DELAY)
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
