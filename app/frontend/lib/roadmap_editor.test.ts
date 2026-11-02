// @vitest-environment happy-dom
import { describe, expect, it } from "vitest"
import {
  applyKeys,
  indexToFocusAfterRemoval,
  isDirection,
  neighbourIndex,
  nextKey,
  substituteKeys,
} from "./roadmap_editor"

describe("nextKey", () => {
  it("starts at one when no row is new", () => {
    expect(nextKey([])).toBe("new-1")
    expect(nextKey(["Zk3mP9", "abc"])).toBe("new-1")
  })

  it("goes past the highest new key, whatever the order", () => {
    expect(nextKey(["new-2", "Zk3mP9", "new-10", "new-3"])).toBe("new-11")
  })

  it("ignores keys that only look like new ones", () => {
    expect(nextKey(["new-", "new-x", "xnew-5"])).toBe("new-1")
  })
})

describe("neighbourIndex", () => {
  it("steps up and down inside the list", () => {
    expect(neighbourIndex(3, 1, "up")).toBe(0)
    expect(neighbourIndex(3, 1, "down")).toBe(2)
  })

  it("refuses to leave the list", () => {
    expect(neighbourIndex(3, 0, "up")).toBeNull()
    expect(neighbourIndex(3, 2, "down")).toBeNull()
  })

  it("refuses an index outside the list", () => {
    expect(neighbourIndex(3, -1, "down")).toBeNull()
    expect(neighbourIndex(3, 3, "up")).toBeNull()
  })
})

describe("indexToFocusAfterRemoval", () => {
  it("prefers the next row, then the previous one", () => {
    expect(indexToFocusAfterRemoval(3, 0)).toBe(1)
    expect(indexToFocusAfterRemoval(3, 2)).toBe(1)
  })

  it("has none when the list empties", () => {
    expect(indexToFocusAfterRemoval(1, 0)).toBeNull()
  })
})

describe("isDirection", () => {
  it("accepts only up and down", () => {
    expect(isDirection("up")).toBe(true)
    expect(isDirection("down")).toBe(true)
    expect(isDirection("left")).toBe(false)
    expect(isDirection(undefined)).toBe(false)
  })
})

describe("substituteKeys", () => {
  it("replaces every placeholder, each as many times as it occurs", () => {
    expect(substituteKeys("a[__m__][__s__] __m__", { __m__: "new-1", __s__: "new-2" })).toBe("a[new-1][new-2] new-1")
  })
})

describe("applyKeys", () => {
  it("rewrites the attributes of the element and of everything under it", () => {
    const row = document.createElement("li")
    row.dataset.key = "__s__"
    const label = document.createElement("label")
    label.htmlFor = "field-__s__"
    const input = document.createElement("input")
    input.id = "field-__s__"
    input.name = "milestones[__m__][stories][__s__][wording_en]"
    row.append(label, input)

    applyKeys(row, { __m__: "Zk3mP9", __s__: "new-4" })

    expect(row.dataset.key).toBe("new-4")
    expect(row.querySelector("label")?.getAttribute("for")).toBe("field-new-4")
    expect(input.id).toBe("field-new-4")
    expect(input.name).toBe("milestones[Zk3mP9][stories][new-4][wording_en]")
  })
})
