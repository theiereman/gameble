import { describe, expect, it } from "vitest"
import { clearsOnEscape, Debounce, summaryOf, TYPING_PAUSE_MS, type Timers } from "./set_search"

function fakeTimers(): Timers & { pending: Map<number, () => void>; delays: number[]; fire(): void } {
  let next = 0
  const pending = new Map<number, () => void>()
  const delays: number[] = []
  return {
    pending,
    delays,
    set(callback, delay) {
      next += 1
      pending.set(next, callback)
      delays.push(delay)
      return next
    },
    clear(handle) {
      if (handle !== undefined) pending.delete(handle)
    },
    fire() {
      for (const [handle, callback] of [...pending]) {
        pending.delete(handle)
        callback()
      }
    },
  }
}

describe("Debounce", () => {
  it("runs once typing has paused for 300 ms", () => {
    const timers = fakeTimers()
    const debounce = new Debounce(TYPING_PAUSE_MS, timers)
    let sent = 0

    debounce.call(() => (sent += 1))

    expect(sent).toBe(0)
    expect(timers.delays).toEqual([300])
    timers.fire()
    expect(sent).toBe(1)
  })

  it("keeps only the latest call while typing goes on", () => {
    const timers = fakeTimers()
    const debounce = new Debounce(TYPING_PAUSE_MS, timers)
    const sent: string[] = []

    debounce.call(() => sent.push("s"))
    debounce.call(() => sent.push("so"))
    debounce.call(() => sent.push("sou"))

    expect(timers.pending.size).toBe(1)
    timers.fire()
    expect(sent).toEqual(["sou"])
  })

  it("sends nothing once cancelled", () => {
    const timers = fakeTimers()
    const debounce = new Debounce(TYPING_PAUSE_MS, timers)
    let sent = 0

    debounce.call(() => (sent += 1))
    debounce.cancel()
    timers.fire()

    expect(sent).toBe(0)
  })
})

describe("clearsOnEscape", () => {
  it("clears a field holding text on Esc", () => {
    expect(clearsOnEscape("Escape", "souls")).toBe(true)
  })

  it("leaves an empty field and other keys alone", () => {
    expect(clearsOnEscape("Escape", "")).toBe(false)
    expect(clearsOnEscape("Enter", "souls")).toBe(false)
  })
})

describe("summaryOf", () => {
  it("reads the count line, trimmed, blank for none", () => {
    expect(summaryOf("  1 set trouvé \n")).toBe("1 set trouvé")
    expect(summaryOf(null)).toBe("")
    expect(summaryOf(undefined)).toBe("")
  })
})
