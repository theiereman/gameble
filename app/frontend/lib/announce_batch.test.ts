import { describe, expect, it } from "vitest"
import { ANNOUNCE_INTERVAL_MS, AnnounceBatch, beyondLimit, shouldAnnounce } from "./announce_batch"

describe("AnnounceBatch", () => {
  it("opens a batch with the first arrival, due after the interval", () => {
    const batch = new AnnounceBatch()
    expect(batch.add(1)).toBe(ANNOUNCE_INTERVAL_MS)
  })

  it("gathers the arrivals of an open batch into one count", () => {
    const batch = new AnnounceBatch()
    batch.add(1)
    expect(batch.add(2)).toBeNull()
    expect(batch.take()).toBe(3)
  })

  it("opens a new batch once the last one was taken", () => {
    const batch = new AnnounceBatch(1000)
    batch.add(1)
    batch.take()
    expect(batch.take()).toBe(0)
    expect(batch.add(4)).toBe(1000)
    expect(batch.take()).toBe(4)
  })

  it("opens nothing for no entry", () => {
    const batch = new AnnounceBatch()
    expect(batch.add(0)).toBeNull()
    expect(batch.add(1)).toBe(ANNOUNCE_INTERVAL_MS)
  })
})

describe("shouldAnnounce", () => {
  it("announces new entries while the list is not focused", () => {
    expect(shouldAnnounce(3, { reduced: false, focusInside: false })).toBe(true)
  })

  it("stays silent under reduced motion, inside the list, or with nothing new", () => {
    expect(shouldAnnounce(3, { reduced: true, focusInside: false })).toBe(false)
    expect(shouldAnnounce(3, { reduced: false, focusInside: true })).toBe(false)
    expect(shouldAnnounce(0, { reduced: false, focusInside: false })).toBe(false)
  })
})

describe("beyondLimit", () => {
  it("answers the entries past the limit, the oldest, to remove", () => {
    expect(beyondLimit(["new", "b", "c", "old"], 2)).toEqual(["c", "old"])
    expect(beyondLimit(["a"], 30)).toEqual([])
  })
})
