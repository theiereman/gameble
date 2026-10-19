import { describe, expect, it } from "vitest"
import {
  addressInChosenLocale,
  LOCALE_CHOICE_KEY,
  readLocaleChoice,
  rememberLocaleChoice,
  rememberShownPage,
  SHOWN_SINCE_LIMIT,
} from "./locale_return"
import { routedLocaleOf, type TrailStorage } from "./history_trail"

function memory(): TrailStorage & { items: Map<string, string> } {
  const items = new Map<string, string>()
  return { items, getItem: (key) => items.get(key) ?? null, setItem: (key, value) => void items.set(key, value) }
}

const refusing: TrailStorage = {
  getItem: () => {
    throw new Error("denied")
  },
  setItem: () => {
    throw new Error("denied")
  },
}

const english = { locale: "en", shownSince: [] }

describe("returning through history in the language chosen in the settings", () => {
  it("reads the locale from the first segment of a localized path only", () => {
    expect(routedLocaleOf("/fr/library")).toBe("fr")
    expect(routedLocaleOf("/en")).toBe("en")
    expect(routedLocaleOf("/")).toBeNull()
    expect(routedLocaleOf("/french/library")).toBeNull()
    expect(routedLocaleOf("/back_office/jobs")).toBeNull()
  })

  it("moves an address read before the choice to the chosen language, keeping its path, query and fragment", () => {
    expect(addressInChosenLocale("https://gameble.net/fr/library?page=2#card", english)).toBe("https://gameble.net/en/library?page=2#card")
    expect(addressInChosenLocale("https://gameble.net/fr", english)).toBe("https://gameble.net/en")
    expect(addressInChosenLocale("https://gameble.net/en/cards/portal", { locale: "fr", shownSince: [] })).toBe("https://gameble.net/fr/cards/portal")
  })

  it("leaves every address alone while no language was chosen in the tab", () => {
    expect(addressInChosenLocale("https://gameble.net/fr/library", null)).toBeNull()
  })

  it("leaves an address already in the chosen language, outside the locales, or chosen in an unknown language", () => {
    expect(addressInChosenLocale("https://gameble.net/en/library", english)).toBeNull()
    expect(addressInChosenLocale("https://gameble.net/back_office/jobs", english)).toBeNull()
    expect(addressInChosenLocale("https://gameble.net/fr/library", { locale: "de", shownSince: [] })).toBeNull()
  })

  it("leaves an address read in the other language since the choice, a link or a pasted URL", () => {
    const storage = memory()
    rememberLocaleChoice("https://gameble.net/en/settings", storage)
    rememberShownPage("https://gameble.net/fr/how-it-works?step=2", storage)

    const choice = readLocaleChoice(storage)
    expect(addressInChosenLocale("https://gameble.net/fr/how-it-works?step=2#top", choice)).toBeNull()
    expect(addressInChosenLocale("https://gameble.net/fr/how-it-works", choice)).toBe("https://gameble.net/en/how-it-works")
  })

  it("starts each choice afresh and remembers only the pages read in another language", () => {
    const storage = memory()
    rememberShownPage("https://gameble.net/fr/library", storage)
    expect(storage.items.has(LOCALE_CHOICE_KEY)).toBe(false)

    rememberLocaleChoice("https://gameble.net/en/settings", storage)
    rememberShownPage("https://gameble.net/en/library", storage)
    rememberShownPage("https://gameble.net/back_office/jobs", storage)
    rememberShownPage("https://gameble.net/fr/more", storage)
    rememberShownPage("https://gameble.net/fr/more", storage)
    expect(readLocaleChoice(storage)).toEqual({ locale: "en", shownSince: ["/fr/more"] })

    rememberLocaleChoice("https://gameble.net/fr/settings", storage)
    expect(readLocaleChoice(storage)).toEqual({ locale: "fr", shownSince: [] })
  })

  it("keeps the latest pages read since the choice", () => {
    const storage = memory()
    rememberLocaleChoice("https://gameble.net/en/settings", storage)
    for (let page = 0; page <= SHOWN_SINCE_LIMIT; page++) rememberShownPage(`https://gameble.net/fr/cards/${page}`, storage)

    const { shownSince } = readLocaleChoice(storage)!
    expect(shownSince).toHaveLength(SHOWN_SINCE_LIMIT)
    expect(shownSince).not.toContain("/fr/cards/0")
    expect(shownSince.at(-1)).toBe(`/fr/cards/${SHOWN_SINCE_LIMIT}`)
  })

  it("reads no choice from a malformed record, without storage or where it refuses", () => {
    const storage = memory()
    storage.setItem(LOCALE_CHOICE_KEY, "{\"locale\":\"en\"}")
    expect(readLocaleChoice(storage)).toBeNull()
    storage.setItem(LOCALE_CHOICE_KEY, "not json")
    expect(readLocaleChoice(storage)).toBeNull()
    expect(() => rememberLocaleChoice("https://gameble.net/en/settings", refusing)).not.toThrow()
    expect(readLocaleChoice(refusing)).toBeNull()
    expect(readLocaleChoice(null)).toBeNull()
  })
})
