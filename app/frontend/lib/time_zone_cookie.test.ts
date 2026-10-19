import { describe, expect, it } from "vitest"
import { timeZoneCookie } from "./time_zone_cookie"

describe("timeZoneCookie", () => {
  it("stores the zone for a year, site-wide", () => {
    expect(timeZoneCookie("Europe/Paris", "", false)).toBe("time_zone=Europe%2FParis; path=/; max-age=31536000; samesite=lax")
  })

  it("is secure over HTTPS", () => {
    expect(timeZoneCookie("Europe/Paris", "", true)).toMatch(/; secure$/)
  })

  it("writes nothing when the same zone is already stored", () => {
    expect(timeZoneCookie("Europe/Paris", "motion=reduced; time_zone=Europe%2FParis", false)).toBeNull()
  })

  it("replaces a zone the browser has left", () => {
    expect(timeZoneCookie("America/New_York", "time_zone=Europe%2FParis", false)).toMatch(/^time_zone=America%2FNew_York;/)
  })

  it("writes nothing for an unknown zone", () => {
    expect(timeZoneCookie(undefined, "", false)).toBeNull()
    expect(timeZoneCookie("", "", false)).toBeNull()
  })
})
