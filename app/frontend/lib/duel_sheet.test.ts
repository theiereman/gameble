import { describe, expect, it } from "vitest"
import {
  challengeSent,
  focusAfter,
  friendToSelect,
  isBlocked,
  outcomeArrived,
  startSheet,
  type FriendOption,
} from "./duel_sheet"

describe("duel sheet state", () => {
  it("starts choosing, or waiting when the server renders a waiting challenge", () => {
    expect(startSheet(false)).toEqual({ phase: "choosing", landing: null })
    expect(startSheet(true)).toEqual({ phase: "waiting", landing: null })
  })

  it("waits once the challenge is sent, and only from choosing", () => {
    expect(challengeSent(startSheet(false)).phase).toBe("waiting")
    const ended = outcomeArrived(startSheet(true), null)
    expect(challengeSent(ended)).toBe(ended)
  })

  it("ends on an outcome and remembers where to land", () => {
    expect(outcomeArrived(startSheet(true), "/en/duels/abc")).toEqual({ phase: "ended", landing: "/en/duels/abc" })
    expect(outcomeArrived(startSheet(true), "").landing).toBeNull()
  })

  it("blocks only a radio marked aria-disabled", () => {
    expect(isBlocked("true")).toBe(true)
    expect(isBlocked("false")).toBe(false)
    expect(isBlocked(null)).toBe(false)
  })

  it("selects the friend of an opener unless that friend is disabled or unknown", () => {
    const options: FriendOption[] = [
      { token: "hugo", ariaDisabled: null },
      { token: "max", ariaDisabled: "true" },
    ]
    expect(friendToSelect(options, "hugo")).toBe("hugo")
    expect(friendToSelect(options, "max")).toBeUndefined()
    expect(friendToSelect(options, "nobody")).toBeUndefined()
    expect(friendToSelect(options, undefined)).toBeUndefined()
  })

  it("focuses the choice, the waiting block or the outcome line by phase", () => {
    expect(focusAfter(startSheet(false))).toBe("choice")
    expect(focusAfter(startSheet(true))).toBe("waiting")
    expect(focusAfter(outcomeArrived(startSheet(true), null))).toBe("outcome")
  })
})
