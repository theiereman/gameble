import { describe, expect, it } from "vitest"
import { isFlatGrey, isPlaceholder, isTooSmall, MIN_SOURCE } from "./placeholder"
import { fromPixels, image } from "./test_helpers"

describe("placeholder", () => {
  it("takes 300 × 450 as the smallest cover", () => {
    expect(MIN_SOURCE).toEqual({ width: 300, height: 450 })
    expect(isTooSmall(300, 450)).toBe(false)
    expect(isTooSmall(299, 450)).toBe(true)
    expect(isTooSmall(300, 449)).toBe(true)
    expect(isTooSmall(600, 900)).toBe(false)
  })

  it("counts near-uniform grey pixels as flat grey", () => {
    expect(isFlatGrey(fromPixels(2, 1, [[128, 130, 129, 255], [132, 134, 133, 255]]))).toBe(true)
    expect(isFlatGrey(fromPixels(2, 1, [[128, 131, 129, 255], [128, 128, 128, 255]]))).toBe(false)
  })

  it("accepts grayscale art with meaningful tonal variation", () => {
    expect(isFlatGrey(fromPixels(2, 1, [[0, 0, 0, 255], [255, 255, 255, 255]]))).toBe(false)
  })

  it("ignores transparent pixels, and counts an image with no other as flat grey", () => {
    expect(isFlatGrey(fromPixels(2, 1, [[255, 0, 0, 0], [9, 9, 9, 255]]))).toBe(true)
    expect(isFlatGrey(fromPixels(1, 1, [[255, 0, 0, 0]]))).toBe(true)
  })

  it("calls a small or flat grey image a placeholder", () => {
    const colour = (x: number, y: number): [number, number, number, number] => [x % 256, y % 256, 50, 255]
    expect(isPlaceholder(image(300, 450, colour))).toBe(false)
    expect(isPlaceholder(image(300, 449, colour))).toBe(true)
    expect(isPlaceholder(image(300, 450, () => [140, 140, 141, 255]))).toBe(true)
  })
})
