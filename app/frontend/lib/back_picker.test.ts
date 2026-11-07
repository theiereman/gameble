import { describe, expect, it, vi } from "vitest"
import {
  blurred,
  focused,
  hovered,
  isCurrentChoice,
  restingStrip,
  sendChoice,
  shownSeason,
  stripTarget,
  unhovered,
} from "./back_picker"

describe("stripTarget", () => {
  it("names the active back at rest", () => {
    expect(stripTarget(restingStrip, "aurore")).toBe("aurore")
  })

  it("names the hovered back, then the focused one", () => {
    expect(stripTarget(hovered(restingStrip, "centurion"), "aurore")).toBe("centurion")
    expect(stripTarget(focused(restingStrip, "contrat"), "aurore")).toBe("contrat")
  })

  it("names the latest of a hovered and a focused back", () => {
    const hoverThenFocus = focused(hovered(restingStrip, "centurion"), "contrat")
    const focusThenHover = hovered(focused(restingStrip, "contrat"), "centurion")

    expect(stripTarget(hoverThenFocus, "aurore")).toBe("contrat")
    expect(stripTarget(focusThenHover, "aurore")).toBe("centurion")
  })

  it("goes back to the focused back when the pointer leaves, then to the active one when the focus leaves", () => {
    const left = unhovered(hovered(focused(restingStrip, "contrat"), "centurion"), "centurion")

    expect(stripTarget(left, "aurore")).toBe("contrat")
    expect(stripTarget(blurred(left), "aurore")).toBe("aurore")
  })

  it("keeps the hover when the pointer leaves another back", () => {
    const state = unhovered(hovered(restingStrip, "centurion"), "contrat")

    expect(stripTarget(state, "aurore")).toBe("centurion")
  })
})

describe("shownSeason", () => {
  it("stamps the season worn, else the latest earned", () => {
    expect(shownSeason([1, 2, 3], 1)).toBe(1)
    expect(shownSeason([1, 2, 3], null)).toBe(3)
    expect(shownSeason([1, 2], 7)).toBe(2)
  })

  it("stamps nothing on a back without seasons", () => {
    expect(shownSeason([], null)).toBeNull()
  })
})

describe("isCurrentChoice", () => {
  it("takes the active back's own button, or its worn season, as nothing to send", () => {
    expect(isCurrentChoice({ back: "aurore", season: null }, { back: "aurore", season: null })).toBe(true)
    expect(isCurrentChoice({ back: "set-theme-rpg", season: 2 }, { back: "set-theme-rpg", season: 2 })).toBe(true)
    expect(isCurrentChoice({ back: "set-theme-rpg", season: null }, { back: "set-theme-rpg", season: 2 })).toBe(true)
  })

  it("sends another back or another season", () => {
    expect(isCurrentChoice({ back: "centurion", season: null }, { back: "aurore", season: null })).toBe(false)
    expect(isCurrentChoice({ back: "set-theme-rpg", season: 1 }, { back: "set-theme-rpg", season: 2 })).toBe(false)
  })
})

describe("sendChoice", () => {
  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } })

  it("patches the back and its season as JSON with the CSRF token and reads the announcement", async () => {
    const fetch = vi.fn().mockResolvedValue(json({ back: "set-theme-rpg", season: 1, announcement: "Equipped." }))

    const result = await sendChoice({
      url: "/en/personalization/back",
      back: "set-theme-rpg",
      season: 1,
      csrfToken: "t",
      fetch,
    })

    expect(result).toEqual({ kind: "chosen", back: "set-theme-rpg", season: 1, announcement: "Equipped." })
    const [url, init] = fetch.mock.calls[0]
    expect(url).toBe("/en/personalization/back")
    expect(init.method).toBe("PATCH")
    expect(init.headers).toMatchObject({ "X-CSRF-Token": "t", Accept: "application/json" })
    expect(JSON.parse(init.body)).toEqual({ back: "set-theme-rpg", season: 1 })
  })

  it("sends no season when none is asked and reads none back", async () => {
    const fetch = vi.fn().mockResolvedValue(json({ back: "aurore", season: null, announcement: "Equipped." }))

    const result = await sendChoice({ url: "/b", back: "aurore", season: null, csrfToken: null, fetch })

    expect(JSON.parse(fetch.mock.calls[0][1].body)).toEqual({ back: "aurore" })
    expect(fetch.mock.calls[0][1].headers).not.toHaveProperty("X-CSRF-Token")
    expect(result).toMatchObject({ kind: "chosen", season: null })
  })

  it("fails on a refusal, a broken answer or a network error", async () => {
    const refused = vi.fn().mockResolvedValue(json({ error: { code: "back_locked", message: "Locked." } }, 422))
    const broken = vi.fn().mockResolvedValue(new Response("oops", { status: 200 }))
    const offline = vi.fn().mockRejectedValue(new TypeError("offline"))

    for (const fetch of [refused, broken, offline]) {
      expect(await sendChoice({ url: "/b", back: "x", season: null, csrfToken: null, fetch })).toEqual({
        kind: "failed",
      })
    }
  })
})
