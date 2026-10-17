import { describe, expect, it } from "vitest"
import { LAST_ALBUM_KEY, lastAlbum, leadsTo, rememberAlbum, type AlbumStorage } from "./last_album"

function memory(): AlbumStorage & { items: Map<string, string> } {
  const items = new Map<string, string>()
  return {
    items,
    getItem: (key) => items.get(key) ?? null,
    setItem: (key, value) => void items.set(key, value),
  }
}

const refusing: AlbumStorage = {
  getItem: () => {
    throw new Error("denied")
  },
  setItem: () => {
    throw new Error("denied")
  },
}

describe("last album", () => {
  it("remembers the album last opened", () => {
    const storage = memory()
    rememberAlbum("/en/library/theme/horror", storage)
    rememberAlbum("/en/library/theme/rpg", storage)

    expect(storage.items.get(LAST_ALBUM_KEY)).toBe("/en/library/theme/rpg")
    expect(lastAlbum(storage)).toBe("/en/library/theme/rpg")
  })

  it("knows none without storage, before any album, or when storage refuses", () => {
    expect(lastAlbum(null)).toBeNull()
    expect(lastAlbum(memory())).toBeNull()
    expect(() => rememberAlbum("/en/library/theme/rpg", refusing)).not.toThrow()
    expect(lastAlbum(refusing)).toBeNull()
  })

  it("matches a row by its link's pathname, whatever its query", () => {
    const base = "https://gameble.test/en/library"

    expect(leadsTo("/en/library/theme/rpg", base, "/en/library/theme/rpg")).toBe(true)
    expect(leadsTo("/en/library/theme/rpg?page=2", base, "/en/library/theme/rpg")).toBe(true)
    expect(leadsTo("https://gameble.test/en/library/theme/rpg", base, "/en/library/theme/rpg")).toBe(true)
    expect(leadsTo("/en/library/theme/rpgs", base, "/en/library/theme/rpg")).toBe(false)
    expect(leadsTo("/fr/library/theme/rpg", base, "/en/library/theme/rpg")).toBe(false)
    expect(leadsTo("/en/library/theme/rpg", base, null)).toBe(false)
  })
})
