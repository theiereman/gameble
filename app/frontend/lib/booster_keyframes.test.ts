import { describe, expect, it } from "vitest"
import { phoneSwell, pose } from "./booster_motion"
import {
  bannerKeyframes,
  legendaryDropKeyframes,
  legendaryJumpKeyframes,
  storeKeyframes,
  trembleKeyframes,
} from "./booster_keyframes"

const asIs = (scale: number) => scale
const first = (keyframes: Keyframe[]) => keyframes[0]
const last = (keyframes: Keyframe[]) => keyframes[keyframes.length - 1]

describe("booster keyframes", () => {
  it("takes the swell from the layout", () => {
    expect(last(trembleKeyframes(3, 26, phoneSwell))).toEqual({
      transform: "translate(0px, -26px) rotate(0deg) scale(1.015, 1.015)",
    })
  })

  it("jumps a Légendaire in 14 steps to its rise, then drops it back to rest", () => {
    const jump = legendaryJumpKeyframes(50, asIs)
    expect(jump).toHaveLength(16)
    expect(first(jump)).toEqual({ transform: pose() })
    expect(last(jump)).toEqual({ transform: "translate(0px, -50px) rotate(0deg) scale(1.15, 1.15)" })
    const drop = legendaryDropKeyframes(50, asIs)
    expect(first(drop)).toEqual(last(jump))
    expect(last(drop)).toEqual({ transform: pose() })
  })

  it("stores a card from where the swipe left it into its slot, shrunk to the slot's width", () => {
    const keyframes = storeKeyframes(
      "translate(12px, 0px)",
      { left: 0, top: 0, width: 100, height: 140 },
      { left: 200, top: 300, width: 44, height: 60 },
    )
    expect(first(keyframes)).toEqual({ transform: "translate(12px, 0px)", opacity: 1 })
    expect(last(keyframes)).toEqual({ transform: "translate(172px, 260px) scale(0.440)", opacity: 0 })
  })

  it("slams the banner in, or fades it in place under reduced motion", () => {
    expect(first(bannerKeyframes(false))).toEqual({ opacity: 0, transform: "translateY(0px) scale(2.2, 0.2)" })
    expect(last(bannerKeyframes(false))).toEqual({ opacity: 0, transform: "translateY(-16px) scale(1, 1)" })
    expect(first(bannerKeyframes(true))).toEqual({ opacity: 0 })
    expect(last(bannerKeyframes(true))).toEqual({ opacity: 0 })
  })
})
