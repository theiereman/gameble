import { describe, expect, it } from "vitest"
import type { Rarity } from "./card_types"
import {
  CHIPS,
  EMPTY_FILTER,
  FRESH_PICKER_FILTERS,
  activeChips,
  clearedFilters,
  columnsOf,
  filterCards,
  filtering,
  freshPickerFilters,
  gridMove,
  initialLines,
  remove,
  replacePickerFilters,
  sendable,
  setQuantity,
  showsOpenHelp,
  sideCount,
  stepperKey,
  toggle,
  toggled,
  toggledFold,
  withFilter,
  type Line,
  type PickerFilters,
  type SideFilter,
} from "./trade_board"

const lines = (...pairs: [string, number][]): Line[] => pairs.map(([key, quantity]) => ({ key, quantity }))

describe("initialLines", () => {
  it("lowers each quantity to its maximum and drops a card with none left", () => {
    const maxima = new Map([
      ["portal--s1", 2],
      ["hades--s1", 0],
    ])
    expect(initialLines(lines(["portal--s1", 3], ["hades--s1", 1], ["gone--s1", 1]), maxima)).toEqual(lines(["portal--s1", 2]))
  })

  it("keeps four cards at most, each once", () => {
    const maxima = new Map(["a", "b", "c", "d", "e"].map((key) => [key, 5]))
    expect(initialLines(lines(["a", 1], ["a", 2], ["b", 1], ["c", 1], ["d", 1], ["e", 1]), maxima).map((line) => line.key)).toEqual([
      "a",
      "b",
      "c",
      "d",
    ])
  })
})

describe("toggle", () => {
  it("adds a card with one copy, and removes a picked one", () => {
    const added = toggle(lines(["a", 2]), "b", 3)
    expect(added).toEqual({ lines: lines(["a", 2], ["b", 1]), refused: false })
    expect(toggle(added.lines, "a", 3)).toEqual({ lines: lines(["b", 1]), refused: false })
  })

  it("refuses a fifth card and keeps the four", () => {
    const four = lines(["a", 1], ["b", 1], ["c", 1], ["d", 1])
    expect(toggle(four, "e", 2)).toEqual({ lines: four, refused: true })
  })

  it("adds nothing for a card with no free copy", () => {
    expect(toggle(lines(["a", 1]), "b", 0)).toEqual({ lines: lines(["a", 1]), refused: false })
  })
})

describe("setQuantity and remove", () => {
  it("keeps a quantity between 1 and the maximum", () => {
    expect(setQuantity(lines(["a", 1]), "a", 5, 3)).toEqual(lines(["a", 3]))
    expect(setQuantity(lines(["a", 2]), "a", 0, 3)).toEqual(lines(["a", 1]))
  })

  it("removes a card with all its copies", () => {
    expect(remove(lines(["a", 2], ["b", 1]), "a")).toEqual(lines(["b", 1]))
  })
})

describe("sideCount", () => {
  it("counts cards and copies", () => {
    expect(sideCount(lines(["a", 2], ["b", 1]))).toEqual({ cards: 2, copies: 3 })
    expect(sideCount([])).toEqual({ cards: 0, copies: 0 })
  })
})

describe("sendable", () => {
  it("waits for a card on the friend's side only", () => {
    const none = { cards: 0, copies: 0 }
    const one = { cards: 1, copies: 1 }
    expect(sendable({ give: none, take: one, changed: true })).toBe(true)
    expect(sendable({ give: one, take: none, changed: true })).toBe(false)
    expect(sendable({ give: one, take: one, changed: true })).toBe(true)
  })
})

describe("showsOpenHelp", () => {
  it("helps under the player's own side while it is empty", () => {
    expect(showsOpenHelp("own", [])).toBe(true)
    expect(showsOpenHelp("own", lines(["a", 1]))).toBe(false)
    expect(showsOpenHelp("friend", [])).toBe(false)
  })
})

describe("stepperKey", () => {
  it("maps arrows, + and -, Home and End", () => {
    expect(["ArrowUp", "ArrowRight", "+"].map(stepperKey)).toEqual([1, 1, 1])
    expect(["ArrowDown", "ArrowLeft", "-"].map(stepperKey)).toEqual([-1, -1, -1])
    expect(stepperKey("Home")).toBe("min")
    expect(stepperKey("End")).toBe("max")
    expect(stepperKey("Enter")).toBeNull()
  })
})

describe("gridMove", () => {
  it("moves by one and by a row, staying put past an edge", () => {
    expect(gridMove(0, "ArrowRight", 7, 3)).toBe(1)
    expect(gridMove(4, "ArrowUp", 7, 3)).toBe(1)
    expect(gridMove(4, "ArrowDown", 7, 3)).toBe(4)
    expect(gridMove(0, "ArrowLeft", 7, 3)).toBe(0)
    expect(gridMove(3, "End", 7, 3)).toBe(6)
    expect(gridMove(3, "Home", 7, 3)).toBe(0)
    expect(gridMove(3, "Tab", 7, 3)).toBeNull()
  })
})

describe("columnsOf", () => {
  it("counts the items on the first row", () => {
    expect(columnsOf([10, 10, 10, 200, 200])).toBe(3)
    expect(columnsOf([10, 10])).toBe(2)
    expect(columnsOf([])).toBe(1)
  })
})

describe("filterCards", () => {
  const card = (key: string, title: string, rarity: Rarity, copies = 1, otherCopies = 0, max = 1) => ({
    key,
    title,
    rarity,
    copies,
    otherCopies,
    max,
  })
  const cards = [
    card("a", "Café Owner", "common"),
    card("b", "Portal", "rare"),
    card("c", "Portal 2", "legendary"),
    card("d", "Hades", "rare"),
  ]
  const keys = (list: { key: string }[]) => list.map((each) => each.key)
  const by = (filter: Partial<SideFilter>) => ({ ...EMPTY_FILTER, ...filter })

  it("keeps every card, in order, without a filter", () => {
    expect(keys(filterCards(cards, EMPTY_FILTER))).toEqual(["a", "b", "c", "d"])
    expect(keys(filterCards(cards, by({ query: "   " })))).toEqual(["a", "b", "c", "d"])
  })

  it("matches part of a title whatever the case or accent", () => {
    expect(keys(filterCards(cards, by({ query: "PORT" })))).toEqual(["b", "c"])
    expect(keys(filterCards(cards, by({ query: "cafe" })))).toEqual(["a"])
    expect(keys(filterCards(cards, by({ query: "café" })))).toEqual(["a"])
  })

  it("matches any of the chosen rarities", () => {
    expect(keys(filterCards(cards, by({ rarities: ["rare"] })))).toEqual(["b", "d"])
    expect(keys(filterCards(cards, by({ rarities: ["common", "legendary"] })))).toEqual(["a", "c"])
  })

  it("requires both the search and a rarity", () => {
    expect(keys(filterCards(cards, by({ query: "portal", rarities: ["legendary"] })))).toEqual(["c"])
  })

  it("returns nothing when no card matches", () => {
    expect(filterCards(cards, by({ query: "zelda" }))).toEqual([])
    expect(filterCards(cards, by({ query: "hades", rarities: ["common"] }))).toEqual([])
  })

  describe("chips", () => {
    const friend = [
      card("one", "Portal", "rare", 1, 0),
      card("two", "Hades", "epic", 2, 1),
      card("three", "Celeste", "common", 3, 0),
      card("hades-s1", "Hades", "rare", 2, 1),
      card("held-elsewhere", "Inside", "epic", 2, 0),
      card("legend", "Limbo", "legendary", 4, 0),
    ]

    it("shows their duplicates: a game held twice or more over every edition", () => {
      expect(keys(filterCards(friend, by({ chips: ["duplicates"] })))).toEqual(["two", "three", "hades-s1", "held-elsewhere", "legend"])
    })

    it("shows a game missing from the other collection only when it holds no edition of it", () => {
      expect(keys(filterCards(friend, by({ chips: ["missing"] })))).toEqual(["one", "three", "held-elsewhere", "legend"])
    })

    it("shows a game both own when the other collection holds any edition of it", () => {
      expect(keys(filterCards(friend, by({ chips: ["shared"] })))).toEqual(["two", "hades-s1"])
    })

    it("shows the available cards, hiding one with every copy reserved", () => {
      const own = [card("free", "Portal", "rare", 2, 0, 2), card("reserved", "Hades", "rare", 1, 0, 0)]
      expect(keys(filterCards(own, by({ chips: ["available"] })))).toEqual(["free"])
    })

    it("requires every chip, any chosen rarity and the search together", () => {
      const filter = by({ rarities: ["rare", "epic"], chips: ["duplicates", "missing"] })
      expect(keys(filterCards(friend, filter))).toEqual(["held-elsewhere"])
      expect(keys(filterCards(friend, { ...filter, query: "hades" }))).toEqual([])
      expect(keys(filterCards(friend, by({ query: "hades", chips: ["duplicates", "shared"] })))).toEqual(["two", "hades-s1"])
    })

    it("shows no card for contradicting chips", () => {
      expect(filterCards(friend, by({ chips: ["missing", "shared"] }))).toEqual([])
    })
  })
})

describe("filtering", () => {
  it("is on once a search, a rarity or a chip is chosen", () => {
    expect(filtering(EMPTY_FILTER)).toBe(false)
    expect(filtering({ ...EMPTY_FILTER, query: "  " })).toBe(false)
    expect(filtering({ ...EMPTY_FILTER, query: "hades" })).toBe(true)
    expect(filtering({ ...EMPTY_FILTER, rarities: ["rare"] })).toBe(true)
    expect(filtering({ ...EMPTY_FILTER, chips: ["available"] })).toBe(true)
  })
})

describe("CHIPS", () => {
  it("offers each side its own three chips", () => {
    expect(CHIPS.friend).toEqual(["duplicates", "missing", "shared"])
    expect(CHIPS.own).toEqual(["duplicates", "missing", "available"])
  })
})

describe("toggled", () => {
  it("adds a missing value and removes a present one", () => {
    expect(toggled(["rare"], "epic")).toEqual(["rare", "epic"])
    expect(toggled(["rare", "epic"], "rare")).toEqual(["epic"])
  })
})

describe("activeChips", () => {
  it("counts the rarities and chips on, not the search", () => {
    expect(activeChips(EMPTY_FILTER)).toBe(0)
    expect(activeChips({ query: "hades", rarities: [], chips: [] })).toBe(0)
    expect(activeChips({ query: "", rarities: ["rare"], chips: ["duplicates"] })).toBe(2)
    expect(activeChips({ query: "", rarities: ["rare", "epic"], chips: ["missing"] })).toBe(3)
  })
})

describe("picker filters", () => {
  const filtered: PickerFilters = { filter: { query: "hades", rarities: ["rare"], chips: ["duplicates"] }, folded: false }

  it("starts every side with no filter, folded", () => {
    expect(freshPickerFilters(2)).toEqual([
      { filter: EMPTY_FILTER, folded: true },
      { filter: EMPTY_FILTER, folded: true },
    ])
    expect(FRESH_PICKER_FILTERS).toEqual({ filter: EMPTY_FILTER, folded: true })
  })

  it("replaces one side and leaves the other untouched", () => {
    const all = freshPickerFilters(2)
    const next = replacePickerFilters(all, 0, filtered)
    expect(next[0]).toEqual(filtered)
    expect(next[1]).toBe(all[1])
  })

  it("changes the filter and keeps the fold", () => {
    const filter = { query: "", rarities: ["epic"] as Rarity[], chips: [] }
    expect(withFilter(filtered, filter)).toEqual({ filter, folded: false })
  })

  it("clears the filter and keeps the fold", () => {
    expect(clearedFilters(filtered)).toEqual({ filter: EMPTY_FILTER, folded: false })
    expect(clearedFilters({ ...filtered, folded: true })).toEqual({ filter: EMPTY_FILTER, folded: true })
  })

  it("toggles the fold and keeps the filter", () => {
    expect(toggledFold(filtered)).toEqual({ ...filtered, folded: true })
    expect(toggledFold(toggledFold(filtered))).toEqual(filtered)
  })
})
