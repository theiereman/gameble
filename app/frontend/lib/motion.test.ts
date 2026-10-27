import { afterEach, describe, expect, it, vi } from "vitest"
import { motionReduced, onMotionChange, REDUCED_MOTION_QUERY } from "./motion"

// The module reads `document` and `window` at call time; the tests stand
// them in with plain objects (the suite runs in node).
function stubPage(motion: string | undefined, systemReduces: boolean) {
  const dataset: Record<string, string | undefined> = { motion }
  const listeners = new Set<() => void>()
  const observers: Array<() => void> = []
  const root = { dataset }
  vi.stubGlobal("document", { documentElement: root })
  vi.stubGlobal("window", {
    matchMedia: (query: string) => ({
      matches: query === REDUCED_MOTION_QUERY && systemReduces,
      addEventListener: (_: string, listener: () => void) => listeners.add(listener),
      removeEventListener: (_: string, listener: () => void) => listeners.delete(listener),
    }),
  })
  vi.stubGlobal(
    "MutationObserver",
    class {
      constructor(private readonly callback: () => void) {}
      observe() {
        observers.push(this.callback)
      }
      disconnect() {
        observers.splice(observers.indexOf(this.callback), 1)
      }
    },
  )
  return {
    setMotion(value: string | undefined) {
      dataset.motion = value
      observers.slice().forEach((callback) => callback())
    },
    listeners,
    observers,
  }
}

afterEach(() => vi.unstubAllGlobals())

describe("motionReduced", () => {
  it("is on when html[data-motion] says reduced, whatever the system prefers", () => {
    stubPage("reduced", false)
    expect(motionReduced()).toBe(true)
  })

  it("is off when html[data-motion] says full, even when the system asks for reduced motion", () => {
    stubPage("full", true)
    expect(motionReduced()).toBe(false)
  })

  it("follows the system when the attribute is absent", () => {
    stubPage(undefined, true)
    expect(motionReduced()).toBe(true)
    stubPage(undefined, false)
    expect(motionReduced()).toBe(false)
  })

  it("is read at the moment of use", () => {
    const page = stubPage(undefined, false)
    expect(motionReduced()).toBe(false)
    page.setMotion("reduced")
    expect(motionReduced()).toBe(true)
  })
})

describe("onMotionChange", () => {
  it("tells the listener when the attribute flips, once per change", () => {
    const page = stubPage(undefined, false)
    const listener = vi.fn()
    const stop = onMotionChange(listener)

    page.setMotion("reduced")
    page.setMotion("reduced")
    expect(listener).toHaveBeenCalledTimes(1)
    expect(listener).toHaveBeenLastCalledWith(true)

    page.setMotion(undefined)
    expect(listener).toHaveBeenLastCalledWith(false)
    stop()
  })

  it("tells the listener when the attribute forces full motion over the system's reduced motion, and when it is removed", () => {
    const page = stubPage(undefined, true)
    const listener = vi.fn()
    const stop = onMotionChange(listener)

    page.setMotion("full")
    expect(listener).toHaveBeenLastCalledWith(false)

    page.setMotion(undefined)
    expect(listener).toHaveBeenLastCalledWith(true)
    expect(listener).toHaveBeenCalledTimes(2)
    stop()
  })

  it("stays quiet when the system preference flips under a forced full motion", () => {
    const page = stubPage("full", false)
    const listener = vi.fn()
    onMotionChange(listener)

    vi.stubGlobal("window", {
      matchMedia: () => ({ matches: true, addEventListener: () => {}, removeEventListener: () => {} }),
    })
    page.listeners.forEach((check) => check())

    expect(listener).not.toHaveBeenCalled()
  })

  it("tells the listener when the system preference flips", () => {
    const page = stubPage(undefined, false)
    const listener = vi.fn()
    onMotionChange(listener)

    vi.stubGlobal("window", {
      matchMedia: () => ({ matches: true, addEventListener: () => {}, removeEventListener: () => {} }),
    })
    page.listeners.forEach((check) => check())

    expect(listener).toHaveBeenCalledWith(true)
  })

  it("stops listening when asked", () => {
    const page = stubPage(undefined, false)
    const stop = onMotionChange(vi.fn())
    expect(page.observers).toHaveLength(1)
    expect(page.listeners.size).toBe(1)

    stop()

    expect(page.observers).toHaveLength(0)
    expect(page.listeners.size).toBe(0)
  })
})
