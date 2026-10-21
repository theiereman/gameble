import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import cardStylesheet from "../styles/card.css?raw"
import detailStylesheet from "../styles/card-detail.css?raw"
import {
  EASE_ENTER,
  EASE_LEAVE,
  HOLD_MS,
  REST,
  REST_REFLECTION,
  TOUCH_SLOP,
  attachTilt,
  easeToward,
  reflection,
  reflectionOf,
  tiltTarget,
} from "./tilt"

const RECT = { left: 100, top: 200, width: 160, height: 240 }
const ASPECT = RECT.width / RECT.height

describe("tiltTarget", () => {
  it("is at rest with the pointer at the centre", () => {
    expect(tiltTarget(180, 320, RECT, 10)).toEqual(REST)
  })

  it("lowers the side under the pointer", () => {
    // 25 % across, 25 % down.
    expect(tiltTarget(140, 260, RECT, 10)).toEqual({ rx: 5, ry: -5 })
    // The bottom right corner, a booster's strength.
    expect(tiltTarget(260, 440, RECT, 16)).toEqual({ rx: -16, ry: 16 })
  })

  it("stays within the card's edges", () => {
    expect(tiltTarget(0, 1000, RECT, 10)).toEqual(tiltTarget(100, 440, RECT, 10))
  })
})

describe("easeToward", () => {
  it("covers part of the way each frame, then snaps onto the target", () => {
    const target = { rx: 5, ry: -5 }
    let current = easeToward(REST, target, EASE_ENTER)
    expect(current.rx).toBeCloseTo(5 * EASE_ENTER)
    let frames = 1
    while (JSON.stringify(current) !== JSON.stringify(target) && frames < 500) {
      current = easeToward(current, target, EASE_ENTER)
      frames++
    }
    expect(current).toEqual(target)
    expect(frames).toBeLessThan(200)
  })
})

describe("reflection", () => {
  it("rests at the flat card's position", () => {
    expect(reflection(0, 0, 2 / 3)).toEqual({ strip: 30, fresnel: 0.8, horizon: -0.32, hue: 50 })
    expect(REST_REFLECTION).toEqual({ strip: 30, fresnel: 0.8, horizon: -0.32, hue: 50 })
  })

  it("slides opposite a corner brought down, and brightens up to a cap", () => {
    const corner = reflection(0.5, 0.5, 2 / 3)
    expect(corner.strip).toBeCloseTo(30 - 68.75 - 37.5)
    expect(corner.fresnel).toBeCloseTo(1.4)
    expect(corner.horizon).toBeCloseTo(-0.32 - 1.25 - 0.25 * (2 / 3))
    expect(corner.hue).toBeCloseTo(50 + 0.45 * 300)
    expect(reflection(0.5, -0.5, 2 / 3).fresnel).toBeCloseTo(1.4)
    expect(reflection(0.25, 0, 2 / 3).fresnel).toBeCloseTo(0.875)
  })

  it("weighs the ceiling's sideways slide by the card's shape", () => {
    expect(reflection(0.5, 0, 1).horizon).toBeCloseTo(-0.32 - 0.25)
    expect(reflection(0.5, 0, 0.5).horizon).toBeCloseTo(-0.32 - 0.125)
  })

  it("shifts the hues with the tilt, whatever the tilt's strength", () => {
    expect(reflectionOf({ rx: -10, ry: 10 }, 10, 2 / 3).hue).toBeCloseTo(185)
    expect(reflectionOf({ rx: 5, ry: -5 }, 10, 2 / 3).hue).toBeCloseTo(-17.5)
    expect(reflectionOf({ rx: -16, ry: 16 }, 16, 2 / 3)).toEqual(reflectionOf({ rx: -10, ry: 10 }, 10, 2 / 3))
  })

  it("is drawn at rest by the stylesheet's defaults", () => {
    const card = cardStylesheet.match(/^\.card \{([^}]*)\}/m)?.[1] ?? ""
    const value = (name: string) => card.match(new RegExp(`--reflection-${name}:\\s*([^;]+);`))?.[1].trim()
    expect(value("strip")).toBe(`${REST_REFLECTION.strip}%`)
    expect(value("fresnel")).toBe(`${REST_REFLECTION.fresnel}`)
    expect(value("horizon")).toBe(`${REST_REFLECTION.horizon}`)
    expect(value("hue")).toBe(`${REST_REFLECTION.hue}%`)
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

  const strip = (card: FakeCard) => parseFloat(card.properties.get("--reflection-strip") ?? "NaN")
  const hue = (card: FakeCard) => parseFloat(card.properties.get("--reflection-hue") ?? "NaN")

  it("follows a mouse, holds once settled, and lets go at rest", () => {
    const { card } = attach()

    card.dispatchEvent(pointer("pointermove", "mouse", 140, 260))
    expect(card.dataset.tilting).toBe("")
    runFrames(1)
    expect(card.dataset.tilt).toBe("moving")
    runFrames()
    expect(card.dataset.tilt).toBe("held")
    const held = reflectionOf({ rx: 5, ry: -5 }, 10, ASPECT)
    expect(Object.fromEntries(card.properties)).toEqual({
      "--tilt-rx": "5deg",
      "--tilt-ry": "-5deg",
      "--reflection-strip": `${held.strip}%`,
      "--reflection-fresnel": `${held.fresnel}`,
      "--reflection-horizon": `${held.horizon}`,
      "--reflection-hue": `${held.hue}%`,
    })

    card.dispatchEvent(pointer("pointerleave", "mouse", 300, 260))
    expect(card.dataset.tilting).toBeUndefined()
    runFrames()
    expect(card.dataset.tilt).toBeUndefined()
    expect(card.properties.size).toBe(0)
  })

  it("eases the reflection in from rest with the tilt, never jumping to the pointer", () => {
    const { card } = attach()
    const atCorner = reflectionOf({ rx: -10, ry: 10 }, 10, ASPECT)

    card.dispatchEvent(pointer("pointermove", "mouse", 260, 440))
    expect(card.properties.size).toBe(0)
    runFrames(1)
    const rest = REST_REFLECTION
    expect(strip(card)).toBeCloseTo(rest.strip + (atCorner.strip - rest.strip) * EASE_ENTER)
    expect(hue(card)).toBeCloseTo(rest.hue + (atCorner.hue - rest.hue) * EASE_ENTER)
    expect(parseFloat(card.properties.get("--reflection-fresnel") ?? "NaN")).toBeLessThan(atCorner.fresnel)

    let easedFrames = 1
    let previous = strip(card)
    while (card.dataset.tilt === "moving") {
      runFrames(1)
      expect(strip(card)).toBeLessThan(previous)
      expect(strip(card)).toBeGreaterThanOrEqual(atCorner.strip)
      previous = strip(card)
      easedFrames++
    }
    expect(easedFrames).toBeGreaterThan(20)
    expect(card.dataset.tilt).toBe("held")
    expect(card.properties.get("--reflection-strip")).toBe(`${atCorner.strip}%`)
  })

  it("eases the reflection back with the tilt once the pointer leaves, then clears it all", () => {
    const { card } = attach()
    const tilt = () => ["--tilt-rx", "--tilt-ry"].map((name) => Math.abs(parseFloat(card.properties.get(name) ?? "0")))

    card.dispatchEvent(pointer("pointermove", "mouse", 260, 440))
    runFrames()
    card.dispatchEvent(pointer("pointerleave", "mouse", 300, 440))

    let easedFrames = 0
    let previousStrip = strip(card)
    let previousTilt = tilt()
    while (frames.size > 0) {
      runFrames(1)
      if (card.properties.size === 0) break
      expect(strip(card) - REST_REFLECTION.strip).toBeCloseTo((previousStrip - REST_REFLECTION.strip) * (1 - EASE_LEAVE))
      tilt().forEach((angle, axis) => expect(angle).toBeLessThan(previousTilt[axis]))
      previousStrip = strip(card)
      previousTilt = tilt()
      easedFrames++
    }
    expect(easedFrames).toBeGreaterThan(20)
    expect(frames.size).toBe(0)
    expect(card.properties.size).toBe(0)
    expect(card.dataset.tilt).toBeUndefined()
    expect(card.dataset.tilting).toBeUndefined()
  })

  it("picks the reflection up where it is when the pointer comes back mid-way", () => {
    const { card } = attach()

    card.dispatchEvent(pointer("pointermove", "mouse", 260, 440))
    runFrames()
    card.dispatchEvent(pointer("pointerleave", "mouse", 300, 440))
    runFrames(10)
    const leaving = strip(card)
    card.dispatchEvent(pointer("pointermove", "mouse", 260, 440))
    expect(strip(card)).toBe(leaving)
    runFrames(1)
    expect(strip(card)).toBeLessThan(leaving)
    expect(card.dataset.tilting).toBe("")
  })

  it("tells where the eased tilt leans on every frame, and (0, 0) back at rest or detached", () => {
    const card = new FakeCard()
    const onTilt = vi.fn()
    const detach = attachTilt(card as unknown as HTMLElement, { max: 16, onTilt })

    card.dispatchEvent(pointer("pointermove", "mouse", 260, 440))
    expect(onTilt).not.toHaveBeenCalled()
    runFrames(1)
    expect(onTilt).toHaveBeenCalledTimes(1)
    const [dx, dy] = onTilt.mock.calls[0]
    expect(dx).toBeCloseTo(0.5 * EASE_ENTER)
    expect(dy).toBeCloseTo(0.5 * EASE_ENTER)
    runFrames()
    expect(onTilt).toHaveBeenLastCalledWith(0.5, 0.5)

    card.dispatchEvent(pointer("pointerleave", "mouse", 300, 440))
    runFrames()
    expect(onTilt).toHaveBeenLastCalledWith(0, 0)

    card.dispatchEvent(pointer("pointermove", "mouse", 260, 440))
    runFrames(3)
    onTilt.mockClear()
    detach()
    expect(onTilt).toHaveBeenCalledExactlyOnceWith(0, 0)
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
    expect(card.properties.get("--reflection-strip")).toBe(`${reflectionOf({ rx: -10, ry: 10 }, 10, ASPECT).strip}%`)

    card.dispatchEvent(pointer("pointerup", "touch", 260, 440))
    runFrames()
    expect(card.dataset.tilt).toBeUndefined()
    expect(card.dataset.tilting).toBeUndefined()
    expect(card.properties.size).toBe(0)
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
    expect(card.properties.size).toBe(0)
  })

  it("lets go when the browser cancels the pointer", () => {
    const { card } = attach()

    card.dispatchEvent(pointer("pointerdown", "touch", 140, 260))
    vi.advanceTimersByTime(HOLD_MS)
    card.dispatchEvent(pointer("pointercancel", "touch", 140, 260))
    runFrames()
    expect(card.dataset.tilt).toBeUndefined()
  })

  it("swallows a finger's menu while it tilts, and lets the mouse's through", () => {
    const { card } = attach()
    const menu = () => {
      const event = new Event("contextmenu", { cancelable: true })
      card.dispatchEvent(event)
      return event.defaultPrevented
    }

    card.dispatchEvent(pointer("pointerdown", "touch", 140, 260))
    vi.advanceTimersByTime(HOLD_MS)
    expect(menu()).toBe(true)
    card.dispatchEvent(pointer("pointerup", "touch", 140, 260))
    expect(menu()).toBe(false)

    card.dispatchEvent(pointer("pointermove", "mouse", 140, 260))
    runFrames(1)
    expect(menu()).toBe(false)
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

  it("keeps the card face unselectable and without the touch callout, and only the face", () => {
    const rule = (selector: string) => {
      const at = cardStylesheet.indexOf(`${selector} {`)
      return at < 0 ? undefined : cardStylesheet.slice(at, cardStylesheet.indexOf("}", at))
    }

    const card = rule(".card") ?? ""
    expect(card).toContain("-webkit-user-select: none")
    expect(card).toContain("user-select: none")
    expect(card).toContain("-webkit-touch-callout: none")
    expect(cardStylesheet.match(/^\s*user-select: none;/gm)).toHaveLength(1)
    expect(cardStylesheet.match(/^\s*-webkit-touch-callout: none;/gm)).toHaveLength(1)
  })

  it("disables the touch callout on links that wrap a card", () => {
    expect(detailStylesheet).toContain(".card-link:has(> .card)")
    const blocks = detailStylesheet.match(/\.card-link[^{]*\{[^}]*\}/g) ?? []
    const calloutBlocks = blocks.filter((block) => block.includes("-webkit-touch-callout"))
    expect(calloutBlocks.length).toBeGreaterThan(0)
    for (const block of calloutBlocks) expect(block).toContain(":has(> .card)")
  })

  it("undoes everything when detached, listeners included", () => {
    const { card, detach } = attach()
    const removeListener = vi.spyOn(card, "removeEventListener")

    card.dispatchEvent(pointer("pointermove", "mouse", 140, 260))
    runFrames(3)
    expect(card.properties.size).toBe(6)
    detach()
    expect(card.dataset.tilt).toBeUndefined()
    expect(card.dataset.tilting).toBeUndefined()
    expect(card.properties.size).toBe(0)
    expect(frames.size).toBe(0)
    expect(removeListener).toHaveBeenCalledWith("contextmenu", expect.any(Function))

    card.dispatchEvent(pointer("pointermove", "mouse", 140, 260))
    runFrames()
    expect(card.dataset.tilt).toBeUndefined()
  })
})
