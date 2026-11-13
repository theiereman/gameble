import { describe, expect, it } from "vitest"
import { start, toggle, type Copy } from "./entrust"
import { recapViewOf, type EntrustStrings } from "./entrust_view"

const STRINGS: EntrustStrings = {
  amount: "%{amount} PiCoins",
  quantityLabel: "Copies of %{title}",
  valueText: "%{count} of %{max}",
  max: "of %{max}",
  maxPhone: "/%{max}",
  submit: { one: "Entrust %{count} copy", other: "Entrust %{count} copies", zero: "Entrust" },
  line: "%{title}, season %{season}",
  count: "×%{count}",
  stays: "%{count} stays",
  overCap: "over",
  rareNote: "rare",
  capText: "%{used} of %{cap} today",
  status: { one: "%{count} copy, %{amount}", other: "%{count} copies, %{amount}", zero: "0 copies, %{amount}" },
  barCount: { one: "%{count} copy", other: "%{count} copies", zero: "0 copies" },
}

const RARE: Copy = { ref: "rare:1", title: "Rare", rarity: "rare", season: 1, free: 2, owned: 2, value: 5000 }
const forms = { open: true, dailyCap: 1_200_000, locale: "en", accessible: "%{amount} PiCoins" }

describe("the daily cap in the recap", () => {
  it("measures the whole day: what was minted earlier plus the selection, out of the daily cap", () => {
    const view = recapViewOf(toggle(start([RARE], 200_000, {}), "rare:1"), STRINGS, forms)
    expect(view.capTotal).toBe(1_200_000)
    expect(view.capBefore).toBe(1_000_000)
    expect(view.capUsed).toBe(1_005_000)
    expect(view.capText).toBe("1,005,000 of 1,200,000 today")
  })

  it("reads the earlier mints alone when nothing is ticked", () => {
    const view = recapViewOf(start([RARE], 1_200_000, {}), STRINGS, forms)
    expect(view.capBefore).toBe(0)
    expect(view.capUsed).toBe(0)
    expect(view.capText).toBe("0 of 1,200,000 today")
  })
})
