import { describe, expect, it } from "vitest"
import { formatLocalTime, isLocalTimeStyle } from "./local_time"

const paris = { locale: "fr", timeZone: "Europe/Paris" }
const newYork = { locale: "fr", timeZone: "America/New_York" }
const nextDay = "2026-10-15T00:00:00Z"
const nextWeek = "2026-10-19T00:00:00Z"

describe("formatLocalTime", () => {
  it("shows the next booster at the reader's local date and time", () => {
    expect(formatLocalTime(nextDay, "datetime", paris)).toBe("15 oct., 02:00")
  })

  it("takes the local date when it differs from the UTC one", () => {
    expect(formatLocalTime("2026-10-14T23:30:00Z", "datetime", paris)).toBe("15 oct., 01:30")
  })

  it("follows the reader's zone", () => {
    expect(formatLocalTime(nextDay, "datetime", newYork)).toBe("14 oct., 20:00")
  })

  it("follows the page's locale", () => {
    expect(formatLocalTime(nextDay, "datetime", { locale: "en", timeZone: "Europe/Paris" })).toBe("Oct 15, 02:00")
  })

  it("adds the year for a date kept on the page", () => {
    expect(formatLocalTime("2026-10-04T07:05:00Z", "date-time-year", paris)).toBe("4 oct. 2026, 09:05")
    expect(formatLocalTime(new Date("2026-10-04T07:05:00Z"), "date-time-year", { locale: "en", timeZone: "Europe/Paris" }))
      .toBe("Oct 4, 2026, 09:05")
  })

  it("gives the day change as a local time and the week start as a local weekday and time", () => {
    expect(formatLocalTime(nextDay, "time", paris)).toBe("02:00")
    expect(formatLocalTime(nextWeek, "weekday-time", paris)).toBe("lundi 02:00")
    expect(formatLocalTime(nextWeek, "weekday-time", newYork)).toBe("dimanche 20:00")
    expect(formatLocalTime(nextWeek, "weekday-time", { locale: "en", timeZone: "Europe/Paris" })).toBe("Monday 02:00")
  })

  it("writes midnight as 00:00", () => {
    expect(formatLocalTime(nextDay, "time", { locale: "en", timeZone: "UTC" })).toBe("00:00")
  })

  it("gives nothing for an instant or a zone it cannot read", () => {
    expect(formatLocalTime("", "datetime", paris)).toBeNull()
    expect(formatLocalTime("tomorrow", "datetime", paris)).toBeNull()
    expect(formatLocalTime(nextDay, "datetime", { locale: "fr", timeZone: "Mars/Olympus" })).toBeNull()
  })

  it("falls back on the default locale without one", () => {
    expect(formatLocalTime(nextDay, "time", { locale: "", timeZone: "Europe/Paris" })).toBe("02:00")
  })
})

describe("isLocalTimeStyle", () => {
  it("knows the four styles", () => {
    expect(["datetime", "date-time-year", "time", "weekday-time"].every(isLocalTimeStyle)).toBe(true)
    expect(isLocalTimeStyle("relative")).toBe(false)
    expect(isLocalTimeStyle("toString")).toBe(false)
  })
})
