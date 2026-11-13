import entrustPreviewCasesJson from "../../../test/fixtures/files/entrust_preview_cases.json?raw"
import { describe, expect, it } from "vitest"
import type { Rarity } from "./card_types"
import {
  CLEARED_FILTER,
  DEFAULT_FILTER,
  bump,
  clearFilters,
  filterCount,
  moveActive,
  preview,
  setCopies,
  setFilter,
  start,
  toggle,
  visible,
  type Copy,
} from "./entrust"

const VALUES: Record<Rarity, number> = { common: 1000, uncommon: 2000, rare: 5000, epic: 15000, legendary: 100000 }

const copy = (rarity: Rarity, over: Partial<Copy> = {}): Copy => ({
  ref: `${rarity}:1`,
  title: `The ${rarity} game`,
  rarity,
  season: 1,
  free: 3,
  owned: 3,
  value: VALUES[rarity],
  ...over,
})

const LIST = [copy("legendary"), copy("rare"), copy("common", { title: "Éclair", free: 1, owned: 1 })]
const CAP = 1_200_000

type Case = {
  name: string
  values: Record<Rarity, number>
  cap_left: number
  lines: { rarity: Rarity; copies: number }[]
  entrusted: Partial<Record<Rarity, number>>
  stayed: Partial<Record<Rarity, number>>
  received: number
}

const cases: Case[] = JSON.parse(entrustPreviewCasesJson)

describe("the shared preview cases, which the operation also runs", () => {
  it.each(cases)("$name", (example) => {
    const copies = example.lines.map(({ rarity, copies: free }) =>
      copy(rarity, { free, owned: free, value: example.values[rarity] }),
    )
    const ticked = Object.fromEntries(example.lines.map(({ rarity, copies: count }) => [`${rarity}:1`, count]))
    const result = preview(start(copies, example.cap_left, ticked))

    const byRarity = (pick: (line: (typeof result.lines)[number]) => number) =>
      Object.fromEntries(result.lines.filter((line) => pick(line) > 0).map((line) => [line.copy.rarity, pick(line)]))
    expect(byRarity((line) => line.entrusted)).toEqual(example.entrusted)
    expect(byRarity((line) => line.stayed)).toEqual(example.stayed)
    expect(result.received).toBe(example.received)
  })
})

describe("the starting filter", () => {
  it("starts with doubles on by default, so single-copy cells are hidden", () => {
    expect(visible(start(LIST, CAP, {})).map((copy) => copy.rarity)).toEqual(["legendary", "rare"])
  })

  it("starts with doubles off when the markup says so, showing single-copy cells", () => {
    const state = start(LIST, CAP, {}, { ...DEFAULT_FILTER, doubles: false })
    expect(state.filter.doubles).toBe(false)
    expect(visible(state).map((copy) => copy.rarity)).toEqual(["legendary", "rare", "common"])
  })

  it("starts from the filter a redrawn page carries", () => {
    const state = start(LIST, CAP, {}, { query: "", rarities: ["rare"], doubles: false })
    expect(visible(state).map((copy) => copy.rarity)).toEqual(["rare"])
    expect(state.active).toBe("rare:1")
  })
})

describe("ticking", () => {
  it("ticks a cell at one copy and unticks it", () => {
    const ticked = toggle(start(LIST, CAP, {}), "rare:1")
    expect(ticked.ticked).toEqual({ "rare:1": 1 })
    expect(toggle(ticked, "rare:1").ticked).toEqual({})
  })

  it("ignores a ref that is not in the list", () => {
    const state = start(LIST, CAP, {})
    expect(toggle(state, "nothing:1")).toBe(state)
  })

  it("starts from the posted ticks, clamped to the free copies and dropping what is not free", () => {
    const state = start(LIST, CAP, { "rare:1": 9, "gone:1": 2, "common:1": 0 })
    expect(state.ticked).toEqual({ "rare:1": 3 })
  })
})

describe("copies", () => {
  it("sets the copies within one and the free count, an only copy included", () => {
    const state = toggle(start(LIST, CAP, {}), "rare:1")
    expect(setCopies(state, "rare:1", 3).ticked["rare:1"]).toBe(3)
    expect(setCopies(state, "rare:1", 9).ticked["rare:1"]).toBe(3)
    expect(setCopies(state, "rare:1", 0).ticked["rare:1"]).toBe(1)
    const only = toggle(start(LIST, CAP, {}), "common:1")
    expect(setCopies(only, "common:1", 2).ticked["common:1"]).toBe(1)
  })

  it("bumps a ticked cell only", () => {
    const state = start(LIST, CAP, {})
    expect(bump(state, "rare:1", 1)).toBe(state)
    const ticked = toggle(state, "rare:1")
    expect(bump(ticked, "rare:1", 1).ticked["rare:1"]).toBe(2)
    expect(bump(bump(ticked, "rare:1", -1), "rare:1", -1).ticked["rare:1"]).toBe(1)
  })
})

describe("filters", () => {
  it("shows the editions of two or more copies by default", () => {
    expect(visible(start(LIST, CAP, {})).map((entry) => entry.ref)).toEqual(["legendary:1", "rare:1"])
    const all = setFilter(start(LIST, CAP, {}), { ...DEFAULT_FILTER, doubles: false })
    expect(visible(all)).toHaveLength(3)
  })

  it("folds accents and case in the search and keeps the list order", () => {
    const all = setFilter(start(LIST, CAP, {}), { query: "ECLAIR", rarities: [], doubles: false })
    expect(visible(all).map((entry) => entry.ref)).toEqual(["common:1"])
  })

  it("filters by rarity", () => {
    const state = setFilter(start(LIST, CAP, {}), { query: "", rarities: ["rare"], doubles: false })
    expect(visible(state).map((entry) => entry.ref)).toEqual(["rare:1"])
  })

  it("keeps a ticked cell that a filter hides", () => {
    const ticked = toggle(start(LIST, CAP, {}), "rare:1")
    const hidden = setFilter(ticked, { query: "legend", rarities: [], doubles: true })
    expect(visible(hidden).map((entry) => entry.ref)).toEqual(["legendary:1"])
    expect(hidden.ticked).toEqual({ "rare:1": 1 })
    expect(preview(hidden).lines).toHaveLength(1)
  })

  it("counts the active filters and clears them all", () => {
    const state = setFilter(start(LIST, CAP, {}), { query: "x", rarities: ["rare", "epic"], doubles: true })
    expect(filterCount(state.filter)).toBe(3)
    expect(clearFilters(state).filter).toEqual(CLEARED_FILTER)
  })

  it("moves the active cell to a visible one when a filter hides it", () => {
    const state = setFilter(start(LIST, CAP, {}), { query: "", rarities: ["rare"], doubles: true })
    expect(state.active).toBe("rare:1")
  })
})

describe("moving between cells", () => {
  it("moves with the arrows, Home and End over the visible cells only", () => {
    const state = start(LIST, CAP, {})
    expect(state.active).toBe("legendary:1")
    const right = moveActive(state, "ArrowRight", 2)
    expect(right.active).toBe("rare:1")
    expect(moveActive(right, "ArrowRight", 2)).toBe(right)
    expect(moveActive(right, "Home", 2).active).toBe("legendary:1")
    expect(moveActive(state, "End", 2).active).toBe("rare:1")
    expect(moveActive(state, "x", 2)).toBe(state)
  })
})

describe("preview", () => {
  it("lists the lines most valuable first, as the list stands, whatever the tick order", () => {
    const state = toggle(toggle(start(LIST, CAP, {}), "rare:1"), "legendary:1")
    expect(preview(state).lines.map((line) => line.copy.ref)).toEqual(["legendary:1", "rare:1"])
  })

  it("names the entrusted Rare or better", () => {
    const result = preview(toggle(toggle(start(LIST, CAP, {}), "rare:1"), "common:1"))
    expect(result.rareNames).toEqual(["The rare game"])
    expect(result.rareCount).toBe(1)
  })

  it("does not name a Rare that stays", () => {
    const result = preview(toggle(start(LIST, 1000, {}), "rare:1"))
    expect(result.rareNames).toEqual([])
    expect(result.canValidate).toBe(true)
    expect(result.count).toBe(0)
  })

  it("disables validation for nothing ticked and for a full cap", () => {
    expect(preview(start(LIST, CAP, {})).canValidate).toBe(false)
    const full = preview(toggle(start(LIST, 0, {}), "rare:1"))
    expect(full.full).toBe(true)
    expect(full.canValidate).toBe(false)
    expect(full.pending).toBe(true)
  })

  it("previews the gauge use and what is left of the cap", () => {
    const result = preview(setCopies(toggle(start(LIST, 50_000, {}), "rare:1"), "rare:1", 3))
    expect(result.received).toBe(15_000)
    expect(result.capUsed).toBe(15_000)
    expect(result.capLeft).toBe(35_000)
  })
})
