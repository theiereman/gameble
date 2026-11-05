import { describe, expect, it } from "vitest"
import {
  activeKey,
  clearRefusal,
  gameLabel,
  gamesUrl,
  hasChanges,
  initialState,
  isFilter,
  move,
  reset,
  setActive,
  setFilter,
  setQuery,
  toggle,
} from "./custom_set_editor"

const BASE = "/en/library/custom-sets/games"

describe("initialState", () => {
  it("opens on every game, no search, the picks it was given once each", () => {
    const state = initialState("Mes favoris", ["portal", "doom", "portal"])
    expect(state.picks).toEqual(["portal", "doom"])
    expect(state.openedWith).toEqual({ name: "Mes favoris", picks: ["portal", "doom"] })
    expect([state.filter, state.query, state.active, state.refusal]).toEqual(["all", "", null, null])
  })
})

describe("toggle", () => {
  it("adds a game at the end of the picks and takes a picked one out", () => {
    let { state } = toggle(initialState("", ["portal"]), "doom", 50)
    expect(state.picks).toEqual(["portal", "doom"])
    expect(state.active).toBe("doom")
    ;({ state } = toggle(state, "portal", 50))
    expect(state.picks).toEqual(["doom"])
  })

  it("refuses one more game at the limit, keeps the picks and shows the refusal", () => {
    const full = initialState("", ["a", "b", "c"])
    const { state, refused } = toggle(full, "d", 3)
    expect(refused).toBe(true)
    expect(state.picks).toEqual(["a", "b", "c"])
    expect(state.refusal).toBe("limit")
  })

  it("lets a picked game out at the limit and clears the refusal", () => {
    const refused = toggle(initialState("", ["a", "b", "c"]), "d", 3).state
    const { state, refused: again } = toggle(refused, "b", 3)
    expect(again).toBe(false)
    expect(state.picks).toEqual(["a", "c"])
    expect(state.refusal).toBeNull()
    expect(clearRefusal(refused).refusal).toBeNull()
  })
})

describe("reset", () => {
  it("brings back the name and picks the editor opened with, every game and no search", () => {
    let state = initialState("Mes favoris", ["portal"])
    state = toggle(state, "doom", 50).state
    state = setQuery(setFilter(state, "picked"), "seed")
    state = reset(state)
    expect(state).toEqual(initialState("Mes favoris", ["portal"]))
  })
})

describe("hasChanges", () => {
  const opened = initialState("Mes favoris", ["portal", "doom"])

  it("sees nothing to lose when only the search and the chip moved", () => {
    expect(hasChanges(setQuery(setFilter(opened, "owned"), "seed"), "Mes favoris")).toBe(false)
  })

  it("sees a renamed set", () => {
    expect(hasChanges(opened, "Autre chose")).toBe(true)
  })

  it("sees a game added or removed, not the same games picked back", () => {
    expect(hasChanges(toggle(opened, "hades", 50).state, "Mes favoris")).toBe(true)
    const removed = toggle(opened, "portal", 50).state
    expect(hasChanges(removed, "Mes favoris")).toBe(true)
    expect(hasChanges(toggle(removed, "portal", 50).state, "Mes favoris")).toBe(false)
  })
})

describe("isFilter", () => {
  it("knows the four chips only", () => {
    expect(["all", "owned", "missing", "picked"].every(isFilter)).toBe(true)
    expect(isFilter("new")).toBe(false)
  })
})

describe("gamesUrl", () => {
  it("is the bare address for every game unsearched", () => {
    expect(gamesUrl(BASE, initialState("", ["portal"]))).toBe(BASE)
  })

  it("carries the trimmed search and the chip", () => {
    const state = setFilter(setQuery(initialState("", []), "  port "), "owned")
    expect(gamesUrl(BASE, state)).toBe(`${BASE}?q=port&state=owned`)
  })

  it("sends the picks in pick order for the picked chip only", () => {
    const state = setFilter(initialState("", ["doom", "portal"]), "picked")
    expect(gamesUrl(BASE, state)).toBe(`${BASE}?state=picked&games%5B%5D=doom&games%5B%5D=portal`)
    expect(gamesUrl(BASE, setFilter(state, "missing"))).toBe(`${BASE}?state=missing`)
  })
})

describe("roving focus", () => {
  const keys = ["a", "b", "c", "d", "e"]

  it("rests on the first game until one is chosen, and on the chosen one while it is shown", () => {
    const state = initialState("", [])
    expect(activeKey(state, keys)).toBe("a")
    expect(activeKey(setActive(state, "c"), keys)).toBe("c")
    expect(activeKey(setActive(state, "z"), keys)).toBe("a")
    expect(activeKey(state, [])).toBeNull()
  })

  it("moves with the arrows across rows", () => {
    const state = setActive(initialState("", []), "b")
    expect(move(state, keys, "ArrowRight", 3)).toBe("c")
    expect(move(state, keys, "ArrowDown", 3)).toBe("e")
    expect(move(state, keys, "Home", 3)).toBe("a")
    expect(move(state, keys, "Enter", 3)).toBeNull()
    expect(move(state, [], "ArrowRight", 3)).toBeNull()
  })
})

describe("gameLabel", () => {
  it("ends with the in-set words when picked", () => {
    expect(gameLabel("Portal, owned", true, ", in the set")).toBe("Portal, owned, in the set")
    expect(gameLabel("Portal, owned", false, ", in the set")).toBe("Portal, owned")
  })
})
