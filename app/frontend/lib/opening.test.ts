import { describe, expect, it } from "vitest"
import { sendOpening } from "./opening"

const KEY = "3c1f9a2e-7d4b-4c8a-b5e6-0f2d9e8a1b7c"

const answer = {
  pack: { token: "abc", kind: "regular", cardBack: "standard", url: "/fr/packs/abc" },
  cards: [
    {
      slug: "portal",
      season: 1,
      tier: "epic",
      coverUrl: "https://x/y.jpg",
      title: "Portal",
      year: 2007,
      label: "Portal — Valve, 2007",
      faces: { s: "<span></span>", m: "<span></span>", xl: "<span></span>" },
    },
  ],
  bank: {
    available: 9,
    special: 0,
    openable: 9,
    reserveFull: false,
    nextSpecialKind: null,
    nextAvailableAt: null,
    scheduledAt: [],
    nextPackSize: 5,
  },
  serverTime: "2026-10-06T14:22:00.000Z",
  tierCountsBefore: { common: 0, uncommon: 0, rare: 0, epic: 0, legendary: 0 },
  setTiers: [
    {
      kind: "theme",
      key: "roguelike",
      name: "Roguelike",
      tier: "silver",
      required: 16,
      held: 18,
      total: 62,
      thresholds: [
        { tier: "bronze", required: 7 },
        { tier: "silver", required: 16 },
        { tier: "gold", required: 31 },
      ],
      url: "/fr/library/theme/roguelike",
    },
  ],
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
    const result = await sendOpening({
      url: "/fr/packs",
      reserve: "standard",
      key: KEY,
      csrfToken: "token",
      fetch: send,
    })

    expect(result).toEqual({ kind: "opened", answer })
    expect(calls).toHaveLength(1)
    expect(calls[0].url).toBe("/fr/packs?reserve=standard")
    expect(calls[0].init.method).toBe("POST")
    expect(calls[0].init.headers).toEqual({
      Accept: "application/json",
      "Idempotency-Key": KEY,
      "X-CSRF-Token": "token",
    })
  })

  it("reads the set tiers of both families: earlier seasons' metals and the ranks", async () => {
    const setTiers = [
      { ...answer.setTiers[0], tier: "bronze", required: 7 },
      ...["novice", "apprentice", "adept", "expert", "master", "complete"].map((tier) => ({
        ...answer.setTiers[0],
        key: "rpg",
        tier,
        thresholds: ["novice", "apprentice", "adept", "expert", "master"].map((rank, index) => ({
          tier: rank,
          required: [25, 63, 125, 188, 225][index],
        })),
      })),
    ]
    const { send } = fake(json(200, { ...answer, setTiers }))
    expect(
      await sendOpening({ url: "/fr/packs", reserve: "standard", key: KEY, csrfToken: null, fetch: send }),
    ).toEqual({
      kind: "opened",
      answer: { ...answer, setTiers },
    })
  })

  it("sends no CSRF header without a token", async () => {
    const { calls, send } = fake(json(200, answer))
    await sendOpening({ url: "/fr/packs", reserve: "standard", key: KEY, csrfToken: null, fetch: send })
    expect(calls[0].init.headers).toEqual({ Accept: "application/json", "Idempotency-Key": KEY })
  })

  it("reads a refusal's code and message", async () => {
    const { send } = fake(json(422, { error: { code: "no_pack_available", message: "Plus de capsule." } }))
    expect(
      await sendOpening({ url: "/fr/packs", reserve: "standard", key: KEY, csrfToken: null, fetch: send }),
    ).toEqual({
      kind: "refused",
      code: "no_pack_available",
      message: "Plus de capsule.",
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
      fake(
        json(200, { ...answer, cards: [{ ...answer.cards[0], faces: { m: "<span></span>", xl: "<span></span>" } }] }),
      ),
      // No set tiers, one of another shape, or one without its album.
      fake(json(200, { ...answer, setTiers: undefined })),
      fake(json(200, { ...answer, setTiers: [{ ...answer.setTiers[0], tier: "platinum" }] })),
      fake(json(200, { ...answer, setTiers: [{ ...answer.setTiers[0], url: undefined }] })),
      fake(json(200, { ...answer, setTiers: [{ ...answer.setTiers[0], held: undefined }] })),
      // A set tier without its set's thresholds, or with one of another shape.
      fake(json(200, { ...answer, setTiers: [{ ...answer.setTiers[0], thresholds: undefined }] })),
      fake(
        json(200, {
          ...answer,
          setTiers: [{ ...answer.setTiers[0], thresholds: [{ tier: "silver", required: "16" }] }],
        }),
      ),
      fake(
        json(200, {
          ...answer,
          setTiers: [{ ...answer.setTiers[0], thresholds: [{ tier: "complete", required: 62 }] }],
        }),
      ),
    ]
    for (const { send } of outcomes)
      expect(
        await sendOpening({ url: "/fr/packs", reserve: "standard", key: KEY, csrfToken: null, fetch: send }),
      ).toEqual({
        kind: "failed",
      })
  })
})
