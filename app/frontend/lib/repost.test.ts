import { describe, expect, it } from "vitest"
import { repostHref, sendRepost } from "./repost"

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

const REPOST_URL = "/fr/cards/portal/seasons/1/repost"

describe("repostHref", () => {
  it("puts the slug, escaped, in place of SLUG and the card's season in place of NUMBER", () => {
    expect(repostHref("/fr/cards/SLUG/seasons/NUMBER/repost", "half-life 2", 3)).toBe("/fr/cards/half-life%202/seasons/3/repost")
  })
})

describe("sendRepost", () => {
  it("posts JSON with the CSRF token and reads a success", async () => {
    const { calls, send } = fake(json(200, { message: "Carte repostée dans le fil." }))

    expect(await sendRepost({ url: REPOST_URL, csrfToken: "token", fetch: send })).toEqual({ kind: "reposted" })
    expect(calls).toHaveLength(1)
    expect(calls[0].url).toBe(REPOST_URL)
    expect(calls[0].init.method).toBe("POST")
    expect(calls[0].init.headers).toEqual({ Accept: "application/json", "X-CSRF-Token": "token" })
  })

  it("sends no CSRF header without a token", async () => {
    const { calls, send } = fake(json(200, { message: "ok" }))
    await sendRepost({ url: REPOST_URL, csrfToken: null, fetch: send })
    expect(calls[0].init.headers).toEqual({ Accept: "application/json" })
  })

  it("reads a refusal's code and message", async () => {
    const { send } = fake(json(422, { error: { code: "card_not_owned", message: "Vous ne possédez pas cette carte." } }))
    expect(await sendRepost({ url: REPOST_URL, csrfToken: null, fetch: send })).toEqual({
      kind: "refused",
      code: "card_not_owned",
      message: "Vous ne possédez pas cette carte.",
    })
  })

  it("fails without an answer, on a server error, on an HTML page or on a refusal of another shape", async () => {
    const outcomes = [
      fake(new TypeError("Failed to fetch")),
      fake(json(500, { error: { code: "boom", message: "x" } })),
      fake(new Response("<html>422</html>", { status: 422, headers: { "Content-Type": "text/html" } })),
      fake(json(422, { error: "nope" })),
    ]
    for (const { send } of outcomes) {
      expect(await sendRepost({ url: REPOST_URL, csrfToken: null, fetch: send })).toEqual({ kind: "failed" })
    }
  })
})
