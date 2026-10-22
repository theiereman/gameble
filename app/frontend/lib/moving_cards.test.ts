import { describe, expect, it } from "vitest"
import { CARD_DIMENSIONS, hasGutterRoom, laneBounds, placeCard, type Frame, type Placement } from "./moving_cards"

const lane = { start: 0, end: 300 }
const card: Placement = { anchor: 0.5, speed: 1.6, sway: 40, offset: 0, rotation: -8, ...CARD_DIMENSIONS.m, lane }
const frame: Frame = { scrollY: 2000, scrollable: 4000, viewportHeight: 1000, dragX: 0, dragY: 0 }

describe("hasGutterRoom", () => {
  it("needs the card, 16px and the side gauge's 96px on the left", () => {
    expect(hasGutterRoom(272, 168, 160)).toBe(true)
    expect(hasGutterRoom(271, 168, 160)).toBe(false)
  })

  it("needs the card and 8px on the right", () => {
    expect(hasGutterRoom(272, 167, 160)).toBe(false)
  })
})

describe("laneBounds", () => {
  it("keeps the left lane clear of the content and the side gauge", () => {
    expect(laneBounds("left", 340, 1460, 1800)).toEqual({ start: 96, end: 324 })
  })

  it("keeps the right lane clear of the content", () => {
    expect(laneBounds("right", 340, 1460, 1800)).toEqual({ start: 1468, end: 1800 })
  })
})

describe("placeCard", () => {
  it("sits at the viewport middle when the scroll reaches its anchor", () => {
    const at = placeCard(card, frame)
    expect(at.y).toBeCloseTo(500 - 120)
    expect(at.rotation).toBe(-8)
    expect(at.visible).toBe(true)
  })

  it("is 1600px below the middle, hidden, at scroll 1000", () => {
    const at = placeCard(card, { ...frame, scrollY: 1000 })
    expect(at.y).toBeCloseTo(500 + 1600 - 120)
    expect(at.visible).toBe(false)
  })

  it("moves faster than the scroll", () => {
    const first = placeCard(card, { ...frame, scrollY: 1900 })
    const second = placeCard(card, { ...frame, scrollY: 2000 })
    expect(first.y - second.y).toBeCloseTo(160)
  })

  it("turns with the distance", () => {
    expect(placeCard(card, { ...frame, scrollY: 1000 }).rotation).toBeCloseTo(-8 + 1000 * 0.004)
  })

  it("stays inside its lane however far it sways", () => {
    for (let scrollY = 0; scrollY <= 4000; scrollY += 37) {
      const at = placeCard({ ...card, sway: 500, offset: 0.4 }, { ...frame, scrollY })
      expect(at.x).toBeGreaterThanOrEqual(lane.start - 1e-9)
      expect(at.x + card.width).toBeLessThanOrEqual(lane.end + 1e-9)
    }
  })

  it("centres a card on a lane that only just holds it", () => {
    const at = placeCard({ ...card, lane: { start: 0, end: 160 } }, frame)
    expect(at.x).toBe(0)
  })

  it("adds the drag to the position and keeps it through the scroll", () => {
    const dragged = { ...frame, dragX: 100, dragY: -30 }
    const rest = placeCard(card, frame)
    const moved = placeCard(card, dragged)
    expect(moved.x - rest.x).toBe(100)
    expect(moved.y - rest.y).toBe(-30)
    const later = placeCard(card, { ...dragged, scrollY: 2100 })
    const laterRest = placeCard(card, { ...frame, scrollY: 2100 })
    expect(later.x - laterRest.x).toBeCloseTo(100)
  })

  it("shows a card up to the 160px margin and hides it beyond", () => {
    const edge = (y: number) => placeCard({ ...card, anchor: 0, speed: 1 }, { ...frame, scrollY: 0, dragY: y - 500 + 120 })
    expect(edge(-399).visible).toBe(true)
    expect(edge(-401).visible).toBe(false)
    expect(edge(1159).visible).toBe(true)
    expect(edge(1161).visible).toBe(false)
  })

  it("does not break on a page that does not scroll", () => {
    expect(placeCard(card, { ...frame, scrollable: 0, scrollY: 0 }).y).toBeCloseTo(500 - 120)
  })
})
