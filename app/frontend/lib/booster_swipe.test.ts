import { describe, expect, it } from "vitest"
import { SWIPE_START } from "./booster_motion"
import { CardSwipe, dragTransform } from "./booster_swipe"

const at = (x: number, y: number, id = 7) => ({ id, x, y })

describe("CardSwipe", () => {
  it("drags once the pointer travels past the start distance, then releases with the distance travelled", () => {
    const swipe = new CardSwipe()
    swipe.press(at(100, 100), 2, false)
    expect(swipe.active).toBe(true)
    expect(swipe.index).toBe(2)
    expect(swipe.move(at(100 + SWIPE_START, 100), false)).toEqual({ kind: "none" })
    expect(swipe.move(at(130, 110), false)).toEqual({ kind: "started", dx: 30, dy: 10 })
    expect(swipe.move(at(160, 110), false)).toEqual({ kind: "dragging", dx: 60, dy: 10 })
    expect(swipe.end(at(220, 90), false, 5000)).toEqual({ index: 2, dx: 120, dy: -10, abandoned: false })
    expect(swipe.active).toBe(false)
    expect(swipe.lastDragEnd).toBe(5000)
  })

  it("lets a tap through: no release, no drag end", () => {
    const swipe = new CardSwipe()
    swipe.press(at(10, 10), 0, false)
    expect(swipe.end(at(12, 11), false, 900)).toBeNull()
    expect(swipe.lastDragEnd).toBe(-Infinity)
  })

  it("ignores another pointer and a second press while one is held", () => {
    const swipe = new CardSwipe()
    swipe.press(at(0, 0), 0, false)
    swipe.press(at(0, 0, 9), 1, false)
    expect(swipe.index).toBe(0)
    expect(swipe.move(at(50, 0, 9), false)).toEqual({ kind: "none" })
    expect(swipe.end(at(50, 0, 9), false, 1)).toBeNull()
    expect(swipe.active).toBe(true)
  })

  it("turns a gesture that starts tilting into a tilt: no drag, abandoned when it had dragged", () => {
    const still = new CardSwipe()
    still.press(at(0, 0), 0, false)
    expect(still.move(at(1, 0), true)).toEqual({ kind: "none" })
    expect(still.move(at(120, 0), true)).toEqual({ kind: "none" })
    expect(still.end(at(120, 0), false, 1)).toBeNull()

    const dragged = new CardSwipe()
    dragged.press(at(0, 0), 0, false)
    dragged.move(at(40, 0), false)
    dragged.move(at(60, 0), true)
    expect(dragged.end(at(80, 0), false, 1)).toMatchObject({ abandoned: true })
  })

  it("does not count a tilt mark already there at the press", () => {
    const swipe = new CardSwipe()
    swipe.press(at(0, 0), 0, true)
    expect(swipe.move(at(40, 0), true)).toEqual({ kind: "started", dx: 40, dy: 0 })
  })

  it("abandons a cancelled drag, and forgets a gesture on demand", () => {
    const swipe = new CardSwipe()
    swipe.press(at(0, 0), 0, false)
    swipe.move(at(40, 0), false)
    expect(swipe.end(at(40, 0), true, 3)).toMatchObject({ abandoned: true })

    swipe.press(at(0, 0), 1, false)
    swipe.forget()
    expect(swipe.active).toBe(false)
    expect(swipe.move(at(40, 0), false)).toEqual({ kind: "none" })
  })
})

describe("dragTransform", () => {
  it("follows the finger in whole pixels with a slight rotation", () => {
    expect(dragTransform(30.4, -10.6)).toBe("translate(30px, -11px) rotate(1.52deg)")
  })
})
