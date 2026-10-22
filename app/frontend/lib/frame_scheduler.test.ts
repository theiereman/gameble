import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import { frameScheduler } from "./frame_scheduler"

describe("frameScheduler", () => {
  let frames: Map<number, FrameRequestCallback>
  let next: number

  beforeEach(() => {
    frames = new Map()
    next = 1
    vi.stubGlobal("requestAnimationFrame", (callback: FrameRequestCallback) => {
      frames.set(next, callback)
      return next++
    })
    vi.stubGlobal("cancelAnimationFrame", (id: number) => frames.delete(id))
  })

  afterEach(() => vi.unstubAllGlobals())

  const runFrames = () => {
    const due = [...frames.values()]
    frames.clear()
    due.forEach((callback) => callback(0))
  }

  it("runs the callback once for any number of requests before the frame", () => {
    const callback = vi.fn()
    const scheduler = frameScheduler(callback)
    scheduler.schedule()
    scheduler.schedule()
    scheduler.schedule()
    expect(callback).not.toHaveBeenCalled()
    runFrames()
    expect(callback).toHaveBeenCalledTimes(1)
  })

  it("accepts a new request once the frame has run", () => {
    const callback = vi.fn()
    const scheduler = frameScheduler(callback)
    scheduler.schedule()
    runFrames()
    scheduler.schedule()
    runFrames()
    expect(callback).toHaveBeenCalledTimes(2)
  })

  it("runs nothing once cancelled, and accepts a request again", () => {
    const callback = vi.fn()
    const scheduler = frameScheduler(callback)
    scheduler.schedule()
    scheduler.cancel()
    runFrames()
    expect(callback).not.toHaveBeenCalled()
    scheduler.schedule()
    runFrames()
    expect(callback).toHaveBeenCalledTimes(1)
  })
})
