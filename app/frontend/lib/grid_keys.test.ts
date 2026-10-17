import { describe, expect, it } from "vitest"
import { columnsOf, nextIndex } from "./grid_keys"

describe("columnsOf", () => {
  it("counts the slots on the first row", () => {
    expect(columnsOf([10, 10, 10, 260, 260, 260, 510])).toBe(3)
    expect(columnsOf([10, 10, 260, 260])).toBe(2)
  })

  it("is the whole grid on one row, and one for none", () => {
    expect(columnsOf([10, 10, 10])).toBe(3)
    expect(columnsOf([])).toBe(1)
  })
})

describe("nextIndex", () => {
  const move = (key: string, index: number) => nextIndex(key, index, 13, 6)

  it("moves one slot left or right, stopping at the ends", () => {
    expect(move("ArrowRight", 0)).toBe(1)
    expect(move("ArrowRight", 5)).toBe(6)
    expect(move("ArrowLeft", 6)).toBe(5)
    expect(move("ArrowLeft", 0)).toBe(0)
    expect(move("ArrowRight", 12)).toBe(12)
  })

  it("moves one row up or down in the same column, staying where no slot is", () => {
    expect(move("ArrowDown", 1)).toBe(7)
    expect(move("ArrowDown", 6)).toBe(12)
    expect(move("ArrowDown", 7)).toBe(7)
    expect(move("ArrowUp", 12)).toBe(6)
    expect(move("ArrowUp", 4)).toBe(4)
  })

  it("follows the columns the grid has", () => {
    expect(nextIndex("ArrowDown", 1, 13, 2)).toBe(3)
    expect(nextIndex("ArrowUp", 3, 13, 2)).toBe(1)
  })

  it("goes to the first or the last slot", () => {
    expect(move("Home", 9)).toBe(0)
    expect(move("End", 2)).toBe(12)
  })

  it("leaves any other key alone", () => {
    expect(move("Enter", 3)).toBeNull()
    expect(move("a", 3)).toBeNull()
  })
})
