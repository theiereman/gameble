import "./turbo"
import { revealModeReached, revealTimings, revealingOpening, type BoosterState } from "./booster"
import type { BoosterCountdown } from "./booster_countdown"
import { csrfToken } from "./booster_page"
import { dispatchGameble } from "./events"
import { sendReveal } from "./reveal"

export function reflectChange(
  before: BoosterState,
  after: BoosterState,
  countdown: BoosterCountdown | undefined,
  goalReachedTitle: string,
  whenIdle: () => void,
): void {
  if (after.goalsReached !== before.goalsReached) {
    after.goalsReached.forEach((name) => dispatchGameble("gameble:toast", { title: goalReachedTitle, message: name }))
  }
  if (after.bank !== before.bank) {
    const { available, special, reserveFull, nextAvailableAt, serverTime } = after.bank
    dispatchGameble("gameble:bank-changed", { available, special, reserveFull, nextAvailableAt, serverTime })
    window.Turbo.cache.clear()
    countdown?.set(nextAvailableAt, serverTime)
  }
  const revealing = revealingOpening(after.status)
  if (revealing !== revealingOpening(before.status)) dispatchGameble("gameble:opening-revealing", { revealing })
  if (before.lockDepth === 0 && after.lockDepth > 0) dispatchGameble("gameble:navigation-locked", { locked: true })
  if (before.lockDepth > 0 && after.lockDepth === 0) {
    dispatchGameble("gameble:navigation-locked", { locked: false })
    whenIdle()
  }
  recordReveal(before, after)
}

function recordReveal(before: BoosterState, after: BoosterState): void {
  const mode = revealModeReached(before, after)
  const url = after.answer?.pack.revealUrl
  if (mode && url) void sendReveal({ url, mode, timings: revealTimings(after), csrfToken: csrfToken() })
  const due = after.revealDue
  if (due && due !== before.revealDue) {
    void sendReveal({ url: due.url, mode: due.mode, timings: due.timings, csrfToken: csrfToken() })
  }
}
