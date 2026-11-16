import { Controller } from "@hotwired/stimulus"
import { clockText, inAlert, secondsLeft, shouldAnnounce, startClock, type DuelClock } from "../lib/duel_clock"

const TICK_MS = 250

export default class extends Controller<HTMLElement> {
  static values = { deadline: String, serverTime: String, template: String, warning: String }
  static targets = ["text", "status"]

  declare readonly deadlineValue: string
  declare readonly serverTimeValue: string
  declare readonly templateValue: string
  declare readonly warningValue: string
  declare readonly textTarget: HTMLElement
  declare readonly statusTarget: HTMLElement

  private clock: DuelClock | null = null
  private startedAt = 0
  private timer?: number

  connect(): void {
    this.clock = startClock(this.deadlineValue, this.serverTimeValue)
    if (this.clock === null) return

    this.startedAt = performance.now()
    this.tick()
    this.timer = window.setInterval(() => this.tick(), TICK_MS)
  }

  disconnect(): void {
    window.clearInterval(this.timer)
  }

  private tick(): void {
    if (this.clock === null) return

    const seconds = secondsLeft(this.clock, performance.now() - this.startedAt)
    this.textTarget.textContent = clockText(this.templateValue, seconds)
    this.element.classList.toggle("duel-clock--alert", inAlert(seconds))
    if (shouldAnnounce(this.clock, seconds)) {
      this.statusTarget.textContent = this.warningValue
      this.clock = { ...this.clock, announced: true }
    }
    if (seconds === 0) window.clearInterval(this.timer)
  }
}
