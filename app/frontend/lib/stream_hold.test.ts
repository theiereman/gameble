import { describe, expect, it } from "vitest"
import { StreamHold } from "./stream_hold"

describe("StreamHold", () => {
  it("is free until a reason is added", () => {
    const hold = new StreamHold<string>(5)
    expect(hold.held).toBe(false)
    hold.hold("hover")
    expect(hold.held).toBe(true)
  })

  it("hands the waiting batches over in order once the last reason ends", () => {
    const hold = new StreamHold<string>(5)
    hold.hold("hover")
    hold.hold("focus")
    hold.defer(["a"])
    hold.defer(["b", "c"])
    expect(hold.release("hover")).toEqual([])
    expect(hold.release("focus")).toEqual([["a"], ["b", "c"]])
    expect(hold.release("focus")).toEqual([])
  })

  it("drops the oldest batches once more than it keeps are waiting", () => {
    const hold = new StreamHold<string>(3)
    hold.hold("hover")
    hold.defer(["a", "b"])
    hold.defer(["c", "d"])
    hold.defer(["e"])
    expect(hold.release("hover")).toEqual([["c", "d"], ["e"]])
  })
})
