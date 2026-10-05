import { Controller } from "@hotwired/stimulus"
import { motionReduced } from "../lib/motion"

// The star field's sideways shift on a screen change (EXPERIENCE.md, Motion:
// "the star field shifts sideways (1.1s)"). The star layer is a repeated
// tile, one tile wider than the screen; each visit after the first moves it
// SHIFT px left with a transform (the transition is in CSS), and when the
// move would leave the extra tile, the layer first jumps back by one whole
// tile, which looks the same, so the field wraps without a visible jump.
// Nothing moves under reduced motion.
//
// The layer is data-turbo-permanent, so Turbo moves it from page to page
// and this controller may disconnect and reconnect during a render: the
// offset and the pending shift live at module level, and a reconnection
// finishes a shift whose turbo:load it missed.
//
// A visit to the page already shown (a refresh, a form sent back to the same
// page, the current tab tapped) is no screen change: the stars stay, and
// `html[data-screen-change=same]` tells the CSS to skip the screen's slide.
const SHIFT = 160

let offset = 0
let pending = false

export default class extends Controller<HTMLElement> {
  static values = { tile: { type: Number, default: 480 } }

  declare readonly tileValue: number

  private frame?: number

  private readonly visited = (event: Event): void => {
    const url = (event as CustomEvent<{ url?: string }>).detail?.url
    // At turbo:visit, location is still the page being left.
    const same = url !== undefined && new URL(url, location.href).pathname === location.pathname
    if (same) {
      document.documentElement.dataset.screenChange = "same"
    } else {
      delete document.documentElement.dataset.screenChange
      pending = true
    }
  }

  private readonly loaded = (): void => {
    this.shiftIfPending()
  }

  connect(): void {
    document.addEventListener("turbo:visit", this.visited)
    document.addEventListener("turbo:load", this.loaded)
    this.place(offset, false)
    if (pending) {
      this.frame = window.requestAnimationFrame(() => {
        this.frame = undefined
        this.shiftIfPending()
      })
    }
  }

  disconnect(): void {
    document.removeEventListener("turbo:visit", this.visited)
    document.removeEventListener("turbo:load", this.loaded)
    if (this.frame !== undefined) window.cancelAnimationFrame(this.frame)
    this.frame = undefined
  }

  private shiftIfPending(): void {
    if (!pending) return
    pending = false
    if (motionReduced()) return

    let target = offset - SHIFT
    if (target < -this.tileValue) {
      // Back by one tile without a transition: the same picture.
      this.place(offset + this.tileValue, false)
      target += this.tileValue
    }
    this.place(target, true)
  }

  private place(x: number, animate: boolean): void {
    offset = x
    this.element.classList.toggle("is-shifting", animate)
    this.element.style.setProperty("--star-shift", `${x}px`)
    // A jump is committed before an animated move can start from it.
    if (!animate) void this.element.offsetWidth
  }
}
