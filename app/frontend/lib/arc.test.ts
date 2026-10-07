import { describe, expect, it } from "vitest"
import { arcPoints } from "./arc"

describe("arcPoints", () => {
  const from = { x: 100, y: 400 }
  const to = { x: 700, y: 20 }

  it("starts at the origin and ends exactly at the destination", () => {
    const points = arcPoints(from, to)
    expect(points[0]).toEqual(from)
    expect(points.at(-1)).toEqual(to)
    expect(points).toHaveLength(17)
  })

  it("rises above the higher end, so the path is an arc", () => {
    const top = Math.min(...arcPoints(from, to, 32).map((point) => point.y))
    expect(top).toBeLessThan(to.y)
  })

  it("covers most of the distance early (ease-out) and never goes back", () => {
    const points = arcPoints(from, to)
    expect(points[8].x - from.x).toBeGreaterThan((to.x - from.x) / 2)
    points.slice(1).forEach((point, i) => expect(point.x).toBeGreaterThanOrEqual(points[i].x))
  })
})
