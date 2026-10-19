import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import { artPixels, sameArtSize, settle } from "./fluid_size"

const SERVER_M = { width: 72, height: 74 }

describe("artPixels", () => {
  it("halves the art box: a grid face at 160px draws card-m's 72 × 74", () => {
    expect(artPixels(144, 148, SERVER_M)).toEqual({ width: 72, height: 74 })
  })

  it("follows a larger or smaller art box", () => {
    expect(artPixels(154, 162, SERVER_M)).toEqual({ width: 77, height: 81 })
    expect(artPixels(108, 112, SERVER_M)).toEqual({ width: 54, height: 56 })
  })

  it("rounds a fractional box down", () => {
    expect(artPixels(145.6, 149.9, SERVER_M)).toEqual({ width: 72, height: 74 })
  })

  it("keeps the server's size for a box with no layout", () => {
    expect(artPixels(0, 0, SERVER_M)).toBe(SERVER_M)
    expect(artPixels(144, 0, SERVER_M)).toBe(SERVER_M)
    expect(artPixels(1, 148, SERVER_M)).toBe(SERVER_M)
    expect(artPixels(-4, 148, SERVER_M)).toBe(SERVER_M)
  })
})

describe("sameArtSize", () => {
  it("compares both dimensions, and nothing drawn yet differs", () => {
    expect(sameArtSize({ width: 72, height: 74 }, { width: 72, height: 74 })).toBe(true)
    expect(sameArtSize({ width: 72, height: 74 }, { width: 72, height: 75 })).toBe(false)
    expect(sameArtSize(undefined, { width: 72, height: 74 })).toBe(false)
  })
})

describe("settle", () => {
  beforeEach(() => vi.useFakeTimers())
  afterEach(() => vi.useRealTimers())

  it("runs once the calls stop for the delay", () => {
    const callback = vi.fn()
    const resize = settle(callback, 150)

    resize.schedule()
    vi.advanceTimersByTime(100)
    resize.schedule()
    vi.advanceTimersByTime(149)
    expect(callback).not.toHaveBeenCalled()

    vi.advanceTimersByTime(1)
    expect(callback).toHaveBeenCalledOnce()
  })

  it("drops a pending run on cancel", () => {
    const callback = vi.fn()
    const resize = settle(callback, 150)

    resize.schedule()
    resize.cancel()
    vi.advanceTimersByTime(500)

    expect(callback).not.toHaveBeenCalled()
  })
})
