import { readdirSync, readFileSync, statSync } from "node:fs"
import { join } from "node:path"
import { describe, expect, it } from "vitest"
import { picoins } from "./picoins"

type Row = { amount: number; locale: string; compact: boolean; text: string }

const rows: Row[] = JSON.parse(readFileSync("test/fixtures/files/picoin_forms.json", "utf8"))

describe("picoins", () => {
  it.each(rows)("draws $amount ($locale, compact $compact) as $text", ({ amount, locale, compact, text }) => {
    expect(picoins(amount, { locale, compact })).toBe(text)
  })

  it("refuses what is not a whole non-negative amount", () => {
    for (const bad of [
      1.5,
      -1,
      Number.NaN,
      "12" as unknown as number,
      "12x" as unknown as number,
      null as unknown as number,
      undefined as unknown as number,
    ]) {
      expect(() => picoins(bad)).toThrow(RangeError)
    }
  })

  it("reads an unknown locale as English", () => {
    expect(picoins(31_599, { locale: "de", compact: true })).toBe("31.5k")
    expect(picoins(1_234_567, { locale: "de" })).toBe("1,234,567")
  })
})

function sources(dir: string): string[] {
  return readdirSync(dir).flatMap((name) => {
    const path = join(dir, name)
    if (statSync(path).isDirectory()) return name === "images" ? [] : sources(path)
    return /\.ts$/.test(name) && !/\.test\.ts$/.test(name) ? [path] : []
  })
}

describe("number formatting", () => {
  it("never goes through Intl.NumberFormat or toLocaleString", () => {
    const offenders = sources("app/frontend").filter((path) =>
      /Intl\.NumberFormat|toLocaleString\(/.test(readFileSync(path, "utf8")),
    )
    expect(offenders).toEqual([])
  })
})
