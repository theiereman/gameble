import { revealingOpening, type BoosterState } from "./booster"
import type { BoosterCountdown } from "./booster_countdown"
import { dispatchGameble } from "./events"

export function reflectChange(
  before: BoosterState,
  after: BoosterState,
  countdown: BoosterCountdown | undefined,
  whenIdle: () => void,
): void {
  if (after.bank !== before.bank) {
    const { available, special, reserveFull, nextAvailableAt, serverTime } = after.bank
    dispatchGameble("gameble:bank-changed", { available, special, reserveFull, nextAvailableAt, serverTime })
    countdown?.set(nextAvailableAt, serverTime)
  }
  const revealing = revealingOpening(after.status)
  if (revealing !== revealingOpening(before.status)) dispatchGameble("gameble:opening-revealing", { revealing })
  if (before.lockDepth === 0 && after.lockDepth > 0) dispatchGameble("gameble:navigation-locked", { locked: true })
  if (before.lockDepth > 0 && after.lockDepth === 0) {
    dispatchGameble("gameble:navigation-locked", { locked: false })
    whenIdle()
  }
}
