import { describe, expect, it } from "vitest"
import { clockText, inAlert, secondsLeft, shouldAnnounce, startClock } from "./duel_clock"

describe("duel clock", () => {
  it("counts from the server's time to the deadline, not from the browser's", () => {
    const clock = startClock("2026-11-16T10:01:00.000Z", "2026-11-16T10:00:15.000Z")

    expect(clock?.total).toBe(45)
    expect(secondsLeft(clock!, 0)).toBe(45)
    expect(secondsLeft(clock!, 1500)).toBe(44)
    expect(secondsLeft(clock!, 60_000)).toBe(0)
  })

  it("has no clock without a readable deadline", () => {
    expect(startClock("later", "2026-11-16T10:00:00.000Z")).toBeNull()
  })

  it("turns to the alert colour from ten seconds", () => {
    expect(inAlert(11)).toBe(false)
    expect(inAlert(10)).toBe(true)
  })

  it("announces the ten seconds once, and never at zero", () => {
    const clock = startClock("2026-11-16T10:01:00.000Z", "2026-11-16T10:00:15.000Z")!

    expect(shouldAnnounce(clock, 11)).toBe(false)
    expect(shouldAnnounce(clock, 10)).toBe(true)
    expect(shouldAnnounce({ ...clock, announced: true }, 9)).toBe(false)
    expect(shouldAnnounce(clock, 0)).toBe(false)
  })

  it("fills the seconds into the translated template", () => {
    expect(clockText("{seconds} s", 42)).toBe("42 s")
  })
})
