import { Controller } from "@hotwired/stimulus"
import { motionReduced, onMotionChange } from "../lib/motion"

// The star field's sideways shift on a screen change (EXPERIENCE.md, Motion:
// "the star field shifts sideways (1.1s)"). The star layer is a repeated
// tile, one tile wider than the screen; each visit after the first moves it
// SHIFT px left with a transform (the transition is in CSS), and when the
// move would leave the extra tile, the layer first jumps back by one whole
// tile, which looks the same, so the field wraps without a visible jump.
// Nothing moves under reduced motion: the switch (lib/motion.ts) is read when a
// shift starts, and a shift under way stops where it is going when the
// switch flips on.
//
// The layer is data-turbo-permanent, so Turbo moves it from page to page
// and this controller may disconnect and reconnect during a render: the
// offset and the pending shift live at module level, and a reconnection
// finishes a shift whose turbo:load it missed.
//
// A visit to the page already shown (a refresh, a form sent back to the same
// page, the current tab tapped) is no screen change: the stars stay, and
// `html[data-screen-change=same]` tells the CSS to skip the screen's slide.
// Nor is a visit made while `html[data-sub-view-step]` is set.
const SHIFT = 160

let offset = 0
let pending = false

export default class extends Controller<HTMLElement> {
  static values = { tile: { type: Number, default: 480 } }

  declare readonly tileValue: number

  private frame?: number
  private stopMotionWatch?: () => void

  private readonly visited = (event: Event): void => {
    // A sub-view's step (the card detail's ◀ ▶, sub_view_controller.ts)
    // changes the URL but not the screen: the stars stay.
    if (document.documentElement.dataset.subViewStep) return
    const { url, action } = (event as CustomEvent<{ url?: string; action?: string }>).detail ?? {}
    // At turbo:visit, location is still the page being left, except on a
    // restoration (Back, Forward): the browser has already moved to the
    // entry, so a restoration always counts as a screen change.
    const same = action !== "restore" && url !== undefined && new URL(url, location.href).pathname === location.pathname
    if (same) {
      document.documentElement.dataset.screenChange = "same"
      // A screen change this visit replaced is not shown any more.
      pending = false
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
    // Reduced motion switched on mid-shift: the field lands at once.
    this.stopMotionWatch = onMotionChange((reduced) => {
      if (reduced) this.place(offset, false)
    })
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
    this.stopMotionWatch?.()
    this.stopMotionWatch = undefined
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
