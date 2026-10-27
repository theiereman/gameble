import { describe, expect, it } from "vitest"
import { CENTRE, irisOrigin, turnsFrom } from "./set_tile_iris"

const box = { left: 100, top: 40, width: 400, height: 280 }

describe("irisOrigin", () => {
  it("is the pointer's place inside the tile", () => {
    expect(irisOrigin(box, { clientX: 130, clientY: 60 })).toEqual({ x: "30px", y: "20px" })
  })

  it("rounds to whole pixels", () => {
    expect(irisOrigin(box, { clientX: 130.6, clientY: 60.4 })).toEqual({ x: "31px", y: "20px" })
  })

  it("stays on the tile when the pointer entered a hair outside it", () => {
    expect(irisOrigin(box, { clientX: 90, clientY: 400 })).toEqual({ x: "0px", y: "280px" })
  })

  it("is the centre without a pointer", () => {
    expect(irisOrigin(box, null)).toEqual(CENTRE)
  })
})

describe("turnsFrom", () => {
  it("accepts a mouse and a pen, not a finger", () => {
    expect(["mouse", "pen", "touch"].map(turnsFrom)).toEqual([true, true, false])
  })
})
