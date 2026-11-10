import { Controller } from "@hotwired/stimulus"
import { t } from "../lib/i18n"
import { msToNextChange, timeLeft } from "../lib/time_left"

export default class extends Controller<HTMLElement> {
  static values = { seconds: Number, hoursTemplate: String, minutesTemplate: String, underTemplate: String }
  static targets = ["label"]

  declare readonly secondsValue: number
  declare readonly hoursTemplateValue: string
  declare readonly minutesTemplateValue: string
  declare readonly underTemplateValue: string
  declare readonly labelTarget: HTMLElement

  private deadline = 0
  private timer?: number
  private connected = false

  connect(): void {
    this.connected = true
    this.secondsValueChanged()
  }

  secondsValueChanged(): void {
    this.deadline = performance.now() + this.secondsValue * 1000
    if (this.connected) this.render()
  }

  disconnect(): void {
    this.connected = false
    this.clear()
  }

  private render(): void {
    this.clear()
    const seconds = (this.deadline - performance.now()) / 1000
    const left = timeLeft(seconds)
    const text = this.words(left)
    if (this.labelTarget.textContent !== text) this.labelTarget.textContent = text
    const wait = msToNextChange(seconds)
    if (wait !== null) this.timer = window.setTimeout(() => this.render(), wait)
  }

  private words(left: ReturnType<typeof timeLeft>): string {
    if (left.kind === "under") return this.underTemplateValue
    if (left.kind === "minutes") return t(this.minutesTemplateValue, { minutes: left.minutes })
    return t(this.hoursTemplateValue, { hours: left.hours, minutes: String(left.minutes).padStart(2, "0") })
  }

  private clear(): void {
    if (this.timer !== undefined) window.clearTimeout(this.timer)
    this.timer = undefined
  }
}
