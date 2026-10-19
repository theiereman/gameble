import { describe, expect, it } from "vitest"
import { addressInShownLocale, readShownLocale, rememberShownLocale, routedLocaleOf, SHOWN_LOCALE_KEY } from "./locale_return"
import type { TrailStorage } from "./history_trail"

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

describe("returning through history in the language shown last", () => {
  it("reads the locale from the first segment of a localized path only", () => {
    expect(routedLocaleOf("/fr/library")).toBe("fr")
    expect(routedLocaleOf("/en")).toBe("en")
    expect(routedLocaleOf("/")).toBeNull()
    expect(routedLocaleOf("/french/library")).toBeNull()
    expect(routedLocaleOf("/back_office/jobs")).toBeNull()
  })

  it("moves an address read in another language to the shown one, keeping its path, query and fragment", () => {
    expect(addressInShownLocale("https://gameble.net/fr/library?page=2#card", "en")).toBe("https://gameble.net/en/library?page=2#card")
    expect(addressInShownLocale("https://gameble.net/fr", "en")).toBe("https://gameble.net/en")
    expect(addressInShownLocale("https://gameble.net/en/cards/portal", "fr")).toBe("https://gameble.net/fr/cards/portal")
  })

  it("leaves an address already in the shown language, outside the locales, or with no language shown yet", () => {
    expect(addressInShownLocale("https://gameble.net/fr/library", "fr")).toBeNull()
    expect(addressInShownLocale("https://gameble.net/back_office/jobs", "en")).toBeNull()
    expect(addressInShownLocale("https://gameble.net/fr/library", null)).toBeNull()
    expect(addressInShownLocale("https://gameble.net/fr/library", "de")).toBeNull()
  })

  it("remembers the language of each localized page shown, and nothing for others", () => {
    const storage = memory()
    rememberShownLocale("/en/settings", storage)
    rememberShownLocale("/back_office/jobs", storage)

    expect(storage.items.get(SHOWN_LOCALE_KEY)).toBe("en")
    expect(readShownLocale(storage)).toBe("en")
  })

  it("remembers nothing without storage or where it refuses", () => {
    expect(() => rememberShownLocale("/en", refusing)).not.toThrow()
    expect(readShownLocale(refusing)).toBeNull()
    expect(readShownLocale(null)).toBeNull()
  })
})
