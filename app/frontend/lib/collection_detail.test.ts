import { describe, expect, it } from "vitest"
import { DETAIL_BESIDE, openAction, opensBeside, selectedLink } from "./collection_detail"

const click = (overrides: Partial<Parameters<typeof opensBeside>[0]> = {}) => ({
  defaultPrevented: false,
  button: 0,
  metaKey: false,
  ctrlKey: false,
  shiftKey: false,
  altKey: false,
  ...overrides,
})

const besideAt = (width: number) => {
  const from = DETAIL_BESIDE.match(/^\(min-width: (\d+)px\)$/)?.[1]
  if (!from) throw new Error("the detail's column is not set by a min-width in px")
  return width >= Number(from)
}

describe("opensBeside", () => {
  it("opens a plain left click or Enter beside the grid in a 1024px window", () => {
    expect(opensBeside(click(), besideAt(1024))).toBe(true)
    expect(opensBeside(click(), besideAt(900))).toBe(true)
  })

  it("leaves the link to the card's page in an 800px window, and on the phone", () => {
    expect(opensBeside(click(), besideAt(899))).toBe(false)
    expect(opensBeside(click(), besideAt(800))).toBe(false)
    expect(opensBeside(click(), besideAt(390))).toBe(false)
  })

  it("leaves a new tab, a new window or a download to the browser", () => {
    for (const key of ["metaKey", "ctrlKey", "shiftKey", "altKey"] as const) {
      expect(opensBeside(click({ [key]: true }), true)).toBe(false)
    }
    expect(opensBeside(click({ button: 1 }), true)).toBe(false)
  })

  it("leaves a click another handler took", () => {
    expect(opensBeside(click({ defaultPrevented: true }), true)).toBe(false)
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
