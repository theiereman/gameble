import { describe, expect, it, vi } from "vitest"
import { sendChange } from "./deck_editor_save"

const answer = (status: number, body: unknown) =>
  vi.fn(async () => new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } }))

const change = { url: "/en/duels/decks/T/cards", method: "POST" as const, body: { ref: "portal:1" }, csrfToken: "csrf" }

describe("sendChange", () => {
  it("posts the change in JSON with the CSRF token and reads the answer", async () => {
    const fetch = answer(200, { slot: 1, count: 1 })

    expect(await sendChange({ ...change, fetch })).toEqual({ kind: "saved", body: { slot: 1, count: 1 } })
    const [url, init] = fetch.mock.calls[0] as unknown as [string, RequestInit]
    expect(url).toBe("/en/duels/decks/T/cards")
    expect(init.method).toBe("POST")
    expect(init.body).toBe('{"ref":"portal:1"}')
    expect((init.headers as Record<string, string>)["X-CSRF-Token"]).toBe("csrf")
  })

  it("reads a 422 as a refusal with its code and message", async () => {
    const fetch = answer(422, { error: { code: "deck_full", message: "The deck is full." } })

    expect(await sendChange({ ...change, fetch })).toEqual({
      kind: "refused",
      code: "deck_full",
      message: "The deck is full.",
    })
  })

  it("reads a network error, a 5xx, a 429 or a 403 as a failure to send again", async () => {
    const offline = vi.fn(async () => {
      throw new TypeError("offline")
    })

    expect(await sendChange({ ...change, fetch: offline })).toEqual({ kind: "failed" })
    expect(await sendChange({ ...change, fetch: answer(500, {}) })).toEqual({ kind: "failed" })
    const throttled = answer(429, { error: { code: "throttled", message: "Too many." } })
    expect(await sendChange({ ...change, fetch: throttled })).toEqual({ kind: "failed" })
    expect(
      await sendChange({ ...change, fetch: answer(403, { error: { code: "forbidden", message: "No." } }) }),
    ).toEqual({
      kind: "failed",
    })
  })
})
