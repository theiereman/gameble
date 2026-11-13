import { Controller } from "@hotwired/stimulus"
import { countedAt } from "../lib/count_up"
import { writeText } from "../lib/dom_writes"
import { motionReduced } from "../lib/motion"
import { picoins } from "../lib/picoins"

export default class EntrustResultController extends Controller<HTMLElement> {
  static targets = ["amount"]
  static values = { amount: Number, locale: String }

  declare readonly amountTarget: HTMLElement
  declare readonly hasAmountTarget: boolean
  declare readonly amountValue: number
  declare readonly localeValue: string

  private frame = 0
  private startedAt?: number

  connect(): void {
    if (motionReduced() || !this.hasAmountTarget) return
    this.drawFigure(0)
    this.frame = requestAnimationFrame(this.roll)
  }

  disconnect(): void {
    this.settle()
  }

  dismiss(): void {
    this.settle()
    this.element.hidden = true
  }

  close(): void {
    this.dismiss()
    this.dispatch("close")
  }

  private readonly roll = (now: number): void => {
    this.startedAt ??= now
    const shown = countedAt(this.amountValue, now - this.startedAt)
    this.drawFigure(shown)
    this.frame = shown === this.amountValue ? 0 : requestAnimationFrame(this.roll)
  }

  private settle(): void {
    if (!this.frame) return
    cancelAnimationFrame(this.frame)
    this.frame = 0
    this.drawFigure(this.amountValue)
  }

  private drawFigure(amount: number): void {
    if (!this.hasAmountTarget) return
    writeText(this.amountTarget.querySelector(".picoin-amount__figure"), picoins(amount, { locale: this.localeValue }))
  }
}
