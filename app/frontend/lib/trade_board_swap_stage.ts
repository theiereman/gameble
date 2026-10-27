import type { Point } from "./arc"
import { motionReduced } from "./motion"
import { screenTimers, type ScreenTimers } from "./screen_timers"
import { SWAP_BURST_AT, SWAP_CROSSFADE_MS, SWAP_MS, confettiDirections, swapKeyframes } from "./trade_board_swap"

const CONFETTI = 14
const CONFETTI_REACH = 90
const BURST_MS = 600

const centre = (element: Element): Point => {
  const rect = element.getBoundingClientRect()
  return { x: rect.left + rect.width / 2, y: rect.top + rect.height / 2 }
}

export type SwapStage = {
  readonly playing: boolean
  play: () => void
  stop: () => void
}

export function swapStage(board: HTMLElement, onChange: () => void): SwapStage {
  let playing = false
  let animations: Animation[] = []
  let effects: HTMLElement[] = []
  let timers: ScreenTimers = screenTimers()

  const reflectSwapping = (swapping: boolean): void => {
    board.toggleAttribute("data-swapping", swapping)
    board.classList.toggle("trade-board--swapping", swapping)
  }

  const effect = (className: string, parent: HTMLElement): HTMLElement => {
    const element = document.createElement("span")
    element.className = className
    element.setAttribute("aria-hidden", "true")
    parent.append(element)
    effects.push(element)
    return element
  }

  const burst = (): void => {
    const middle = board.querySelector<HTMLElement>(".trade-board__middle")
    if (!middle) return
    effect("trade-board__ring", middle)
    confettiDirections(CONFETTI, CONFETTI_REACH).forEach((direction, index) => {
      const piece = effect(`trade-board__confetti trade-board__confetti--${index % 4}`, middle)
      piece.style.setProperty("--confetti-x", `${direction.x}px`)
      piece.style.setProperty("--confetti-y", `${direction.y}px`)
    })
    effect("trade-board__flash", board)
    timers.later(BURST_MS, () => {
      effects.forEach((each) => each.remove())
      effects = []
    })
  }

  const finish = (): void => {
    playing = false
    reflectSwapping(false)
    onChange()
    board.querySelector<HTMLElement>(".trade-board__message")?.focus({ preventScroll: true })
  }

  const run = (): void => {
    const friend = board.querySelector<HTMLElement>(".trade-side--friend .trade-side__cards")
    const own = board.querySelector<HTMLElement>(".trade-side--own .trade-side__cards")
    if (!friend || !own || typeof board.animate !== "function") {
      finish()
      return
    }

    if (motionReduced()) {
      for (const list of [friend, own]) {
        animations.push(list.animate([{ opacity: 0 }, { opacity: 1 }], { duration: SWAP_CROSSFADE_MS, easing: "ease-out" }))
      }
      timers.later(SWAP_CROSSFADE_MS, finish)
      return
    }

    const from = { friend: centre(own), own: centre(friend) }
    const to = { friend: centre(friend), own: centre(own) }
    reflectSwapping(true)
    for (const [list, side] of [
      [friend, "friend"],
      [own, "own"],
    ] as const) {
      const offset = { x: from[side].x - to[side].x, y: from[side].y - to[side].y }
      for (const card of list.querySelectorAll<HTMLElement>(":scope > .trade-card")) {
        animations.push(card.animate(swapKeyframes(offset), { duration: SWAP_MS, easing: "linear", fill: "backwards" }))
      }
    }
    timers.later(SWAP_MS * SWAP_BURST_AT, burst)
    timers.later(SWAP_MS, finish)
  }

  return {
    get playing() {
      return playing
    },
    play() {
      timers = screenTimers()
      playing = true
      onChange()
      run()
    },
    stop() {
      animations.forEach((animation) => animation.cancel())
      timers.dispose()
      effects.forEach((each) => each.remove())
      animations = []
      effects = []
      playing = false
      reflectSwapping(false)
    },
  }
}
