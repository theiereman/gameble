import { describe, expect, it } from "vitest"
import { ignoreAlert, ignoredAlertKey, isIgnored } from "./alert_ignore"

function memoryStorage(): Pick<Storage, "getItem" | "setItem"> & { entries: Map<string, string> } {
  const entries = new Map<string, string>()
  return {
    entries,
    getItem: (key) => entries.get(key) ?? null,
    setItem: (key, value) => void entries.set(key, value),
  }
}

describe("ignoredAlertKey", () => {
  it("names the indicator under the gameble prefix", () => {
    expect(ignoredAlertKey("destroyed_share")).toBe("gameble:ignored-alert:destroyed_share")
  })
})

describe("ignoreAlert and isIgnored", () => {
  it("ignores an alert while its value stays the same", () => {
    const storage = memoryStorage()

    ignoreAlert("destroyed_share", "3400", storage)

    expect(storage.entries.get("gameble:ignored-alert:destroyed_share")).toBe("3400")
    expect(isIgnored("destroyed_share", "3400", storage)).toBe(true)
  })

  it("shows the alert again once the value changes", () => {
    const storage = memoryStorage()
    ignoreAlert("destroyed_share", "3400", storage)

    expect(isIgnored("destroyed_share", "3500", storage)).toBe(false)
  })

  it("keeps each indicator apart", () => {
    const storage = memoryStorage()
    ignoreAlert("destroyed_share", "3400", storage)

    expect(isIgnored("top_share", "3400", storage)).toBe(false)
  })

  it("never ignores without storage or a name", () => {
    ignoreAlert("destroyed_share", "3400", null)

    expect(isIgnored("destroyed_share", "3400", null)).toBe(false)
    expect(isIgnored("", "3400", memoryStorage())).toBe(false)
  })

  it("shows the alert when the storage refuses", () => {
    const refusing = {
      getItem: () => {
        throw new Error("denied")
      },
      setItem: () => {
        throw new Error("denied")
      },
    }

    expect(() => ignoreAlert("destroyed_share", "3400", refusing)).not.toThrow()
    expect(isIgnored("destroyed_share", "3400", refusing)).toBe(false)
  })
})
