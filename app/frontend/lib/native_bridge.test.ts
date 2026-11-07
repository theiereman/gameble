import { describe, expect, it } from "vitest"

import { IMPACTS, pushGrant } from "./native_bridge"
import { RARITIES } from "./card_types"

describe("IMPACTS", () => {
  it("gives every rarity a haptic, stronger for the rarer cards", () => {
    expect(RARITIES.map((rarity) => IMPACTS[rarity])).toEqual(["light", "light", "medium", "heavy", "heavy"])
  })
})

describe("pushGrant", () => {
  it("reads the token and platform the app answers with", () => {
    expect(pushGrant({ token: "abc", platform: "apple", metadata: {} })).toEqual({ token: "abc", platform: "apple" })
  })

  it("is null when the player refused or the app sent no token", () => {
    expect(pushGrant({ granted: false })).toBeNull()
    expect(pushGrant({ token: "", platform: "google" })).toBeNull()
    expect(pushGrant({ token: 12, platform: "google" })).toBeNull()
  })
})
