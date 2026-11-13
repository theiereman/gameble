import { describe, expect, it } from "vitest"
import { selectAll, setCopies, start, toggle, type Copy } from "./entrust"
import {
  gridViewOf,
  RECAP_LINES,
  recapViewOf,
  sameCell,
  selectionOf,
  ticksOf,
  type EntrustStrings,
} from "./entrust_view"

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
  more: { one: "and %{count} more", other: "and %{count} more", zero: "" },
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

const setCopiesOf = (state: ReturnType<typeof start>) => setCopies(state, "rare:1", 2)

describe("a selection of every edition", () => {
  const copies: Copy[] = Array.from({ length: RECAP_LINES + 5 }, (_, index) => ({
    ...RARE,
    ref: `game-${String(index).padStart(2, "0")}:1`,
    title: `Game ${String(index).padStart(2, "0")}`,
  }))

  it("draws the first lines of the recap and counts the rest", () => {
    const view = recapViewOf(selectAll(start([], 1_200_000, {}), copies), STRINGS, forms)
    expect(view.lines).toHaveLength(RECAP_LINES)
    expect(view.more).toBe("and 5 more")
    expect(view.bar.count).toBe(`${RECAP_LINES + 5} copies`)
  })

  it("posts one field per ticked edition, loaded or not, in the list's order", () => {
    const state = selectAll(start([RARE], 1_200_000, {}), copies.slice(0, 2))
    const ticked = toggle(state, "rare:1")
    expect(ticksOf(ticked).map(({ copy, copies: count }) => [copy.ref, count])).toEqual([
      ["game-00:1", 1],
      ["game-01:1", 1],
      ["rare:1", 1],
    ])
    expect(selectionOf(ticksOf(setCopiesOf(ticked)))).toBe("game-00:1=1,game-01:1=1,rare:1=2")
  })
})

describe("the grid view", () => {
  it("draws the loaded cells only, and tells an unchanged cell", () => {
    const state = toggle(start([RARE, { ...RARE, ref: "other:1" }], 200_000, {}, ["rare:1"]), "rare:1")
    const view = gridViewOf(state, STRINGS)
    expect([...view.cells.keys()]).toEqual(["rare:1"])
    const cell = view.cells.get("rare:1")!
    expect(cell).toMatchObject({ ticked: true, tabbable: true, copies: 1 })
    expect(sameCell(cell, { ...cell, stepper: cell.stepper && { ...cell.stepper } })).toBe(true)
    expect(sameCell(cell, { ...cell, copies: 2 })).toBe(false)
    expect(sameCell(undefined, cell)).toBe(false)
  })
})
