import { Controller } from "@hotwired/stimulus"
import "../lib/turbo"
import { formatClock } from "../lib/booster"

// After a refresh that brought no new countdown (failed, or the same value),
// the next try.
const RETRY_MS = 5000
// While a form is being submitted, the next look at whether it is over.
const BUSY_RETRY_MS = 250

// The countdown to the next pack, in the top bar's packs chip (R4). The server
// renders the whole seconds left; the clock counts down against a
// performance.now() deadline, so a throttled timer or a changed system clock
// never drifts it. One second after zero the page refreshes with a morph,
// keeping its scroll, and shows the new pack and the next countdown; until a
// new value arrives, the refresh is tried again every few seconds.
//
// A refresh would cancel a form submission in flight (the hub's daily
// booster, "Récupérer"), so none starts from a submission's start until the
// next page load, or until the submission ends without one.
//
// The daily booster panel's countdown to 00:00 UTC (CAP-16) is the same
// controller: `hours` writes "HH:MM:SS"; without it the clock reads
// "H:MM:SS" from an hour, else "MM:SS" (the packs chip). A `bar` target (a
// <progress> of `total` seconds) fills as the clock runs down.
//
// With `refresh` false (the packs chip on any page but the hub), the clock
// stops at 00:00 and the page is never refreshed: the next visit brings the
// new value.
export default class extends Controller<HTMLElement> {
  static values = { seconds: Number, refresh: { type: Boolean, default: true }, hours: Boolean, total: Number }
  static targets = ["clock", "bar"]

  declare readonly secondsValue: number
  declare readonly refreshValue: boolean
  declare readonly hoursValue: boolean
  declare readonly totalValue: number
  declare readonly clockTarget: HTMLElement
  declare readonly hasBarTarget: boolean
  declare readonly barTarget: HTMLProgressElement

  private deadline?: number
  private seconds?: number
  private timer?: number
  private submitting = false

  private readonly submitStarted = (): void => {
    this.submitting = true
  }

  private readonly submitEnded = (event: Event): void => {
    const { success, fetchResponse } = (event as CustomEvent<{ success: boolean; fetchResponse?: { header(name: string): string | null } }>).detail ?? {}
    // A successful submission is followed by a visit, ended by turbo:load,
    // unless the answer is a Turbo Stream (the daily claim): no visit follows.
    const stream = fetchResponse?.header("Content-Type")?.startsWith("text/vnd.turbo-stream.html") ?? false
    if (!success || stream) this.submitting = false
  }

  private readonly loaded = (): void => {
    this.submitting = false
  }

  // Also called when a refresh morphs in a new value. The same value again
  // (a reconnection, a refresh too early) keeps the running deadline.
  secondsValueChanged(): void {
    if (this.seconds === this.secondsValue && this.deadline !== undefined) return
    this.seconds = this.secondsValue
    this.deadline = performance.now() + this.secondsValue * 1000
    if (this.timer !== undefined) this.tick()
  }

  connect(): void {
    document.addEventListener("turbo:submit-start", this.submitStarted)
    document.addEventListener("turbo:submit-end", this.submitEnded)
    document.addEventListener("turbo:load", this.loaded)
    this.secondsValueChanged()
    this.tick()
  }

  disconnect(): void {
    document.removeEventListener("turbo:submit-start", this.submitStarted)
    document.removeEventListener("turbo:submit-end", this.submitEnded)
    document.removeEventListener("turbo:load", this.loaded)
    window.clearTimeout(this.timer)
    this.timer = undefined
  }

  private tick(): void {
    window.clearTimeout(this.timer)
    const left = (this.deadline ?? 0) - performance.now()
    if (!this.refreshValue && left <= 0) {
      // Stopped; a new value morphed in starts it again.
      this.show(0)
      return
    }
    if (left <= -1000) {
      if (this.submitting) {
        this.schedule(BUSY_RETRY_MS)
      } else {
        window.Turbo.visit(location.href, { action: "replace" })
        this.schedule(RETRY_MS)
      }
      return
    }

    const seconds = Math.max(0, Math.ceil(left / 1000))
    this.show(seconds)
    // Wake at the next whole second, or at the refresh.
    this.schedule(left > 0 ? left - (seconds - 1) * 1000 : left + 1000)
  }

  // The clock, and the bar when there is one.
  private show(seconds: number): void {
    const pad = (n: number): string => String(n).padStart(2, "0")
    const minutes = Math.floor(seconds / 60)
    this.clockTarget.textContent = this.hoursValue
      ? `${pad(Math.floor(minutes / 60))}:${pad(minutes % 60)}:${pad(seconds % 60)}`
      : formatClock(seconds)
    if (this.hasBarTarget && this.totalValue > 0) this.barTarget.value = Math.max(0, this.totalValue - seconds)
  }

  private schedule(wait: number): void {
    this.timer = window.setTimeout(() => this.tick(), Math.max(wait, 16))
  }
}
