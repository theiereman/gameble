import { describe, expect, it } from "vitest"
import type { Rarity } from "./card_types"
import {
  CHIPS,
  EMPTY_FILTER,
  FRESH_PICKER_FILTERS,
  activeChips,
  cardOf,
  changed,
  clearFilters,
  clearedFilters,
  closePicker,
  columnsOf,
  draftSides,
  edit,
  filterCards,
  filtering,
  gridMove,
  initialLines,
  moveActive,
  openPicker,
  pickerView,
  place,
  remove,
  removeLine,
  restore,
  sendable,
  setFilter,
  setLineQuantity,
  setPickQuantity,
  setQuantity,
  showMore,
  showsOpenHelp,
  sideCount,
  start,
  stepperKey,
  toggle,
  toggleFold,
  togglePick,
  toggledFold,
  withFilter,
  type BoardState,
  type Line,
  type PickerFilters,
  type SideFilter,
  type TradeCard,
} from "./trade_board"
import { PICKER_PAGE } from "./trade_board_faces"

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

  it("starts with no filter, folded", () => {
    expect(FRESH_PICKER_FILTERS).toEqual({ filter: EMPTY_FILTER, folded: true })
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

describe("the board", () => {
  const card = (key: string, max: number, extra: Partial<TradeCard> = {}): TradeCard => ({
    key,
    title: key,
    rarity: "common",
    owned: Math.max(1, max),
    reserved: 0,
    max,
    copies: 1,
    otherCopies: 0,
    ...extra,
  })
  const catalogue = {
    friend: [card("depths", 2), card("hills", 3, { rarity: "uncommon" }), card("soldier", 1)],
    own: [card("portal", 3), card("crown", 0, { rarity: "legendary" }), card("tin", 1)],
  }
  const received = { friend: lines(["depths", 1]), own: lines(["portal", 2]) }
  const board = (overrides: Partial<Parameters<typeof start>[0]> = {}): BoardState =>
    start({ catalogue, received, editing: false, draft: null, ...overrides })
  const picking = (side: "friend" | "own" = "own") => openPicker(edit(board()), side)

  describe("start", () => {
    it("shows the received lines, kept within each card's copies", () => {
      const state = board({ received: { friend: lines(["depths", 5], ["gone", 1]), own: lines(["crown", 1], ["portal", 2]) } })
      expect(state.received).toEqual({ friend: lines(["depths", 2]), own: lines(["portal", 2]) })
      expect(state.lines).toEqual(state.received)
      expect(state.picker).toBeNull()
      expect(state.filters).toEqual({ friend: FRESH_PICKER_FILTERS, own: FRESH_PICKER_FILTERS })
    })

    it("starts from a kept draft, held to the maxima, a missing side empty", () => {
      const state = board({ draft: { take: lines(["hills", 9], ["crown", 1]) } })
      expect(state.lines).toEqual({ friend: lines(["hills", 3]), own: [] })
      expect(state.received).toEqual({ friend: lines(["depths", 1]), own: lines(["portal", 2]) })
    })

    it("keeps the given filters, for a board rebuilt after a refresh", () => {
      const filters = { friend: { filter: { ...EMPTY_FILTER, query: "hills" }, folded: false }, own: FRESH_PICKER_FILTERS }
      expect(board({ filters }).filters).toBe(filters)
    })
  })

  it("finds a side's card by key", () => {
    expect(cardOf(board(), "own", "portal")?.max).toBe(3)
    expect(cardOf(board(), "friend", "portal")).toBeUndefined()
  })

  describe("editing", () => {
    it("opens the edition and restores the received lines", () => {
      const changedBoard = removeLine(edit(board()), "own", "portal")
      expect(changedBoard.editing).toBe(true)
      const restored = restore(openPicker(changedBoard, "own"))
      expect(restored.editing).toBe(false)
      expect(restored.lines).toEqual(restored.received)
      expect(restored.picker).toBeNull()
    })

    it("removes a line, and leaves the board as it is for a key it does not hold", () => {
      const state = edit(board())
      expect(removeLine(state, "own", "portal").lines.own).toEqual([])
      expect(removeLine(state, "own", "tin")).toBe(state)
    })

    it("sets a line's quantity within its card's copies, unchanged when it stays", () => {
      const state = edit(board())
      expect(setLineQuantity(state, "own", "portal", 9).lines.own).toEqual(lines(["portal", 3]))
      expect(setLineQuantity(state, "own", "portal", 2)).toBe(state)
      expect(setLineQuantity(state, "own", "unknown", 2)).toBe(state)
    })
  })

  describe("derived", () => {
    it("is changed once a side differs from what was received", () => {
      expect(changed(board())).toBe(false)
      expect(changed(setLineQuantity(board(), "own", "portal", 1))).toBe(true)
      expect(changed(setLineQuantity(setLineQuantity(board(), "own", "portal", 1), "own", "portal", 2))).toBe(false)
    })

    it("is sendable with a card on the friend's side, whatever the player gives", () => {
      expect(sendable(board())).toBe(true)
      expect(sendable(removeLine(board(), "own", "portal"))).toBe(true)
      expect(sendable(removeLine(board(), "friend", "depths"))).toBe(false)
    })

    it("keeps the friend's side as taken and the player's as given", () => {
      expect(draftSides(board())).toEqual({ take: lines(["depths", 1]), give: lines(["portal", 2]) })
    })
  })

  describe("the picker", () => {
    it("opens on a side with its lines picked and the first line active", () => {
      const view = pickerView(picking())!
      expect(view.side).toBe("own")
      expect(view.selection).toEqual(lines(["portal", 2]))
      expect(view.activeKey).toBe("portal")
      expect(view.shownKeys).toEqual(["portal", "crown", "tin"])
      expect(view.count).toEqual({ cards: 1, copies: 2 })
      expect(view).toMatchObject({ hasMore: false, matches: 3, hasCards: true, empty: null, refused: false, folded: true, filtering: false })
    })

    it("has no view while closed", () => {
      expect(pickerView(board())).toBeNull()
    })

    it("makes the first shown card active when no line is", () => {
      expect(pickerView(openPicker(removeLine(board(), "own", "portal"), "own"))!.activeKey).toBe("portal")
      expect(pickerView(openPicker(start({ catalogue: { friend: [], own: [] }, received, editing: true, draft: null }), "own"))!.activeKey).toBeNull()
    })

    it("picks and unpicks a card, making it active", () => {
      const picked = togglePick(picking(), "tin")
      expect(picked.picker).toMatchObject({ activeKey: "tin", selection: lines(["portal", 2], ["tin", 1]), refused: false })
      expect(togglePick(picked, "portal").picker!.selection).toEqual(lines(["tin", 1]))
      expect(togglePick(picked, "unknown")).toBe(picked)
      expect(togglePick(board(), "tin")).toEqual(board())
    })

    it("refuses a fifth card and keeps the selection", () => {
      const many = { ...catalogue, own: ["a", "b", "c", "d", "e"].map((key) => card(key, 1)) }
      let state = openPicker(start({ catalogue: many, received: { friend: [], own: [] }, editing: true, draft: null }), "own")
      for (const key of ["a", "b", "c", "d"]) state = togglePick(state, key)
      const refused = togglePick(state, "e")
      expect(refused.picker).toMatchObject({ refused: true, selection: state.picker!.selection })
      expect(togglePick(refused, "a").picker!.refused).toBe(false)
    })

    it("does not pick a card without a free copy", () => {
      expect(togglePick(picking(), "crown").picker).toMatchObject({ activeKey: "crown", selection: lines(["portal", 2]), refused: false })
    })

    it("sets a pick's quantity within the card's copies", () => {
      expect(setPickQuantity(picking(), "portal", 7).picker!.selection).toEqual(lines(["portal", 3]))
      const state = picking()
      expect(setPickQuantity(state, "portal", 2)).toBe(state)
      expect(setPickQuantity(board(), "portal", 1)).toEqual(board())
    })

    it("places the selection on its side, or closes leaving the side as it was", () => {
      const picked = togglePick(picking(), "tin")
      expect(place(picked).lines.own).toEqual(lines(["portal", 2], ["tin", 1]))
      expect(place(picked).picker).toBeNull()
      expect(closePicker(picked).lines.own).toEqual(lines(["portal", 2]))
      expect(closePicker(picked).picker).toBeNull()
      const closed = board()
      expect(closePicker(closed)).toBe(closed)
      expect(place(closed)).toBe(closed)
    })

    it("filters the side's cards, back to the first page, the active card the first shown when filtered out", () => {
      const state = setFilter(picking(), { ...EMPTY_FILTER, rarities: ["legendary"] })
      const view = pickerView(state)!
      expect(view.shownKeys).toEqual(["crown"])
      expect(view.activeKey).toBe("crown")
      expect(view.matches).toBe(1)
      expect(view.chipsOn).toBe(1)
      expect(view.filtering).toBe(true)
      expect(view.selection).toEqual(lines(["portal", 2]))
      expect(state.filters.friend).toBe(FRESH_PICKER_FILTERS)
    })

    it("says why nothing shows: no card, every copy reserved, or no match", () => {
      expect(pickerView(setFilter(picking(), { ...EMPTY_FILTER, query: "zelda" }))!.empty).toBe("unmatched")
      const none = start({ catalogue: { friend: [], own: [card("x", 0)] }, received: { friend: [], own: [] }, editing: true, draft: null })
      expect(pickerView(openPicker(none, "friend"))).toMatchObject({ empty: "none", hasCards: false })
      expect(pickerView(openPicker(none, "own"))).toMatchObject({ empty: "reserved", hasCards: true })
    })

    it("clears the filters and keeps them per side between openings", () => {
      const filtered = setFilter(picking(), { ...EMPTY_FILTER, query: "tin" })
      const reopened = openPicker(closePicker(filtered), "own")
      expect(pickerView(reopened)!.filter.query).toBe("tin")
      expect(pickerView(openPicker(closePicker(filtered), "friend"))!.filter).toBe(EMPTY_FILTER)
      expect(pickerView(clearFilters(reopened))!.filter).toBe(EMPTY_FILTER)
    })

    it("folds and unfolds the filters", () => {
      expect(pickerView(toggleFold(picking()))!.folded).toBe(false)
      expect(toggleFold(board())).toEqual(board())
    })

    it("shows the cards a page at a time", () => {
      const many = { ...catalogue, own: Array.from({ length: PICKER_PAGE + 2 }, (_, at) => card(`c${at}`, 1)) }
      const state = openPicker(start({ catalogue: many, received: { friend: [], own: [] }, editing: true, draft: null }), "own")
      expect(pickerView(state)).toMatchObject({ hasMore: true, matches: PICKER_PAGE + 2 })
      expect(pickerView(state)!.shownKeys).toHaveLength(PICKER_PAGE)
      const more = showMore(state)
      expect(pickerView(more)).toMatchObject({ hasMore: false })
      expect(pickerView(more)!.shownKeys).toHaveLength(PICKER_PAGE + 2)
      expect(showMore(more)).toBe(more)
    })

    it("moves the active card through the grid, showing the page it lands on", () => {
      const state = picking()
      expect(moveActive(state, "ArrowRight", 3).picker!.activeKey).toBe("crown")
      expect(moveActive(state, "End", 3).picker!.activeKey).toBe("tin")
      expect(moveActive(state, "ArrowLeft", 3).picker!.activeKey).toBe("portal")
      expect(moveActive(state, "Tab", 3)).toBe(state)
      const many = { ...catalogue, own: Array.from({ length: PICKER_PAGE + 2 }, (_, at) => card(`c${at}`, 1)) }
      const long = openPicker(start({ catalogue: many, received: { friend: [], own: [] }, editing: true, draft: null }), "own")
      const end = moveActive(long, "End", 4)
      expect(end.picker).toMatchObject({ activeKey: `c${PICKER_PAGE + 1}`, shown: 2 * PICKER_PAGE })
    })
  })
})
