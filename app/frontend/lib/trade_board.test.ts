import { describe, expect, it } from "vitest"
import { columnsOf, filterCards, gridMove, initialLines, remove, setQuantity, sideCount, stepperKey, toggle, type Line } from "./trade_board"

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
  const cards = [
    { key: "a", title: "Café Owner", rarity: "common" as const },
    { key: "b", title: "Portal", rarity: "rare" as const },
    { key: "c", title: "Portal 2", rarity: "legendary" as const },
    { key: "d", title: "Hades", rarity: "rare" as const },
  ]
  const keys = (list: { key: string }[]) => list.map((card) => card.key)

  it("keeps every card, in order, without a filter", () => {
    expect(keys(filterCards(cards, "", []))).toEqual(["a", "b", "c", "d"])
    expect(keys(filterCards(cards, "   ", []))).toEqual(["a", "b", "c", "d"])
  })

  it("matches part of a title whatever the case or accent", () => {
    expect(keys(filterCards(cards, "PORT", []))).toEqual(["b", "c"])
    expect(keys(filterCards(cards, "cafe", []))).toEqual(["a"])
    expect(keys(filterCards(cards, "café", []))).toEqual(["a"])
  })

  it("matches any of the chosen rarities", () => {
    expect(keys(filterCards(cards, "", ["rare"]))).toEqual(["b", "d"])
    expect(keys(filterCards(cards, "", ["common", "legendary"]))).toEqual(["a", "c"])
  })

  it("requires both the search and a rarity", () => {
    expect(keys(filterCards(cards, "portal", ["legendary"]))).toEqual(["c"])
  })

  it("returns nothing when no card matches", () => {
    expect(filterCards(cards, "zelda", [])).toEqual([])
    expect(filterCards(cards, "hades", ["common"])).toEqual([])
  })
})
