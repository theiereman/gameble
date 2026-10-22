import { describe, expect, it } from "vitest"
import {
  approach,
  FOUND_HOLD_MS,
  Lamp,
  type LampCard,
  type LampInput,
  lampMode,
  MANUAL_HOLD_MS,
  pointerHeld,
  powerAt,
  RADII_DESKTOP,
  scaleRadii,
  wanderPoint
} from "./lamp"

const area = { width: 500, height: 400 }
const cards: LampCard[] = [
  { x: 100, y: 100, radius: 40 },
  { x: 400, y: 100, radius: 40 },
  { x: 250, y: 320, radius: 40 }
]

const idle = (now: number, dt = 0.016): LampInput => ({ now, dt, reduced: false, pointer: null, pointerHeld: false })

function run(lamp: Lamp, from: number, until: number, input: (now: number) => LampInput = idle) {
  let frame = lamp.advance(input(from))
  for (let now = from + 16; now <= until; now += 16) frame = lamp.advance(input(now))
  return frame
}

describe("powerAt", () => {
  it("is dark until the delay, then climbs in five steps over 300ms", () => {
    expect(powerAt(0)).toBe(0)
    expect(powerAt(350)).toBe(0)
    expect(powerAt(410)).toBe(0.2)
    expect(powerAt(500)).toBe(0.6)
    expect(powerAt(650)).toBe(1)
    expect(powerAt(5000)).toBe(1)
  })
})

describe("scaleRadii", () => {
  it("scales the three radii by the power", () => {
    expect(scaleRadii([70, 96, 124], 0.5)).toEqual([35, 48, 62])
    expect(scaleRadii([70, 96, 124], 0)).toEqual([0, 0, 0])
  })
})

describe("approach", () => {
  it("moves a share of the gap and never overshoots", () => {
    const next = approach(0, 100, 0.1, 12)
    expect(next).toBeGreaterThan(50)
    expect(next).toBeLessThan(100)
    expect(approach(0, 100, 0, 12)).toBe(0)
  })
})

describe("wanderPoint", () => {
  it("stays inside the area", () => {
    for (let seconds = 0; seconds < 60; seconds += 0.5) {
      const point = wanderPoint(area, seconds)
      expect(point.x).toBeGreaterThan(0)
      expect(point.x).toBeLessThan(area.width)
      expect(point.y).toBeGreaterThan(0)
      expect(point.y).toBeLessThan(area.height)
    }
  })
})

describe("pointerHeld and lampMode", () => {
  it("holds a mouse inside the field for 2.5s after its last move", () => {
    const base = { inside: true, movedAt: 1000, now: 1000 + MANUAL_HOLD_MS - 1 }
    expect(pointerHeld(base)).toBe(true)
    expect(pointerHeld({ ...base, now: 1000 + MANUAL_HOLD_MS })).toBe(false)
    expect(pointerHeld({ ...base, inside: false })).toBe(false)
  })

  it("names the mode: still under reduced motion, else manual or auto", () => {
    expect(lampMode({ reduced: true, pointerHeld: true })).toBe("still")
    expect(lampMode({ reduced: false, pointerHeld: true })).toBe("manual")
    expect(lampMode({ reduced: false, pointerHeld: false })).toBe("auto")
  })
})

describe("Lamp", () => {
  it("starts dark and finds nothing before it is fully lit", () => {
    const lamp = new Lamp(cards, area, RADII_DESKTOP, 0)
    const frame = lamp.advance(idle(100))
    expect(frame.power).toBe(0)
    expect(frame.radii).toEqual([0, 0, 0])
    expect(frame.found).toEqual([false, false, false])
    expect(frame.lit).toEqual([false, false, false])
  })

  it("sweeps on its own to the first card, finds it and holds there", () => {
    const lamp = new Lamp(cards, area, RADII_DESKTOP, 0)
    const frame = run(lamp, 0, 1200)
    expect(frame.mode).toBe("auto")
    expect(frame.found[0]).toBe(true)
    expect(frame.foundCount).toBeGreaterThanOrEqual(1)
  })

  it("holds on a find before heading for the next card", () => {
    const lamp = new Lamp(cards, area, RADII_DESKTOP, 0)
    let foundAt = 0
    let now = 0
    while (!lamp.advance(idle(now)).found[0]) now += 16
    foundAt = now
    const during = run(lamp, foundAt, foundAt + FOUND_HOLD_MS - 100)
    expect(Math.hypot(during.x - cards[0].x, during.y - cards[0].y)).toBeLessThan(RADII_DESKTOP[0])
    const after = run(lamp, foundAt + FOUND_HOLD_MS - 100, foundAt + FOUND_HOLD_MS + 4000)
    expect(after.x).toBeGreaterThan(cards[0].x + 50)
  })

  it("holds on a card found while heading elsewhere", () => {
    const lamp = new Lamp(cards, area, RADII_DESKTOP, 0)
    let now = 0
    while (!lamp.advance({ now, dt: 0.016, reduced: false, pointer: { x: 400, y: 100 }, pointerHeld: true }).found[1]) now += 16
    const held = run(lamp, now, now + FOUND_HOLD_MS - 200)
    expect(Math.hypot(held.x - 400, held.y - 100)).toBeLessThan(RADII_DESKTOP[0])
  })

  it("keeps the found cards it is given, when the counts match", () => {
    const lamp = new Lamp(cards, area, RADII_DESKTOP, 0)
    lamp.keepFound([true, false, true])
    expect(lamp.advance(idle(0)).found).toEqual([true, false, true])
    lamp.keepFound([true])
    expect(lamp.advance(idle(16)).found).toEqual([true, false, true])
  })

  it("follows a held pointer quickly and finds the card under it", () => {
    const lamp = new Lamp(cards, area, RADII_DESKTOP, 0)
    const frame = run(lamp, 0, 1500, (now) => ({ now, dt: 0.016, reduced: false, pointer: { x: 400, y: 100 }, pointerHeld: true }))
    expect(frame.mode).toBe("manual")
    expect(frame.found).toEqual([false, true, false])
    expect(frame.lit[1]).toBe(true)
  })

  it("counts each card once, settles on the last one found and stops", () => {
    const lamp = new Lamp(cards, area, RADII_DESKTOP, 0)
    const frame = run(lamp, 0, 60000)
    expect(frame.foundCount).toBe(3)
    expect(frame.settled).toBe(true)
    expect(frame.mode).toBe("auto")
    const again = lamp.advance(idle(60016))
    expect(again.foundCount).toBe(3)
    expect(again.x).toBeCloseTo(frame.x, 1)
  })

  it("is not settled while a card remains or while a pointer holds the lamp", () => {
    const lamp = new Lamp(cards, area, RADII_DESKTOP, 0)
    expect(run(lamp, 0, 500).settled).toBe(false)
    run(lamp, 500, 60000)
    const held = lamp.advance({ now: 60100, dt: 0.016, reduced: false, pointer: { x: 10, y: 10 }, pointerHeld: true })
    expect(held.settled).toBe(false)
  })

  it("rests on the first card with two found under reduced motion, and jumps to the pointer", () => {
    const lamp = new Lamp(cards, area, RADII_DESKTOP, 0)
    lamp.startReduced()
    const rest = lamp.advance({ now: 0, dt: 0, reduced: true, pointer: null, pointerHeld: false })
    expect(rest).toMatchObject({ x: 100, y: 100, power: 1, mode: "still", found: [true, true, false], foundCount: 2 })

    const jumped = lamp.advance({ now: 10, dt: 0, reduced: true, pointer: { x: 250, y: 320 }, pointerHeld: false })
    expect(jumped).toMatchObject({ x: 250, y: 320, found: [true, true, true], foundCount: 3 })

    const left = lamp.advance({ now: 20, dt: 0, reduced: true, pointer: null, pointerHeld: false })
    expect(left).toMatchObject({ x: 100, y: 100, foundCount: 3 })
  })

  it("wanders when there is no card at all", () => {
    const lamp = new Lamp([], area, RADII_DESKTOP, 0)
    const frame = run(lamp, 0, 2000)
    expect(frame.foundCount).toBe(0)
    expect(frame.settled).toBe(false)
  })
})
