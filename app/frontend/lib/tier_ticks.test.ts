import { describe, expect, it } from "vitest"
import { PLACED_CLASS, placeTicks, tierAt, type Placeable } from "./tier_ticks"

const tick = (at: string | null) => {
  const properties = new Map<string, string>()
  const classes = new Set<string>()
  const element: Placeable = {
    getAttribute: (name) => (name === "data-tier-at" ? at : null),
    style: { setProperty: (name, value) => void properties.set(name, value) },
    classList: { add: (name) => void classes.add(name) },
  }
  return { element, properties, classes }
}

describe("tierAt", () => {
  it("reads the tick's share of the set", () => {
    expect(tierAt("0.25")).toBe(0.25)
    expect(tierAt("0.1129")).toBe(0.1129)
    expect(tierAt("1")).toBe(1)
  })

  it("refuses a value that is not a share", () => {
    expect([tierAt(null), tierAt(undefined), tierAt(""), tierAt("abc"), tierAt("-0.1"), tierAt("1.5"), tierAt("Infinity")]).toEqual([
      null,
      null,
      null,
      null,
      null,
      null,
      null,
    ])
  })
})

describe("placeTicks", () => {
  it("sets each tick's place as a custom property and shows it", () => {
    const ticks = ["0.25", "0.5", "0.75"].map(tick)
    placeTicks(ticks.map(({ element }) => element))

    expect(ticks.map(({ properties }) => properties.get("--at"))).toEqual(["0.25", "0.5", "0.75"])
    expect(ticks.every(({ classes }) => classes.has(PLACED_CLASS))).toBe(true)
  })

  it("leaves a tick without a valid place hidden", () => {
    const broken = tick("wide")
    placeTicks([broken.element])

    expect(broken.properties.size).toBe(0)
    expect(broken.classes.size).toBe(0)
  })
})
