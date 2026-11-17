import { describe, expect, it } from "vitest"
import { linkChecked, linkSecondsLeft, startLink } from "./duel_link"

describe("the player's own connection", () => {
  it("is not lost while the cable has not connected yet", () => {
    expect(linkChecked(startLink(), false, true, 0).lostAt).toBeNull()
  })

  it("is lost once a connected cable drops, or at once when the browser goes offline", () => {
    const seen = linkChecked(startLink(), true, true, 0)
    const dropped = linkChecked(seen, false, true, 5000)

    expect(dropped.lostAt).toBe(5000)
    expect(linkChecked(startLink(), false, false, 7000).lostAt).toBe(7000)
  })

  it("keeps the instant it was lost and forgets it on return", () => {
    const dropped = linkChecked(linkChecked(startLink(), true, true, 0), false, true, 5000)

    expect(linkChecked(dropped, false, true, 9000).lostAt).toBe(5000)
    expect(linkChecked(dropped, true, true, 9000).lostAt).toBeNull()
  })

  it("counts the minute down from the loss and stops at zero", () => {
    const dropped = linkChecked(linkChecked(startLink(), true, true, 0), false, true, 1000)

    expect(linkSecondsLeft(startLink(), 0)).toBeNull()
    expect(linkSecondsLeft(dropped, 1000)).toBe(60)
    expect(linkSecondsLeft(dropped, 21_500)).toBe(40)
    expect(linkSecondsLeft(dropped, 99_000)).toBe(0)
  })
})
