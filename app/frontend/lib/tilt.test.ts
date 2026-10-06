import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import { HOLD_MS, REST, TOUCH_SLOP, attachTilt, easeToward, tiltTarget } from "./tilt"

const RECT = { left: 100, top: 200, width: 160, height: 240 }

describe("tiltTarget", () => {
  it("is at rest with the pointer at the centre", () => {
    expect(tiltTarget(180, 320, RECT, 10)).toEqual(REST)
  })

  it("lowers the side under the pointer, glare under it", () => {
    // 25 % across, 25 % down.
    expect(tiltTarget(140, 260, RECT, 10)).toEqual({ rx: 5, ry: -5, glareDx: -40, glareDy: -60 })
    // The bottom right corner, a booster's strength.
    expect(tiltTarget(260, 440, RECT, 16)).toEqual({ rx: -16, ry: 16, glareDx: 80, glareDy: 120 })
  })

  it("stays within the card's edges", () => {
    expect(tiltTarget(0, 1000, RECT, 10)).toEqual(tiltTarget(100, 440, RECT, 10))
  })
})

describe("easeToward", () => {
  it("covers part of the way each frame, then snaps onto the target", () => {
    const target = { rx: 5, ry: -5, glareDx: 40, glareDy: -60 }
    let current = easeToward(REST, target)
    expect(current.rx).toBeCloseTo(0.8)
    let frames = 1
    while (JSON.stringify(current) !== JSON.stringify(target) && frames < 200) {
      current = easeToward(current, target)
      frames++
    }
    expect(current).toEqual(target)
    expect(frames).toBeLessThan(100)
  })
})

// A card stand-in: events, a dataset, custom properties and a layout box.
class FakeCard extends EventTarget {
  dataset: Record<string, string> = {}
  properties = new Map<string, string>()
  style = {
    setProperty: (name: string, value: string) => this.properties.set(name, value),
    removeProperty: (name: string) => this.properties.delete(name),
  }
  offsetWidth = RECT.width
  offsetHeight = RECT.height
  getBoundingClientRect() {
    return { ...RECT }
  }
}

function pointer(type: string, pointerType: string, x: number, y: number, pointerId = 1): Event {
  return Object.assign(new Event(type), { pointerType, pointerId, clientX: x, clientY: y })
}

describe("attachTilt", () => {
  let frames: Map<number, FrameRequestCallback>
  let nextFrame: number

  const runFrames = (count = 500) => {
    for (let i = 0; i < count && frames.size > 0; i++) {
      const pending = [...frames.entries()]
      frames.clear()
      for (const [, callback] of pending) callback(0)
    }
  }

  beforeEach(() => {
    frames = new Map()
    nextFrame = 1
    vi.useFakeTimers()
    vi.stubGlobal("requestAnimationFrame", (callback: FrameRequestCallback) => {
      const id = nextFrame++
      frames.set(id, callback)
      return id
    })
    vi.stubGlobal("cancelAnimationFrame", (id: number) => frames.delete(id))
  })

  afterEach(() => {
    vi.useRealTimers()
    vi.unstubAllGlobals()
  })

  const attach = (max = 10) => {
    const card = new FakeCard()
    const detach = attachTilt(card as unknown as HTMLElement, { max })
    return { card, detach }
  }

  it("follows a mouse, holds once settled, and lets go at rest", () => {
    const { card } = attach()

    card.dispatchEvent(pointer("pointermove", "mouse", 140, 260))
    expect(card.dataset.tilting).toBe("")
    runFrames(1)
    expect(card.dataset.tilt).toBe("moving")
    runFrames()
    expect(card.dataset.tilt).toBe("held")
    expect(card.properties.get("--tilt-rx")).toBe("5deg")
    expect(card.properties.get("--tilt-ry")).toBe("-5deg")
    expect(card.properties.get("--glare-dx")).toBe("-40px")
    expect(card.properties.get("--glare-dy")).toBe("-60px")

    card.dispatchEvent(pointer("pointerleave", "mouse", 300, 260))
    expect(card.dataset.tilting).toBeUndefined()
    runFrames()
    expect(card.dataset.tilt).toBeUndefined()
    expect(card.properties.size).toBe(0)
  })

  it("marks a card driven but resting at its centre neither moving nor held", () => {
    const { card } = attach()

    card.dispatchEvent(pointer("pointermove", "mouse", 140, 260))
    runFrames()
    card.dispatchEvent(pointer("pointermove", "mouse", 180, 320))
    runFrames()
    expect(card.dataset.tilting).toBe("")
    expect(card.dataset.tilt).toBeUndefined()
  })

  it("tilts under a finger held still, until it is lifted", () => {
    const { card } = attach()

    card.dispatchEvent(pointer("pointerdown", "touch", 140, 260))
    runFrames()
    expect(card.dataset.tilting).toBeUndefined()
    vi.advanceTimersByTime(HOLD_MS)
    expect(card.dataset.tilting).toBe("")
    card.dispatchEvent(pointer("pointermove", "touch", 260, 440))
    runFrames()
    expect(card.dataset.tilt).toBe("held")
    expect(card.properties.get("--tilt-rx")).toBe("-10deg")

    card.dispatchEvent(pointer("pointerup", "touch", 260, 440))
    runFrames()
    expect(card.dataset.tilt).toBeUndefined()
    expect(card.dataset.tilting).toBeUndefined()
  })

  it("swallows the click that follows a finger's tilt, and only that one", () => {
    const { card } = attach()
    const click = () => {
      const event = new Event("click", { cancelable: true })
      card.dispatchEvent(event)
      return event.defaultPrevented
    }

    card.dispatchEvent(pointer("pointerdown", "touch", 140, 260))
    vi.advanceTimersByTime(HOLD_MS)
    card.dispatchEvent(pointer("pointerup", "touch", 140, 260))
    expect(click()).toBe(true)
    expect(click()).toBe(false)

    // A quick tap tilts nothing and clicks.
    card.dispatchEvent(pointer("pointerdown", "touch", 140, 260))
    card.dispatchEvent(pointer("pointerup", "touch", 140, 260))
    expect(click()).toBe(false)
  })

  it("leaves a finger that moves first to scroll", () => {
    const { card } = attach()

    card.dispatchEvent(pointer("pointerdown", "touch", 140, 260))
    card.dispatchEvent(pointer("pointermove", "touch", 140, 260 + TOUCH_SLOP + 1))
    vi.advanceTimersByTime(HOLD_MS)
    runFrames()
    expect(card.dataset.tilting).toBeUndefined()
    expect(card.dataset.tilt).toBeUndefined()
  })

  it("lets go when the browser cancels the pointer", () => {
    const { card } = attach()

    card.dispatchEvent(pointer("pointerdown", "touch", 140, 260))
    vi.advanceTimersByTime(HOLD_MS)
    card.dispatchEvent(pointer("pointercancel", "touch", 140, 260))
    runFrames()
    expect(card.dataset.tilt).toBeUndefined()
  })

  it("does nothing under reduced motion", () => {
    vi.stubGlobal("document", { documentElement: { dataset: { motion: "reduced" } } })
    const { card } = attach()

    card.dispatchEvent(pointer("pointermove", "mouse", 140, 260))
    card.dispatchEvent(pointer("pointerdown", "touch", 140, 260, 2))
    vi.advanceTimersByTime(HOLD_MS)
    runFrames()
    expect(card.dataset.tilt).toBeUndefined()
    expect(card.dataset.tilting).toBeUndefined()
    expect(card.properties.size).toBe(0)
  })

  it("undoes everything when detached, listeners included", () => {
    const { card, detach } = attach()

    card.dispatchEvent(pointer("pointermove", "mouse", 140, 260))
    runFrames(3)
    detach()
    expect(card.dataset.tilt).toBeUndefined()
    expect(card.dataset.tilting).toBeUndefined()
    expect(card.properties.size).toBe(0)
    expect(frames.size).toBe(0)

    card.dispatchEvent(pointer("pointermove", "mouse", 140, 260))
    runFrames()
    expect(card.dataset.tilt).toBeUndefined()
  })
})
