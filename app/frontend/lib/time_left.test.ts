import { describe, expect, it } from "vitest"
import { msToNextChange, timeLeft } from "./time_left"

describe("timeLeft", () => {
  it("reads under a minute below 60 seconds, zero and negative included", () => {
    expect(timeLeft(59).kind).toBe("under")
    expect(timeLeft(0).kind).toBe("under")
    expect(timeLeft(-5).kind).toBe("under")
  })

  it("reads whole minutes from 60 seconds to under an hour", () => {
    expect(timeLeft(60)).toEqual({ kind: "minutes", hours: 0, minutes: 1 })
    expect(timeLeft(59 * 60 + 59)).toEqual({ kind: "minutes", hours: 0, minutes: 59 })
  })

  it("reads hours and minutes from an hour", () => {
    expect(timeLeft(3600)).toEqual({ kind: "hours", hours: 1, minutes: 0 })
    expect(timeLeft(134 * 60 + 30)).toEqual({ kind: "hours", hours: 2, minutes: 14 })
  })
})

describe("msToNextChange", () => {
  it("waits for the seconds past the whole minute", () => {
    expect(msToNextChange(134 * 60 + 30)).toBe(30_001)
  })

  it("changes at once on a whole minute", () => {
    expect(msToNextChange(120)).toBe(1)
  })

  it("never changes again under a minute", () => {
    expect(msToNextChange(59)).toBeNull()
    expect(msToNextChange(-1)).toBeNull()
  })
})
