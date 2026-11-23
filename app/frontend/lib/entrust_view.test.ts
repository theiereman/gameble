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
  setApartHeading: { one: "SET ASIDE · 1 WANTED CARD", other: "SET ASIDE · %{count} WANTED CARDS", zero: "" },
  setApartStatus: { one: "%{count} set aside", other: "%{count} set aside", zero: "" },
  seekers: { one: "%{count} player wants it", other: "%{count} players want it", zero: "" },
  choose: { one: "CHOOSE FOR THE WANTED CARD ▸", other: "CHOOSE FOR THE %{count} WANTED CARDS ▸", zero: "" },
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

describe("wanted copies in the recap", () => {
  const PYRE: Copy = { ...RARE, ref: "pyre:1", title: "Pyre", free: 2, seekers: 1 }
  const COMMON: Copy = {
    ref: "common:1",
    title: "Common",
    rarity: "common",
    season: 1,
    free: 3,
    owned: 3,
    value: 10,
    seekers: 0,
  }

  it("sets one copy apart per seeker and counts the rest only", () => {
    const view = recapViewOf(start([PYRE, COMMON], 1_200_000, { "pyre:1": 2, "common:1": 3 }), STRINGS, forms)
    expect(view.setApart).toEqual({
      heading: "SET ASIDE · 1 WANTED CARD",
      lines: [{ ref: "pyre:1", rarity: "rare", label: "Pyre, season 1", seekers: "1 player wants it" }],
      more: null,
    })
    expect(view.lines.map((line) => [line.ref, line.count, line.stepper?.value])).toEqual([
      ["pyre:1", "×2", 2],
      ["common:1", "×3", 3],
    ])
    expect(view.received).toBe(5030)
    expect(view.label).toBe("Entrust 4 copies")
    expect(view.status).toBe("4 copies, 5,030 PiCoins, 1 set aside")
    expect(view.finality).toBe(true)
  })

  it("leads straight to the table when only wanted copies are ticked, even with a full cap", () => {
    const view = recapViewOf(start([PYRE], 0, { "pyre:1": 1 }), STRINGS, forms)
    expect(view.lines).toEqual([])
    expect(view.prompt).toBe(false)
    expect(view.label).toBe("CHOOSE FOR THE WANTED CARD ▸")
    expect(view.disabled).toBe(false)
    expect(view.finality).toBe(false)
  })

  it("leads to the table when the cap entrusts nothing of the other ticked copies", () => {
    const view = recapViewOf(start([PYRE, COMMON], 0, { "pyre:1": 1, "common:1": 1 }), STRINGS, forms)
    expect(view.lines.map((line) => line.state)).toEqual(["stays"])
    expect(view.label).toBe("CHOOSE FOR THE WANTED CARD ▸")
    expect(view.finality).toBe(false)
    expect(view.disabled).toBe(false)
  })

  it("draws the first set-apart lines and counts the rest", () => {
    const wanted = Array.from({ length: RECAP_LINES + 2 }, (_, index) => ({ ...PYRE, ref: `pyre:${index}` }))
    const ticked = Object.fromEntries(wanted.map((copy) => [copy.ref, 1]))
    const view = recapViewOf(start(wanted, 1_200_000, ticked), STRINGS, forms)
    expect(view.setApart?.lines).toHaveLength(RECAP_LINES)
    expect(view.setApart?.more).toBe("and 2 more")
  })

  it("shows the first of two steps in the grid while a wanted copy is ticked", () => {
    expect(gridViewOf(start([PYRE, COMMON], 1_000, { "pyre:1": 1 }), STRINGS).firstOfTwoSteps).toBe(true)
    expect(gridViewOf(start([PYRE, COMMON], 1_000, { "common:1": 1 }), STRINGS).firstOfTwoSteps).toBe(false)
  })
})
