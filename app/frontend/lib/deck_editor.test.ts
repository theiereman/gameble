import { describe, expect, it } from "vitest"
import {
  activateFirst,
  choose,
  chooseGap,
  collectionView,
  countOf,
  failed,
  filterBy,
  focusAfterRemoval,
  move,
  nextToSend,
  noticeText,
  refused,
  removeSlot,
  rename,
  requestFor,
  saved,
  slotsView,
  sortBy,
  start,
  type DeckState,
  type DeckStrings,
  type Entry,
} from "./deck_editor"

const STRINGS: DeckStrings = {
  add: "Add",
  added: "%{card} added, %{count} of 12",
  countHidden: "%{count} of 12",
  deleteTitle: 'Delete the deck "%{deck}"?',
  full: "The deck is full.",
  inDeck: "In the deck",
  inDeckSuffix: ", in the deck",
  removeSlot: "Remove %{card} from the deck",
  removed: "%{card} removed, %{count} of 12",
  sameGame: "This game is already in the deck.",
  saveFailed: "Could not save, try again.",
  saveStateFailed: "Not saved",
  saveStateSaved: "Saved",
  saveStateSaving: "Saving…",
  notYetRanked: "This card gets its stats on Monday.",
  noFreeCopy: "All your copies of this card are reserved.",
  coverageCovered: "%{call}, %{best}",
  sorted: "Collection sorted: %{call}",
  calls: { "release-low": "Oldest", "popularity-high": "Most popular" },
}

const entry = (ref: string, overrides: Partial<Entry> = {}): Entry => ({
  ref,
  game: ref.split(":")[0] ?? ref,
  title: ref.split(":")[0] ?? ref,
  image: `https://images.test/${ref}.jpg`,
  availability: "available",
  percentiles: { popularity: 50, rating: 50, release: 50, discovery: 50, circulation: 50 },
  trump: "popularity",
  movesText: "",
  movesSentence: "",
  ...overrides,
})

const games = Array.from({ length: 14 }, (_, index) => entry(`game-${index}:1`))

function fresh(entries: Entry[] = games): DeckState {
  return start({ token: null, url: null, name: "", slots: [], entries })
}

function saved_deck(slots: (string | null)[] = []): DeckState {
  return start({ token: "T".repeat(24), url: "/en/duels/decks/T", name: "Vieux", slots, entries: games })
}

describe("choose", () => {
  it("puts a card in the first empty slot and, on a new deck, creates the deck first", () => {
    const state = choose(fresh(), "game-0:1")

    expect(state.slots[0]).toBe("game-0:1")
    expect(countOf(state)).toBe(1)
    expect(state.pending).toEqual([
      { kind: "create", name: null },
      { kind: "add", ref: "game-0:1", slot: 1 },
    ])
    expect(noticeText(state, STRINGS)).toBe("game-0 added, 1 of 12")
  })

  it("takes out a card already in the deck, leaving its slot empty", () => {
    const state = choose(choose(choose(saved_deck(), "game-0:1"), "game-1:1"), "game-0:1")

    expect(state.slots.slice(0, 2)).toEqual([null, "game-1:1"])
    expect(state.pending.at(-1)).toEqual({ kind: "remove", ref: "game-0:1", slot: 1 })
    expect(noticeText(state, STRINGS)).toBe("game-0 removed, 1 of 12")
    expect(choose(state, "game-2:1").slots[0]).toBe("game-2:1")
  })

  it("refuses another edition of a game in the deck, before sending anything", () => {
    const entries = [entry("portal:1", { game: "portal" }), entry("portal:2", { game: "portal" })]
    const state = choose(choose(fresh(entries), "portal:1"), "portal:2")

    expect(state.slots.filter(Boolean)).toEqual(["portal:1"])
    expect(state.pending).toHaveLength(2)
    expect(noticeText(state, STRINGS)).toBe("This game is already in the deck.")
  })

  it("refuses a thirteenth card", () => {
    const full = games.slice(0, 12).reduce((state, game) => choose(state, game.ref), saved_deck())
    const state = choose(full, "game-12:1")

    expect(countOf(state)).toBe(12)
    expect(state.pending).toHaveLength(12)
    expect(noticeText(state, STRINGS)).toBe("The deck is full.")
  })

  it("refuses an edition with no stats or no free copy, saying why", () => {
    const entries = [entry("a:1", { availability: "unranked" }), entry("b:1", { availability: "reserved" })]

    expect(noticeText(choose(fresh(entries), "a:1"), STRINGS)).toBe("This card gets its stats on Monday.")
    expect(noticeText(choose(fresh(entries), "b:1"), STRINGS)).toBe("All your copies of this card are reserved.")
    expect(choose(fresh(entries), "b:1").pending).toEqual([])
  })

  it("makes the chosen card the collection's tab stop", () => {
    const state = choose(saved_deck(), "game-3:1")

    expect(collectionView(state).entries.get("game-3:1")).toEqual({ inDeck: true, tabbable: true, hidden: false })
    expect(collectionView(state).entries.get("game-0:1")).toEqual({ inDeck: false, tabbable: false, hidden: false })
  })
})

describe("saving", () => {
  it("sends the changes one at a time in order, the deck's creation first", () => {
    let state = choose(choose(fresh(), "game-0:1"), "game-1:1")

    expect(requestFor(state, nextToSend(state)!, "/en/duels/decks")).toEqual({
      url: "/en/duels/decks",
      method: "POST",
      body: { name: null },
    })
    state = saved(state, { token: "T".repeat(24), url: "/en/duels/decks/T", name: "Deck 1" })
    expect([state.token, state.name, state.savedName]).toEqual(["T".repeat(24), "Deck 1", "Deck 1"])
    expect(requestFor(state, nextToSend(state)!, "/en/duels/decks")).toEqual({
      url: "/en/duels/decks/T/cards",
      method: "POST",
      body: { ref: "game-0:1" },
    })
    state = saved(saved(state, {}), {})
    expect(nextToSend(state)).toBeNull()
  })

  it("keeps a failed change on screen and resends it before the next change", () => {
    let state = choose(saved_deck(), "game-0:1")
    state = failed(state)

    expect(state.slots[0]).toBe("game-0:1")
    expect(noticeText(state, STRINGS)).toBe("Could not save, try again.")

    state = choose(state, "game-1:1")
    expect(nextToSend(state)).toEqual({ kind: "add", ref: "game-0:1", slot: 1 })
    state = saved(state, {})
    expect(nextToSend(state)).toEqual({ kind: "add", ref: "game-1:1", slot: 2 })
  })

  it("takes back a refused card and says why", () => {
    const state = refused(
      choose(saved_deck(), "game-0:1"),
      "no_free_copy",
      "All your copies of this card are reserved.",
    )

    expect(state.slots[0]).toBeNull()
    expect(state.pending).toEqual([])
    expect(noticeText(state, STRINGS)).toBe("All your copies of this card are reserved.")
  })

  it("moves a saved card to the slot the server gave it, after an earlier card was refused", () => {
    let state = choose(choose(saved_deck(), "game-0:1"), "game-1:1")
    state = refused(state, "no_free_copy", "All your copies of this card are reserved.")
    state = choose(state, "game-2:1")
    expect(state.slots.slice(0, 2)).toEqual(["game-2:1", "game-1:1"])

    state = saved(state, { slot: 1, count: 1 })

    expect(state.slots.slice(0, 2)).toEqual(["game-1:1", "game-2:1"])
    expect(saved(state, { slot: 2, count: 2 }).slots.slice(0, 2)).toEqual(["game-1:1", "game-2:1"])
  })

  it("puts back a card whose removal was refused", () => {
    const state = refused(removeSlot(saved_deck(["game-0:1"]), 1), "deck_not_found", "This deck cannot be found.")

    expect(state.slots[0]).toBe("game-0:1")
  })

  it("names a new deck by its first change when that change is the name, and keeps the saved name on a refusal", () => {
    let state = rename(fresh(), "  Vieux briscards ")
    expect(state.pending).toEqual([{ kind: "create", name: "Vieux briscards" }])

    state = refused(state, "deck_name_taken", "You already have a deck with this name.")
    expect([state.name, state.nameRefusal, state.token]).toEqual(["", "You already have a deck with this name.", null])
  })

  it("renames a saved deck, reverting to the saved name when refused", () => {
    let state = rename(saved_deck(), "")
    expect(requestFor(state, nextToSend(state)!, "/en/duels/decks")).toEqual({
      url: "/en/duels/decks/T",
      method: "PATCH",
      body: { name: "" },
    })
    state = refused(state, "deck_name_required", "Name the deck.")
    expect([state.name, state.nameRefusal]).toEqual(["Vieux", "Name the deck."])
    expect(rename(state, "Vieux").nameRefusal).toBeNull()
    expect(rename(saved_deck(), " Vieux ").pending).toEqual([])
  })

  it("on a refused creation by its name, still creates the deck its cards wait for", () => {
    const state = refused(
      choose(rename(fresh(), "Vieux"), "game-0:1"),
      "deck_name_taken",
      "You already have a deck with this name.",
    )

    expect(state.pending).toEqual([
      { kind: "create", name: null },
      { kind: "add", ref: "game-0:1", slot: 1 },
    ])
    expect(state.slots[0]).toBe("game-0:1")
  })

  it("on a sixth deck, takes back every change waiting for it", () => {
    const state = refused(choose(fresh(), "game-0:1"), "too_many_decks", "Five decks at most.")

    expect(state.slots.every((slot) => slot === null)).toBe(true)
    expect(state.pending).toEqual([])
    expect(noticeText(state, STRINGS)).toBe("Five decks at most.")
  })
})

describe("focus and keys", () => {
  it("after a slot's card is taken out, goes to the next filled slot, else to the collection", () => {
    const state = saved_deck(["game-0:1", null, "game-2:1", "game-3:1"])

    expect(focusAfterRemoval(removeSlot(state, 1), 1)).toBe(3)
    expect(focusAfterRemoval(removeSlot(state, 4), 4)).toBeNull()
    expect(activateFirst(choose(state, "game-5:1")).active).toBe("game-0:1")
  })

  it("moves the collection's tab stop with the arrow keys", () => {
    const state = saved_deck()

    expect(move(state, "ArrowDown", 1).active).toBe("game-1:1")
    expect(move(state, "ArrowRight", 2).active).toBe("game-1:1")
    expect(move(state, "End", 2).active).toBe("game-13:1")
    expect(move(state, "ArrowUp", 1)).toBe(state)
    expect(move(state, "a", 1)).toBe(state)
  })
})

describe("views", () => {
  it("draws a filled slot as its card with a button name taking it out", () => {
    const view = slotsView(saved_deck(["game-0:1"]), STRINGS)

    expect(view[0]).toEqual({
      ref: "game-0:1",
      title: "game-0",
      image: "https://images.test/game-0:1.jpg",
      label: "Remove game-0 from the deck",
      moves: "",
    })
    expect(view.slice(1).every((slot) => slot === null)).toBe(true)
    expect(view).toHaveLength(12)
  })
})

describe("sort and trump filter", () => {
  const ranked = [
    entry("old:1", { percentiles: { release: 5 }, trump: "release" }),
    entry("pop:1", { percentiles: { popularity: 99 }, trump: "popularity" }),
    entry("new:1", { percentiles: { release: 95 }, trump: "release" }),
    entry("unranked:1", { percentiles: {}, trump: "" }),
    entry("older:1", { percentiles: { release: 2 }, trump: "release" }),
  ]
  const deck = () =>
    start({ token: "T".repeat(24), url: "/en/duels/decks/T", name: "Vieux", slots: [], entries: ranked })
  const shown = (state: DeckState) =>
    [...collectionView(state).entries].filter(([, view]) => !view.hidden).map(([ref]) => ref)

  it("orders the collection by a call, the cards with no value in it last, and back by title", () => {
    const state = sortBy(deck(), "release-low")

    expect([...collectionView(state).entries.keys()]).toEqual(["older:1", "old:1", "new:1", "pop:1", "unranked:1"])
    expect(collectionView(state).sort).toBe("release-low")
    expect([...collectionView(sortBy(state, "title")).entries.keys()]).toEqual(ranked.map((each) => each.ref))
    expect(sortBy(state, "release-low")).toBe(state)
  })

  it("on a gap, sorts by its call and says so", () => {
    const state = chooseGap(deck(), "release-low")

    expect(state.sort).toBe("release-low")
    expect(noticeText(state, STRINGS)).toBe("Collection sorted: Oldest")
  })

  it("hides the cards of another trump and moves the tab stop to the first one shown when its card is hidden", () => {
    const state = filterBy(deck(), "release")

    expect(shown(state)).toEqual(["old:1", "new:1", "older:1"])
    expect(collectionView(state).entries.get("pop:1")).toEqual({ inDeck: false, tabbable: false, hidden: true })
    expect(state.active).toBe("old:1")
    expect(filterBy(move(state, "End", 1), "rating").active).toBeNull()
    expect(filterBy({ ...deck(), active: "pop:1" }, "release").active).toBe("old:1")
    expect(filterBy(state, "release")).toBe(state)
  })

  it("moves the arrow keys over the cards shown only, in their sorted order, the collection one tab stop", () => {
    let state = filterBy(sortBy(deck(), "release-low"), "release")
    state = activateFirst(state)
    expect(state.active).toBe("older:1")

    state = move(state, "ArrowDown", 1)
    expect(state.active).toBe("old:1")
    state = move(state, "ArrowDown", 1)
    expect(state.active).toBe("new:1")
    expect(move(state, "ArrowDown", 1)).toBe(state)
    expect(move(state, "Home", 1).active).toBe("older:1")
    expect([...collectionView(state).entries.values()].filter((view) => view.tabbable)).toHaveLength(1)
  })
})

describe("moves", () => {
  it("draws a deck card's moved stats under it and ends its button's name with each move", () => {
    const moved = entry("game-0:1", {
      movesText: "▲ Pop.",
      movesSentence: "Popularity up: 62, against 55 last Monday",
    })
    const state = start({ token: null, url: null, name: "", slots: ["game-0:1"], entries: [moved] })

    expect(slotsView(state, STRINGS)[0]).toMatchObject({
      moves: "▲ Pop.",
      label: "Remove game-0 from the deck. Popularity up: 62, against 55 last Monday",
    })
  })
})
