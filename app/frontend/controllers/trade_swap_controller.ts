import { Controller } from "@hotwired/stimulus"
import type { Point } from "../lib/arc"
import { holdLiveRefresh } from "../lib/live_refresh_hold"
import { motionReduced } from "../lib/motion"
import { SWAP_BURST_AT, SWAP_CROSSFADE_MS, SWAP_MS, confettiDirections, swapKeyframes } from "../lib/trade_swap"

const CONFETTI = 14
const CONFETTI_REACH = 90
const BURST_MS = 600

const centre = (element: Element): Point => {
  const rect = element.getBoundingClientRect()
  return { x: rect.left + rect.width / 2, y: rect.top + rect.height / 2 }
}

export default class extends Controller<HTMLElement> {
  static values = { play: Boolean }

  declare playValue: boolean

  private animations: Animation[] = []
  private timers: number[] = []
  private effects: HTMLElement[] = []

  connect(): void {
    if (!this.playValue) return
    this.playValue = false
    if (document.documentElement.hasAttribute("data-turbo-preview")) return
    holdLiveRefresh(this.element, true)
    this.play()
  }

  disconnect(): void {
    this.animations.forEach((animation) => animation.cancel())
    this.timers.forEach((timer) => window.clearTimeout(timer))
    this.effects.forEach((effect) => effect.remove())
    this.animations = []
    this.timers = []
    this.effects = []
    this.element.classList.remove("trade-board--swapping")
    holdLiveRefresh(this.element, false)
  }

  private play(): void {
    const friend = this.element.querySelector<HTMLElement>(".trade-side--friend .trade-side__cards")
    const own = this.element.querySelector<HTMLElement>(".trade-side--own .trade-side__cards")
    if (!friend || !own || typeof this.element.animate !== "function") {
      this.finish()
      return
    }

    if (motionReduced()) {
      for (const list of [friend, own]) {
        this.animations.push(list.animate([{ opacity: 0 }, { opacity: 1 }], { duration: SWAP_CROSSFADE_MS, easing: "ease-out" }))
      }
      this.later(SWAP_CROSSFADE_MS, () => this.finish())
      return
    }

    const from = { friend: centre(own), own: centre(friend) }
    const to = { friend: centre(friend), own: centre(own) }
    this.element.classList.add("trade-board--swapping")
    for (const [list, side] of [[friend, "friend"], [own, "own"]] as const) {
      const offset = { x: from[side].x - to[side].x, y: from[side].y - to[side].y }
      for (const card of list.querySelectorAll<HTMLElement>(":scope > .trade-card")) {
        this.animations.push(card.animate(swapKeyframes(offset), { duration: SWAP_MS, easing: "linear", fill: "backwards" }))
      }
    }
    this.later(SWAP_MS * SWAP_BURST_AT, () => this.burst())
    this.later(SWAP_MS, () => this.finish())
  }

  private burst(): void {
    const middle = this.element.querySelector<HTMLElement>(".trade-board__middle")
    if (!middle) return
    this.effect("trade-swap__ring", middle)
    confettiDirections(CONFETTI, CONFETTI_REACH).forEach((direction, index) => {
      const piece = this.effect(`trade-swap__confetti trade-swap__confetti--${index % 4}`, middle)
      piece.style.setProperty("--confetti-x", `${direction.x}px`)
      piece.style.setProperty("--confetti-y", `${direction.y}px`)
    })
    this.effect("trade-swap__flash", this.element)
    this.later(BURST_MS, () => {
      this.effects.forEach((effect) => effect.remove())
      this.effects = []
    })
  }

  private effect(className: string, parent: HTMLElement): HTMLElement {
    const element = document.createElement("span")
    element.className = className
    element.setAttribute("aria-hidden", "true")
    parent.append(element)
    this.effects.push(element)
    return element
  }

  private finish(): void {
    this.element.classList.remove("trade-board--swapping")
    holdLiveRefresh(this.element, false)
    this.element.querySelector<HTMLElement>(".trade-board__message")?.focus({ preventScroll: true })
  }

  private later(delay: number, callback: () => void): void {
    this.timers.push(window.setTimeout(callback, delay))
  }
}
