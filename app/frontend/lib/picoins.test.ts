import picoinFormsJson from "../../../test/fixtures/files/picoin_forms.json?raw"
import { describe, expect, it } from "vitest"
import { picoins } from "./picoins"

type Row = { amount: number; locale: string; compact: boolean; text: string }

const rows: Row[] = JSON.parse(picoinFormsJson)

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

const sources: Record<string, string> = import.meta.glob(["../**/*.ts", "!../**/*.test.ts", "!../images/**"], {
  query: "?raw",
  import: "default",
  eager: true,
})

describe("number formatting", () => {
  it("never goes through Intl.NumberFormat or toLocaleString", () => {
    const offenders = Object.entries(sources)
      .filter(([, source]) => /Intl\.NumberFormat|toLocaleString\(/.test(source))
      .map(([path]) => path)
    expect(Object.keys(sources).length).toBeGreaterThan(50)
    expect(offenders).toEqual([])
  })
})
