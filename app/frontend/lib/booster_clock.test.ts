import { describe, expect, it } from "vitest"
import { formatClock, formatDailyClock, secondsUntil } from "./booster_clock"

describe("formatClock", () => {
  it("shows hours from an hour, else minutes and seconds", () => {
    expect(formatClock(59)).toBe("00:59")
    expect(formatClock(600)).toBe("10:00")
    expect(formatClock(3599)).toBe("59:59")
    expect(formatClock(3600)).toBe("1:00:00")
    expect(formatClock(6130)).toBe("1:42:10")
    expect(formatClock(-4)).toBe("00:00")
  })
})

describe("formatDailyClock", () => {
  it("always shows two-digit hours, minutes and seconds", () => {
    expect(formatDailyClock(0)).toBe("00:00:00")
    expect(formatDailyClock(59)).toBe("00:00:59")
    expect(formatDailyClock(3600)).toBe("01:00:00")
    expect(formatDailyClock(86399)).toBe("23:59:59")
    expect(formatDailyClock(-4)).toBe("00:00:00")
  })
})

describe("secondsUntil", () => {
  it("counts whole seconds from the server's time, rounded up", () => {
    expect(secondsUntil("2026-10-06T14:32:00.000Z", "2026-10-06T14:22:00.000Z")).toBe(600)
    expect(secondsUntil("2026-10-06T14:32:00.000Z", "2026-10-06T14:31:59.500Z")).toBe(1)
    expect(secondsUntil("2026-10-06T14:22:00.000Z", "2026-10-06T14:23:00.000Z")).toBe(0)
    expect(secondsUntil(null, "2026-10-06T14:22:00.000Z")).toBeNull()
  })
})
