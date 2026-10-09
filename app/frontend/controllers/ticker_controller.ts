import { Controller } from "@hotwired/stimulus"
import { motionReduced, onMotionChange } from "../lib/motion"
import { itemsInView, joinQueued, loopSeconds, repeatsToFill } from "../lib/ticker"

export default class extends Controller<HTMLElement> {
  static targets = ["window", "track", "run", "queue"]
  static values = { size: { type: Number, default: 12 } }

  declare readonly windowTarget: HTMLElement
  declare readonly trackTarget: HTMLElement
  declare readonly runTarget: HTMLElement
  declare readonly queueTarget: HTMLElement
  declare readonly sizeValue: number

  private arrivals?: MutationObserver
  private resizes?: ResizeObserver
  private stopMotion?: () => void
  private measured = { run: 0, window: 0 }

  private readonly boundary = (): void => {
    this.join(this.itemsInView())
  }

  private readonly queued = (): void => {
    if (!this.scrollingOrPausedMidLoop()) this.join()
  }

  private readonly resized = (): void => {
    const { run, window } = this.widths()
    if (run === this.measured.run && window === this.measured.window) return
    this.layoutAndRestartLoop()
  }

  connect(): void {
    this.layoutAndRestartLoop()
    this.trackTarget.addEventListener("animationiteration", this.boundary)
    this.arrivals = new MutationObserver(this.queued)
    this.arrivals.observe(this.queueTarget, { childList: true })
    this.stopMotion = onMotionChange(() => {
      this.join()
      this.layoutAndRestartLoop()
    })
    if (typeof ResizeObserver === "function") {
      this.resizes = new ResizeObserver(this.resized)
      this.resizes.observe(this.windowTarget)
      this.resizes.observe(this.runTarget)
    }
    this.queued()
  }

  disconnect(): void {
    this.trackTarget.removeEventListener("animationiteration", this.boundary)
    this.arrivals?.disconnect()
    this.arrivals = undefined
    this.resizes?.disconnect()
    this.resizes = undefined
    this.stopMotion?.()
    this.stopMotion = undefined
  }

  private scrollingOrPausedMidLoop(): boolean {
    return this.element.dataset.tickerState === "scrolling" && !motionReduced()
  }

  private join(keep = 0): void {
    const arrived = Array.from(this.queueTarget.children)
    if (arrived.length === 0) return

    this.runTarget.replaceChildren(...joinQueued(Array.from(this.runTarget.children), arrived, this.sizeValue, keep))
    this.queueTarget.replaceChildren()
    this.layoutAndRestartLoop()
  }

  private itemsInView(): number {
    const start = this.runTarget.getBoundingClientRect().left
    const starts = Array.from(this.runTarget.children, (item) => item.getBoundingClientRect().left - start)
    return itemsInView(starts, this.windowTarget.clientWidth)
  }

  private layoutAndRestartLoop(): void {
    this.trackTarget.querySelectorAll(".ticker__run--copy").forEach((copy) => copy.remove())
    this.measured = this.widths()
    const { run, window } = this.measured
    if (this.runTarget.children.length === 0 || motionReduced()) {
      this.element.dataset.tickerState = "still"
      return
    }

    const repeats = repeatsToFill(run, window)
    for (let copy = 1; copy < repeats * 2; copy += 1) this.trackTarget.append(this.copyOfRun())
    this.element.style.setProperty("--ticker-duration", `${loopSeconds(run * repeats)}s`)
    this.element.dataset.tickerState = "scrolling"
    this.trackTarget.getAnimations().forEach((animation) => {
      animation.currentTime = 0
    })
  }

  private widths(): { run: number; window: number } {
    return { run: this.runTarget.getBoundingClientRect().width, window: this.windowTarget.clientWidth }
  }

  private copyOfRun(): HTMLElement {
    const copy = this.runTarget.cloneNode(true) as HTMLElement
    copy.removeAttribute("data-ticker-target")
    copy.classList.add("ticker__run--copy")
    return copy
  }
}
