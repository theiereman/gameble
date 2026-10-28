import { describe, expect, it } from "vitest"
import { atZero, fetchBank, handPutAway, owedBankDue, phaseForBank } from "./booster_bank"
import type { BoosterPhase } from "./booster_types"

const bank = {
  available: 1,
  special: 2,
  openable: 3,
  reserveFull: false,
  nextSpecialKind: "bonus",
  nextAvailableAt: "2026-10-06T14:32:00.000Z",
  serverTime: "2026-10-06T14:22:00.000Z",
  nextPackSize: 5,
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

describe("fetchBank", () => {
  it("gets the screen in JSON with the session's cookies, and reads the bank", async () => {
    const { calls, send } = fake(json(200, { bank }))

    expect(await fetchBank({ url: "/fr/booster.json", fetch: send })).toEqual(bank)
    expect(calls).toHaveLength(1)
    expect(calls[0].url).toBe("/fr/booster.json")
    expect(calls[0].init).toEqual({
      method: "GET",
      headers: { Accept: "application/json" },
      credentials: "same-origin",
    })
  })

  it("reads a full reserve with no next booster and no pack to open next", async () => {
    const full = {
      available: 0,
      special: 0,
      openable: 0,
      reserveFull: true,
      nextSpecialKind: null,
      nextAvailableAt: null,
      serverTime: bank.serverTime,
      nextPackSize: null,
    }
    const { send } = fake(json(200, { bank: { ...full, extra: "ignored" } }))
    expect(await fetchBank({ url: "/en/booster.json", fetch: send })).toEqual(full)
  })

  it("reads nothing without an answer, on a refusal, a server error, an HTML page or an answer of another shape", async () => {
    const outcomes = [
      fake(new TypeError("Failed to fetch")),
      fake(json(401, { error: { code: "sign_in_required", message: "Sign in." } })),
      fake(json(500, { bank })),
      fake(new Response("<html></html>", { status: 200, headers: { "Content-Type": "text/html" } })),
      fake(json(200, bank)),
      fake(json(200, { bank: null })),
      fake(json(200, { bank: { ...bank, available: "1" } })),
      fake(json(200, { bank: { ...bank, reserveFull: null } })),
      fake(json(200, { bank: { ...bank, nextAvailableAt: 0 } })),
      fake(json(200, { bank: { ...bank, serverTime: null } })),
      fake(json(200, { bank: { ...bank, nextPackSize: "5" } })),
    ]
    for (const { send } of outcomes) expect(await fetchBank({ url: "/en/booster.json", fetch: send })).toBeNull()
  })
})

describe("handPutAway", () => {
  it("in a row, once every card is revealed", () => {
    expect(handPutAway("wide", [true, true, true], [false, false, false])).toBe(true)
    expect(handPutAway("narrow", [true, false, true], [false, false, false])).toBe(false)
  })

  it("on the phone, once every card is stored", () => {
    expect(handPutAway("phone", [true, true, true], [true, true, false])).toBe(false)
    expect(handPutAway("phone", [true, true, true], [true, true, true])).toBe(true)
  })

  it("never without a hand", () => {
    expect(handPutAway("wide", [], [])).toBe(false)
    expect(handPutAway("phone", [], [])).toBe(false)
  })
})

describe("atZero", () => {
  it("refreshes the page at rest with no hand", () => {
    for (const phase of ["sealed", "empty"] as BoosterPhase[])
      expect(atZero({ phase, idle: true, handPutAway: false })).toBe("page")
  })

  it("owes the bank while a dealt hand is not put away", () => {
    expect(atZero({ phase: "dealt", idle: true, handPutAway: false })).toBe("owe")
  })

  it("fetches the bank at once when the hand is already put away", () => {
    expect(atZero({ phase: "dealt", idle: true, handPutAway: true })).toBe("bank")
  })

  it("owes the bank during an opening or while anything runs, never refreshing the page", () => {
    expect(atZero({ phase: "opening", idle: false, handPutAway: false })).toBe("owe")
    expect(atZero({ phase: "opening", idle: true, handPutAway: false })).toBe("owe")
    for (const phase of ["sealed", "empty", "dealt"] as BoosterPhase[]) {
      expect(atZero({ phase, idle: false, handPutAway: true })).toBe("owe")
    }
  })
})

describe("owedBankDue", () => {
  it("is due once the hand is put away and nothing runs", () => {
    expect(owedBankDue({ phase: "dealt", idle: true, handPutAway: true })).toBe(true)
    expect(owedBankDue({ phase: "dealt", idle: true, handPutAway: false })).toBe(false)
    expect(owedBankDue({ phase: "dealt", idle: false, handPutAway: true })).toBe(false)
  })

  it("waits out an opening, and is due at rest without a hand", () => {
    expect(owedBankDue({ phase: "opening", idle: true, handPutAway: false })).toBe(false)
    expect(owedBankDue({ phase: "sealed", idle: true, handPutAway: false })).toBe(true)
    expect(owedBankDue({ phase: "empty", idle: true, handPutAway: false })).toBe(true)
    expect(owedBankDue({ phase: "empty", idle: false, handPutAway: false })).toBe(false)
  })
})

describe("phaseForBank", () => {
  it("lets the canister follow the count", () => {
    expect(phaseForBank("empty", 1)).toBe("sealed")
    expect(phaseForBank("sealed", 0)).toBe("empty")
    expect(phaseForBank("sealed", 2)).toBe("sealed")
    expect(phaseForBank("empty", 0)).toBe("empty")
  })

  it("leaves a hand or an opening as it is", () => {
    expect(phaseForBank("dealt", 0)).toBe("dealt")
    expect(phaseForBank("dealt", 3)).toBe("dealt")
    expect(phaseForBank("opening", 0)).toBe("opening")
  })
})
