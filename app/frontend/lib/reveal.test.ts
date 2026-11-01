import { describe, expect, it } from "vitest"
import { sendReveal } from "./reveal"

function fake(outcome: Response | Error) {
  const calls: { url: string; init: RequestInit }[] = []
  const send = (async (url: string, init: RequestInit) => {
    calls.push({ url, init })
    if (outcome instanceof Error) throw outcome
    return outcome
  }) as typeof fetch
  return { calls, send }
}

const REVEAL_URL = "/fr/packs/2b7Qx9KfPm4TzWcR8vYhN3sD/reveal"

describe("sendReveal", () => {
  it("posts the mode as JSON, with the CSRF token, kept alive past the page", async () => {
    const { calls, send } = fake(new Response(null, { status: 204 }))

    await sendReveal({ url: REVEAL_URL, mode: "one_by_one", csrfToken: "token", fetch: send })

    expect(calls).toHaveLength(1)
    expect(calls[0].url).toBe(REVEAL_URL)
    expect(calls[0].init).toEqual({
      method: "POST",
      headers: { Accept: "application/json", "Content-Type": "application/json", "X-CSRF-Token": "token" },
      body: JSON.stringify({ mode: "one_by_one" }),
      credentials: "same-origin",
      keepalive: true,
    })
  })

  it("sends no CSRF header without a token", async () => {
    const { calls, send } = fake(new Response(null, { status: 204 }))
    await sendReveal({ url: REVEAL_URL, mode: "all", csrfToken: null, fetch: send })
    expect(calls[0].init.headers).toEqual({ Accept: "application/json", "Content-Type": "application/json" })
    expect(calls[0].init.body).toBe('{"mode":"all"}')
  })

  it("swallows a refusal and a network failure", async () => {
    const refused = fake(new Response('{"error":{"code":"not_latest_pack","message":"…"}}', { status: 422 }))
    await expect(
      sendReveal({ url: REVEAL_URL, mode: "all", csrfToken: null, fetch: refused.send }),
    ).resolves.toBeUndefined()
    const failed = fake(new TypeError("Failed to fetch"))
    await expect(
      sendReveal({ url: REVEAL_URL, mode: "all", csrfToken: null, fetch: failed.send }),
    ).resolves.toBeUndefined()
  })
})
