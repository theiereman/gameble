import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import { boosterTimers } from "./booster_timers"

describe("boosterTimers", () => {
  beforeEach(() => vi.useFakeTimers())
  afterEach(() => vi.useRealTimers())

  it("resolves a wait after its delay and runs a later action after its own", async () => {
    const timers = boosterTimers()
    const done = vi.fn()
    const action = vi.fn()
    void timers.wait(100).then(done)
    timers.later(200, action)

    await vi.advanceTimersByTimeAsync(99)
    expect(done).not.toHaveBeenCalled()
    await vi.advanceTimersByTimeAsync(1)
    expect(done).toHaveBeenCalledOnce()
    expect(action).not.toHaveBeenCalled()
    await vi.advanceTimersByTimeAsync(100)
    expect(action).toHaveBeenCalledOnce()
  })

  it("treats a negative delay as none", async () => {
    const done = vi.fn()
    void boosterTimers().wait(-50).then(done)
    await vi.advanceTimersByTimeAsync(0)
    expect(done).toHaveBeenCalledOnce()
  })

  it("leaves every pending wait unresolved once disposed, and starts none after", async () => {
    const timers = boosterTimers()
    const done = vi.fn()
    const action = vi.fn()
    void timers.wait(100).then(done)
    timers.later(50, action)
    timers.dispose()
    void timers.wait(10).then(done)

    await vi.advanceTimersByTimeAsync(1000)
    expect(timers.disposed).toBe(true)
    expect(done).not.toHaveBeenCalled()
    expect(action).not.toHaveBeenCalled()
    expect(vi.getTimerCount()).toBe(0)
  })
})
