import { describe, expect, it } from "vitest"
import { edgeButtons, moveItem, nearestIndex, pastThreshold, sendPlacement } from "./showcase_order"

const box = (left: number, top: number) => ({ left, top, width: 100, height: 150 })

describe("pastThreshold", () => {
  it("keeps a small wobble a click and takes a longer move as a drag", () => {
    expect(pastThreshold(3, 4)).toBe(false)
    expect(pastThreshold(6, 0)).toBe(false)
    expect(pastThreshold(5, 5)).toBe(true)
    expect(pastThreshold(0, -7)).toBe(true)
  })
})

describe("nearestIndex", () => {
  const row = [box(0, 0), box(120, 0), box(240, 0)]

  it("picks the card whose centre is nearest the pointer", () => {
    expect(nearestIndex({ x: 50, y: 75 }, row)).toBe(0)
    expect(nearestIndex({ x: 185, y: 10 }, row)).toBe(1)
    expect(nearestIndex({ x: 900, y: 75 }, row)).toBe(2)
  })

  it("reads a wrapped second line by its height too", () => {
    const wrapped = [...row, box(0, 180)]
    expect(nearestIndex({ x: 50, y: 250 }, wrapped)).toBe(3)
  })

  it("has no place without a card", () => {
    expect(nearestIndex({ x: 0, y: 0 }, [])).toBe(-1)
  })
})

describe("moveItem", () => {
  it("moves a card later, the ones between shifting earlier", () => {
    expect(moveItem(["a", "b", "c", "d"], 0, 2)).toEqual(["b", "c", "a", "d"])
  })

  it("moves a card earlier, the ones between shifting later", () => {
    expect(moveItem(["a", "b", "c", "d"], 3, 0)).toEqual(["d", "a", "b", "c"])
  })

  it("leaves the order alone in place, and never changes its input", () => {
    const items = ["a", "b", "c"]
    expect(moveItem(items, 1, 1)).toEqual(["a", "b", "c"])
    moveItem(items, 0, 2)
    expect(items).toEqual(["a", "b", "c"])
  })

  it("clamps a place past either end, and ignores a missing card", () => {
    expect(moveItem(["a", "b", "c"], 0, 9)).toEqual(["b", "c", "a"])
    expect(moveItem(["a", "b", "c"], 2, -1)).toEqual(["c", "a", "b"])
    expect(moveItem(["a", "b"], 5, 0)).toEqual(["a", "b"])
  })
})

describe("edgeButtons", () => {
  it("has no ◀ on the first card and no ▶ on the last", () => {
    expect([0, 1, 2].map((index) => edgeButtons(index, 3))).toEqual([
      { earlier: false, later: true },
      { earlier: true, later: true },
      { earlier: true, later: false },
    ])
  })
})

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } })

function fake(response: Response | Error) {
  const calls: { url: string; init: RequestInit }[] = []
  const send = (async (url: string, init: RequestInit) => {
    calls.push({ url, init })
    if (response instanceof Error) throw response
    return response
  }) as typeof fetch
  return { calls, send }
}

const PLACE_URL = "/fr/cards/portal/seasons/1/showcase"

describe("sendPlacement", () => {
  it("patches the new place as JSON with the CSRF token and reads a success", async () => {
    const { calls, send } = fake(new Response(null, { status: 204 }))

    expect(await sendPlacement({ url: PLACE_URL, position: 2, csrfToken: "token", fetch: send })).toEqual({
      kind: "placed",
    })
    expect(calls).toHaveLength(1)
    expect(calls[0].url).toBe(PLACE_URL)
    expect(calls[0].init.method).toBe("PATCH")
    expect(calls[0].init.body).toBe(JSON.stringify({ position: 2 }))
    expect(calls[0].init.headers).toMatchObject({ Accept: "application/json", "X-CSRF-Token": "token" })
  })

  it("brings back the server's refusal with its message", async () => {
    const { send } = fake(
      json(422, { error: { code: "position_out_of_range", message: "La vitrine n'a pas cette place." } }),
    )

    expect(await sendPlacement({ url: PLACE_URL, position: 9, csrfToken: null, fetch: send })).toEqual({
      kind: "refused",
      message: "La vitrine n'a pas cette place.",
    })
  })

  it("fails on a network error, a server error or an answer without a message", async () => {
    for (const response of [new Error("offline"), new Response("oops", { status: 500 }), json(422, { nope: true })]) {
      const { send } = fake(response)
      expect(await sendPlacement({ url: PLACE_URL, position: 0, csrfToken: null, fetch: send })).toEqual({
        kind: "failed",
      })
    }
  })
})
