import { describe, expect, it } from "vitest"
import { openAction, opensBeside, selectedLink } from "./collection_detail"

const click = (overrides: Partial<Parameters<typeof opensBeside>[0]> = {}) => ({
  defaultPrevented: false,
  button: 0,
  metaKey: false,
  ctrlKey: false,
  shiftKey: false,
  altKey: false,
  ...overrides,
})

describe("opensBeside", () => {
  it("opens a plain left click or Enter beside the grid from 720px", () => {
    expect(opensBeside(click(), false)).toBe(true)
  })

  it("leaves the link its own way on the phone", () => {
    expect(opensBeside(click(), true)).toBe(false)
  })

  it("leaves a new tab, a new window or a download to the browser", () => {
    for (const key of ["metaKey", "ctrlKey", "shiftKey", "altKey"] as const) {
      expect(opensBeside(click({ [key]: true }), false)).toBe(false)
    }
    expect(opensBeside(click({ button: 1 }), false)).toBe(false)
  })

  it("leaves a click another handler took", () => {
    expect(opensBeside(click({ defaultPrevented: true }), false)).toBe(false)
  })
})

describe("openAction", () => {
  it("adds a history entry for the first card, then replaces it, so Back returns to the grid in one step", () => {
    expect(openAction(false)).toBe("advance")
    expect(openAction(true)).toBe("replace")
  })
})

describe("selectedLink", () => {
  const base = "https://gameble.test/fr/library/cards"
  const links = [
    { href: "https://gameble.test/fr/cards/hades/seasons/4?grid%5Bq%5D=", name: "hades" },
    { href: "https://gameble.test/fr/cards/celeste/seasons/4?grid%5Bq%5D=", name: "celeste" },
  ]

  it("finds the grid link to the card the frame shows, whatever context either carries", () => {
    expect(selectedLink(links, "/fr/cards/celeste/seasons/4?grid%5Bq%5D=dead", base)?.name).toBe("celeste")
    expect(selectedLink(links, "https://gameble.test/fr/cards/hades/seasons/4", base)?.name).toBe("hades")
  })

  it("finds none for a card off this page of the grid, another season, or an empty frame", () => {
    expect(selectedLink(links, "/fr/cards/portal/seasons/4?grid%5Bq%5D=", base)).toBeUndefined()
    expect(selectedLink(links, "/fr/cards/hades/seasons/3?grid%5Bq%5D=", base)).toBeUndefined()
    expect(selectedLink(links, null, base)).toBeUndefined()
  })
})
