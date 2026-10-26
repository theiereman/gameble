import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import { AFTER_ZERO, BoosterCountdown, type CountdownClock } from "./booster_countdown"

const SERVER = "2026-10-26T12:00:00.000Z"
const inSeconds = (seconds: number) => new Date(Date.parse(SERVER) + seconds * 1000).toISOString()

describe("BoosterCountdown", () => {
  let hidden = false
  const clock: CountdownClock = {
    now: () => Date.now(),
    hidden: () => hidden,
    setTimeout: (action, ms) => setTimeout(action, ms),
    clearTimeout: (timer) => clearTimeout(timer),
  }

  beforeEach(() => {
    vi.useFakeTimers()
    hidden = false
  })
  afterEach(() => vi.useRealTimers())

  const countdown = () => {
    const seen: (number | null)[] = []
    const zero = vi.fn()
    const timer = new BoosterCountdown(clock, { left: (seconds) => seen.push(seconds), zero })
    return { timer, seen, zero }
  }

  it("counts whole seconds down and calls zero a second after it reaches it", () => {
    const { timer, seen, zero } = countdown()
    timer.set(inSeconds(3), SERVER)
    expect(timer.left).toBe(3)
    vi.advanceTimersByTime(3000)
    expect(seen).toEqual([3, 2, 1, 0])
    expect(zero).not.toHaveBeenCalled()
    vi.advanceTimersByTime(AFTER_ZERO)
    expect(zero).toHaveBeenCalledOnce()
  })

  it("never calls zero for a clock already at zero, nor without a next booster", () => {
    const { timer, seen, zero } = countdown()
    timer.set(inSeconds(-5), SERVER)
    vi.advanceTimersByTime(5000)
    expect(seen).toEqual([0])
    timer.set(null, SERVER)
    expect(timer.left).toBeNull()
    vi.advanceTimersByTime(5000)
    expect(zero).not.toHaveBeenCalled()
  })

  it("starts again only when the next booster or the server time changes", () => {
    const { timer, seen } = countdown()
    timer.set(inSeconds(10), SERVER)
    vi.advanceTimersByTime(2000)
    timer.set(inSeconds(10), SERVER)
    expect(timer.left).toBe(8)
    timer.set(inSeconds(60), SERVER)
    expect(timer.left).toBe(60)
    expect(seen).toEqual([10, 9, 8, 60])
  })

  it("drops a pending zero when the countdown changes before it", () => {
    const { timer, zero } = countdown()
    timer.set(inSeconds(1), SERVER)
    vi.advanceTimersByTime(1000)
    timer.set(inSeconds(30), SERVER)
    vi.advanceTimersByTime(AFTER_ZERO)
    expect(zero).not.toHaveBeenCalled()
  })

  it("pauses while the page is hidden and catches up when it shows again", () => {
    const { timer, seen, zero } = countdown()
    timer.set(inSeconds(5), SERVER)
    hidden = true
    timer.visibilityChanged()
    vi.advanceTimersByTime(10_000)
    expect(seen).toEqual([5])
    hidden = false
    timer.visibilityChanged()
    expect(timer.left).toBe(0)
    vi.advanceTimersByTime(AFTER_ZERO)
    expect(zero).toHaveBeenCalledOnce()
  })

  it("stops every timer once disposed", () => {
    const { timer, zero } = countdown()
    timer.set(inSeconds(1), SERVER)
    vi.advanceTimersByTime(1000)
    timer.dispose()
    vi.advanceTimersByTime(5000)
    expect(zero).not.toHaveBeenCalled()
    expect(vi.getTimerCount()).toBe(0)
  })
})
