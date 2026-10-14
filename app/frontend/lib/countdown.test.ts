import { describe, expect, it } from "vitest"
import { atZero, fetchChip } from "./countdown"

const CHIP_URL = "/fr/packs-chip"

function fake(response: Response | Error) {
  const calls: { url: string; init: RequestInit }[] = []
  const send = (async (url: string, init: RequestInit) => {
    calls.push({ url, init })
    if (response instanceof Error) throw response
    return response
  }) as typeof fetch
  return { calls, send }
}

describe("atZero", () => {
  it("waits while a form submission is in flight", () => {
    expect(atZero({ submitting: true, refreshPage: true, refreshUrl: CHIP_URL })).toBe("wait")
  })

  it("reloads the page on the hub", () => {
    expect(atZero({ submitting: false, refreshPage: true, refreshUrl: CHIP_URL })).toBe("visit")
  })

  it("fetches the chip alone off the hub", () => {
    expect(atZero({ submitting: false, refreshPage: false, refreshUrl: CHIP_URL })).toBe("fetchChip")
  })

  it("stops at zero when there is nothing to refresh", () => {
    expect(atZero({ submitting: false, refreshPage: false, refreshUrl: "" })).toBe("stop")
  })
})

describe("fetchChip", () => {
  it("asks for a Turbo Stream and renders the answer", async () => {
    const { calls, send } = fake(new Response("<turbo-stream></turbo-stream>", { status: 200 }))

    expect(await fetchChip(CHIP_URL, send)).toEqual({ kind: "render", html: "<turbo-stream></turbo-stream>" })
    expect(calls).toHaveLength(1)
    expect(calls[0].url).toBe(CHIP_URL)
    expect(calls[0].init.headers).toEqual({ Accept: "text/vnd.turbo-stream.html" })
  })

  it("retries after a server error", async () => {
    expect(await fetchChip(CHIP_URL, fake(new Response("", { status: 503 })).send)).toEqual({ kind: "retry" })
  })

  it("retries after a network error", async () => {
    expect(await fetchChip(CHIP_URL, fake(new TypeError("offline")).send)).toEqual({ kind: "retry" })
  })

  it("stops when the player is refused, which a retry cannot change", async () => {
    expect(await fetchChip(CHIP_URL, fake(new Response("", { status: 401 })).send)).toEqual({ kind: "stop" })
    expect(await fetchChip(CHIP_URL, fake(new Response("", { status: 403 })).send)).toEqual({ kind: "stop" })
  })
})
