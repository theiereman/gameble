// @vitest-environment happy-dom
import { describe, expect, it } from "vitest"
import {
  STATUS_INTERVAL_MS,
  flush,
  idle,
  milestones,
  offer,
  readLine,
  readOutcome,
  type StatusKind,
  type Throttle,
} from "./annonce_status"

const T0 = 1_000_000

function after(throttle: Throttle, text: string, kind: StatusKind, now: number, reduced = false) {
  return offer(throttle, text, kind, now, reduced)
}

describe("offer", () => {
  it("posts the first update at once", () => {
    const step = after(idle, "Price 1", "update", T0)

    expect(step.say).toBe("Price 1")
    expect(step.throttle.lastSaidAt).toBe(T0)
  })

  it("holds a second update for the rest of the 10 seconds and says when to post it", () => {
    const first = after(idle, "Price 1", "update", T0)
    const second = after(first.throttle, "Price 2", "update", T0 + 3_000)

    expect(second.say).toBeNull()
    expect(second.throttle.waiting).toBe("Price 2")
    expect(second.wait).toBe(STATUS_INTERVAL_MS - 3_000)
  })

  it("keeps only the last update of a burst and never drops it", () => {
    const first = after(idle, "Price 1", "update", T0)
    const second = after(first.throttle, "Price 2", "update", T0 + 2_000)
    const third = after(second.throttle, "Price 3", "update", T0 + 4_000)

    expect(third.say).toBeNull()
    expect(third.wait).toBeNull()
    const flushed = flush(third.throttle, T0 + STATUS_INTERVAL_MS)
    expect(flushed.say).toBe("Price 3")
    expect(flushed.throttle.waiting).toBeNull()
    expect(flushed.throttle.lastSaidAt).toBe(T0 + STATUS_INTERVAL_MS)
  })

  it("posts again straight away once the 10 seconds have passed", () => {
    const first = after(idle, "Price 1", "update", T0)

    expect(after(first.throttle, "Price 2", "update", T0 + STATUS_INTERVAL_MS).say).toBe("Price 2")
  })

  it("does not post an unchanged text and cancels a waiting one that came back to it", () => {
    const first = after(idle, "Price 1", "update", T0)
    const waiting = after(first.throttle, "Price 2", "update", T0 + 1_000)

    expect(after(first.throttle, "Price 1", "update", T0 + 20_000).say).toBeNull()
    expect(after(waiting.throttle, "Price 1", "update", T0 + 2_000).throttle.waiting).toBeNull()
  })

  it("posts nothing empty", () => {
    expect(after(idle, "", "update", T0).say).toBeNull()
  })
})

describe("the bypass", () => {
  it("posts an extension at once, within the 10 seconds, and drops the waiting update", () => {
    const first = after(idle, "Price 1", "update", T0)
    const waiting = after(first.throttle, "Price 2", "update", T0 + 1_000)
    const extension = after(waiting.throttle, "Price 3, ends later", "extension", T0 + 2_000)

    expect(extension.say).toBe("Price 3, ends later")
    expect(extension.throttle.waiting).toBeNull()
  })

  it("posts the end at once, even right after another post", () => {
    const first = after(idle, "Price 1", "update", T0)

    expect(after(first.throttle, "AUCTION ENDED", "end", T0 + 1).say).toBe("AUCTION ENDED")
  })
})

describe("reduced motion", () => {
  it("stays silent about other players' bids", () => {
    const step = after(idle, "Price 1", "update", T0, true)

    expect(step.say).toBeNull()
    expect(step.throttle).toEqual(idle)
  })

  it("never silences the end, an extension or a bidder's milestone", () => {
    expect(after(idle, "AUCTION ENDED", "end", T0, true).say).toBe("AUCTION ENDED")
    expect(after(idle, "Ends later", "extension", T0, true).say).toBe("Ends later")
    expect(after(idle, "Price 1", "milestone", T0, true).say).toBe("Price 1")
  })

  it("posts a milestone even when its text was already said", () => {
    const first = after(idle, "Price 1", "update", T0)

    expect(after(first.throttle, "Price 1", "milestone", T0 + STATUS_INTERVAL_MS).say).toBe("Price 1")
  })
})

describe("milestones", () => {
  const now = Date.parse("2026-11-10T12:00:00Z")

  it("gives the delays to the last hour and to 3 minutes left", () => {
    expect(milestones("2026-11-10T14:00:00Z", now)).toEqual([3_600_000, 7_020_000])
  })

  it("keeps only the moments still ahead", () => {
    expect(milestones("2026-11-10T12:30:00Z", now)).toEqual([1_620_000])
    expect(milestones("2026-11-10T12:02:00Z", now)).toEqual([])
  })

  it("ignores an unreadable end", () => {
    expect(milestones("soon", now)).toEqual([])
  })
})

describe("reading the page", () => {
  it("reads the status line the server drew", () => {
    document.body.innerHTML = `<div hidden data-status-text="Price 1. Ends at 12:00." data-status-ends-at="2026-11-10T12:00:00Z" data-status-bidder="true"></div>`

    expect(readLine(document.body)).toEqual({
      text: "Price 1. Ends at 12:00.",
      endsAt: "2026-11-10T12:00:00Z",
      bidder: true,
    })
  })

  it("reads no line once the page shows an outcome, and the outcome's heading", () => {
    document.body.innerHTML = `<h2 id="listing-outcome-heading"> AUCTION ENDED </h2>`

    expect(readLine(document.body)).toBeNull()
    expect(readOutcome(document.body)).toBe("AUCTION ENDED")
  })
})
