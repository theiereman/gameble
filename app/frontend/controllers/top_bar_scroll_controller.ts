import { Controller } from "@hotwired/stimulus"
import { frameScheduler, type FrameScheduler } from "../lib/frame_scheduler"
import { initialScrollState, nextScrollState, type ScrollState } from "../lib/top_bar_scroll"

const HIDDEN = "data-hidden"

export default class extends Controller<HTMLElement> {
  private state: ScrollState = initialScrollState
  private scheduler?: FrameScheduler

  connect(): void {
    this.scheduler = frameScheduler(() => this.update())
    this.state = { shown: true, anchor: window.scrollY }
    window.addEventListener("scroll", this.onScroll, { passive: true })
    this.element.addEventListener("focusin", this.reveal)
    this.element.addEventListener("toggle", this.reveal, true)
  }

  disconnect(): void {
    window.removeEventListener("scroll", this.onScroll)
    this.element.removeEventListener("focusin", this.reveal)
    this.element.removeEventListener("toggle", this.reveal, true)
    this.scheduler?.cancel()
    this.element.removeAttribute(HIDDEN)
  }

  private readonly onScroll = (): void => {
    this.scheduler?.schedule()
  }

  private readonly reveal = (): void => {
    this.apply({ shown: true, anchor: window.scrollY })
  }

  private update(): void {
    const holdOpen =
      this.element.querySelector(":focus-visible") !== null || this.element.querySelector(":popover-open") !== null
    this.apply(nextScrollState(this.state, { offset: Math.max(0, window.scrollY), holdOpen }))
  }

  private apply(state: ScrollState): void {
    this.state = state
    this.element.toggleAttribute(HIDDEN, !state.shown)
  }
}
