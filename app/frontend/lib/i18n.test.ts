import { describe, expect, it } from "vitest"
import { formatNumber, pluralForm, t } from "./i18n"

describe("t", () => {
  it("fills every placeholder of a plain template", () => {
    expect(t("Cartes révélées : %{revealed} / %{total}", { revealed: 2, total: 5 })).toBe("Cartes révélées : 2 / 5")
  })

  it("picks one at 1 and other otherwise, zero only when the template has it", () => {
    const template = { one: "%{n} booster", other: "%{n} boosters" }
    expect(t(template, { count: 1, n: "1" })).toBe("1 booster")
    expect(t(template, { count: 2, n: "2" })).toBe("2 boosters")
    expect(t(template, { count: 0, n: "0" })).toBe("0 boosters")
    expect(t({ zero: "Aucun", one: "Un", other: "%{n}" }, { count: 0 })).toBe("Aucun")
  })

  it("reads other without a count", () => {
    expect(pluralForm({ one: "un", other: "plusieurs" }, undefined)).toBe("plusieurs")
  })

  it("leaves a placeholder without value as it is", () => {
    expect(t("%{title} · %{year}", { title: "Portal" })).toBe("Portal · %{year}")
  })
})

describe("formatNumber", () => {
  it("groups digits by three with the locale's delimiter", () => {
    expect(formatNumber(31420, " ")).toBe("31 420")
    expect(formatNumber(1234567, ",")).toBe("1,234,567")
    expect(formatNumber(999, ",")).toBe("999")
    expect(formatNumber(0, ",")).toBe("0")
  })
})
