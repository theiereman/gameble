import { describe, expect, it } from "vitest"
import { RevealHold, TOAST_BASE_MS, TOAST_ONCE_PREFIX, firstShowing, toastActionHref, toastDuration } from "./toast"

describe("toastDuration", () => {
  it("stays the base time for an empty text", () => {
    expect(toastDuration("")).toBe(TOAST_BASE_MS)
    expect(toastDuration("   ")).toBe(TOAST_BASE_MS)
  })

  it("adds a second for each started group of ten words", () => {
    expect(toastDuration("Proposition envoyée")).toBe(6000)
    expect(toastDuration("un deux trois quatre cinq six sept huit neuf dix")).toBe(6000)
    expect(toastDuration("un deux trois quatre cinq six sept huit neuf dix onze")).toBe(7000)
    expect(toastDuration(Array.from({ length: 30 }, () => "mot").join(" "))).toBe(8000)
  })

  it("counts words across any whitespace", () => {
    expect(toastDuration("  Léa a\n7 jours\tpour répondre. ")).toBe(6000)
  })
})

describe("toastActionHref", () => {
  it("takes an object URL or a path of the site", () => {
    expect(toastActionHref("blob:https://gameble.example/0b6e2c4a")).toBe("blob:https://gameble.example/0b6e2c4a")
    expect(toastActionHref("/fr/settings")).toBe("/fr/settings")
  })

  it("refuses any other target", () => {
    expect(toastActionHref("javascript:alert(1)")).toBeNull()
    expect(toastActionHref("https://elsewhere.example/")).toBeNull()
    expect(toastActionHref("//elsewhere.example/")).toBeNull()
    expect(toastActionHref("/\\elsewhere.example/")).toBeNull()
    expect(toastActionHref("")).toBeNull()
    expect(toastActionHref(undefined)).toBeNull()
  })
})

describe("firstShowing", () => {
  function memory(): Pick<Storage, "getItem" | "setItem"> & { items: Map<string, string> } {
    const items = new Map<string, string>()
    return { items, getItem: (key) => items.get(key) ?? null, setItem: (key, value) => void items.set(key, value) }
  }

  it("answers true the first time for a key, then false", () => {
    const storage = memory()
    expect(firstShowing("goal-reward-2026-10-05", storage)).toBe(true)
    expect(firstShowing("goal-reward-2026-10-05", storage)).toBe(false)
    expect(storage.items.get(`${TOAST_ONCE_PREFIX}goal-reward-2026-10-05`)).toBe("1")
  })

  it("keeps keys apart", () => {
    const storage = memory()
    expect(firstShowing("goal-reward-2026-10-05", storage)).toBe(true)
    expect(firstShowing("goal-reward-2026-10-12", storage)).toBe(true)
  })

  it("shows the toast when storage is missing or refuses", () => {
    expect(firstShowing("goal-reward-2026-10-05", null)).toBe(true)
    const refusing = {
      getItem: (): string | null => {
        throw new Error("blocked")
      },
      setItem: (): void => {
        throw new Error("blocked")
      },
    }
    expect(firstShowing("goal-reward-2026-10-05", refusing)).toBe(true)
    expect(firstShowing("goal-reward-2026-10-05", refusing)).toBe(true)
  })
})

describe("RevealHold", () => {
  it("holds a marked toast while an opening is revealing and releases the held ones in arrival order", () => {
    const hold = new RevealHold<string>()
    expect(hold.revealingChanged(true)).toEqual([])
    expect(hold.hold("Première Épique", true)).toBe(true)
    expect(hold.hold("Premier set complet", true)).toBe(true)
    expect(hold.revealingChanged(false)).toEqual(["Première Épique", "Premier set complet"])
    expect(hold.revealingChanged(false)).toEqual([])
  })

  it("never holds an unmarked toast", () => {
    const hold = new RevealHold<string>()
    hold.revealingChanged(true)
    expect(hold.hold("Proposition envoyée", false)).toBe(false)
    expect(hold.revealingChanged(false)).toEqual([])
  })

  it("lets a marked toast through when no opening is revealing", () => {
    const hold = new RevealHold<string>()
    expect(hold.hold("Premier booster", true)).toBe(false)
    hold.revealingChanged(true)
    hold.revealingChanged(false)
    expect(hold.hold("Premier échange", true)).toBe(false)
  })

  it("keeps holding while the reveal goes on", () => {
    const hold = new RevealHold<string>()
    hold.revealingChanged(true)
    hold.hold("Premier booster", true)
    expect(hold.revealingChanged(true)).toEqual([])
    expect(hold.revealingChanged(false)).toEqual(["Premier booster"])
  })

  it("drops the held toasts and stops holding once cleared", () => {
    const hold = new RevealHold<string>()
    hold.revealingChanged(true)
    hold.hold("Premier booster", true)
    hold.clear()
    expect(hold.hold("Première Légendaire", true)).toBe(false)
    expect(hold.revealingChanged(false)).toEqual([])
  })
})
