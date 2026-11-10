import { describe, expect, it } from "vitest"
import { OUTBID_INTERVAL_MS, flushOutbid, noOutbids, offerOutbid } from "./outbid_status"

const T0 = 1_000_000

describe("offerOutbid", () => {
  it("posts the first outbid of a listing at once", () => {
    const step = offerOutbid(noOutbids, "listing-a", "Hugo went past your maximum", T0)

    expect(step.say).toBe("Hugo went past your maximum")
    expect(step.wait).toBeNull()
  })

  it("holds a second outbid of the same listing for the rest of the 30 seconds", () => {
    const first = offerOutbid(noOutbids, "listing-a", "First", T0)
    const second = offerOutbid(first.outbids, "listing-a", "Second", T0 + 5_000)

    expect(second.say).toBeNull()
    expect(second.wait).toBe(OUTBID_INTERVAL_MS - 5_000)
  })

  it("keeps the last held line and posts it when the wait is over", () => {
    const first = offerOutbid(noOutbids, "listing-a", "First", T0)
    const second = offerOutbid(first.outbids, "listing-a", "Second", T0 + 5_000)
    const third = offerOutbid(second.outbids, "listing-a", "Third", T0 + 9_000)

    expect(third.wait).toBeNull()
    const flushed = flushOutbid(third.outbids, "listing-a", T0 + OUTBID_INTERVAL_MS)
    expect(flushed.say).toBe("Third")
  })

  it("posts again once 30 seconds have passed", () => {
    const first = offerOutbid(noOutbids, "listing-a", "First", T0)

    expect(offerOutbid(first.outbids, "listing-a", "Again", T0 + OUTBID_INTERVAL_MS).say).toBe("Again")
  })

  it("counts each listing on its own", () => {
    const first = offerOutbid(noOutbids, "listing-a", "A", T0)

    expect(offerOutbid(first.outbids, "listing-b", "B", T0 + 1_000).say).toBe("B")
  })

  it("never reads an empty line", () => {
    expect(offerOutbid(noOutbids, "listing-a", "", T0).say).toBeNull()
  })
})
