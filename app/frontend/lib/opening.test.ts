import { describe, expect, it } from "vitest"
import { sendOpening } from "./opening"

const KEY = "3c1f9a2e-7d4b-4c8a-b5e6-0f2d9e8a1b7c"

const answer = {
  pack: { token: "abc", kind: "regular", cardBack: "standard", url: "/fr/packs/abc" },
  cards: [{ slug: "portal", tier: "epic", coverUrl: "https://x/y.jpg", title: "Portal", year: 2007, label: "Portal — Valve, 2007", faces: { s: "<span></span>", m: "<span></span>", xl: "<span></span>" } }],
  bank: { available: 9, reserveFull: false, nextAvailableAt: null, scheduledAt: [], nextPackSize: 5 },
  serverTime: "2026-10-06T14:22:00.000Z",
  tierCountsBefore: { common: 0, uncommon: 0, rare: 0, epic: 0, legendary: 0 },
  unlockedCardBacks: [],
}

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

describe("sendOpening", () => {
  it("posts JSON with the key and the CSRF token, and reads the opened pack", async () => {
    const { calls, send } = fake(json(200, answer))
    const result = await sendOpening({ url: "/fr/packs", key: KEY, csrfToken: "token", fetch: send })

    expect(result).toEqual({ kind: "opened", answer })
    expect(calls).toHaveLength(1)
    expect(calls[0].url).toBe("/fr/packs")
    expect(calls[0].init.method).toBe("POST")
    expect(calls[0].init.headers).toEqual({ Accept: "application/json", "Idempotency-Key": KEY, "X-CSRF-Token": "token" })
  })

  it("sends no CSRF header without a token", async () => {
    const { calls, send } = fake(json(200, answer))
    await sendOpening({ url: "/fr/packs", key: KEY, csrfToken: null, fetch: send })
    expect(calls[0].init.headers).toEqual({ Accept: "application/json", "Idempotency-Key": KEY })
  })

  it("reads a refusal's code and message", async () => {
    const { send } = fake(json(422, { error: { code: "no_pack_available", message: "Plus de booster." } }))
    expect(await sendOpening({ url: "/fr/packs", key: KEY, csrfToken: null, fetch: send })).toEqual({
      kind: "refused",
      code: "no_pack_available",
      message: "Plus de booster.",
    })
  })

  it("fails without an answer, on a server error, on an HTML page or on an answer of another shape", async () => {
    const outcomes = [
      fake(new TypeError("Failed to fetch")),
      fake(json(500, { error: { code: "boom", message: "x" } })),
      fake(new Response("<html>422</html>", { status: 422, headers: { "Content-Type": "text/html" } })),
      fake(json(200, { pack: {} })),
      fake(json(422, { message: "no envelope" })),
      // A card without one of its three faces.
      fake(json(200, { ...answer, cards: [{ ...answer.cards[0], faces: { m: "<span></span>", xl: "<span></span>" } }] })),
    ]
    for (const { send } of outcomes) expect(await sendOpening({ url: "/fr/packs", key: KEY, csrfToken: null, fetch: send })).toEqual({ kind: "failed" })
  })
})
