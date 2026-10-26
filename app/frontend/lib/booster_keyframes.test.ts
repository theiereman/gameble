import { describe, expect, it } from "vitest"
import { phoneSwell, pose } from "./booster_motion"
import {
  armKeyframes,
  bannerKeyframes,
  dockKeyframes,
  legendaryDropKeyframes,
  legendaryJumpKeyframes,
  platePopKeyframes,
  sinkKeyframes,
  storeKeyframes,
  trembleKeyframes,
} from "./booster_keyframes"

const asIs = (scale: number) => scale
const first = (keyframes: Keyframe[]) => keyframes[0]
const last = (keyframes: Keyframe[]) => keyframes[keyframes.length - 1]

describe("booster keyframes", () => {
  it("arms the canister from rest to its stretched squash", () => {
    const keyframes = armKeyframes()
    expect(first(keyframes)).toEqual({ transform: "translate(0px, 0px) rotate(0deg) scale(1, 1)", easing: "cubic-bezier(.4,0,.6,1)" })
    expect(last(keyframes)).toEqual({ transform: "translate(0px, -4px) rotate(0deg) scale(0.95, 1.1)" })
  })

  it("docks a new canister from below, faded, to rest", () => {
    const keyframes = dockKeyframes()
    expect(first(keyframes)).toEqual({ transform: "translateY(220px)", opacity: 0 })
    expect(last(keyframes)).toEqual({ transform: "none", opacity: 1 })
  })

  it("sinks a card from its pose, down and faded", () => {
    const keyframes = sinkKeyframes(pose(0, 10))
    expect(first(keyframes)).toEqual({ transform: "translate(0px, 10px) rotate(0deg) scale(1, 1)", opacity: 1 })
    expect(last(keyframes)).toEqual({ transform: "translate(0px, 80px) rotate(0deg) scale(0.92, 0.92)", opacity: 0 })
  })

  it("trembles an epic up to its lift height, a step per 40ms of the prototype", () => {
    const keyframes = trembleKeyframes(3, 26, asIs)
    expect(keyframes).toHaveLength(8)
    expect(first(keyframes)).toEqual({ transform: pose() })
    expect(last(keyframes)).toEqual({ transform: "translate(0px, -26px) rotate(0deg) scale(1.06, 1.06)" })
  })

  it("takes the swell from the layout", () => {
    expect(last(trembleKeyframes(3, 26, phoneSwell))).toEqual({ transform: "translate(0px, -26px) rotate(0deg) scale(1.015, 1.015)" })
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
    const keyframes = storeKeyframes("translate(12px, 0px)", { left: 0, top: 0, width: 100, height: 140 }, { left: 200, top: 300, width: 44, height: 60 })
    expect(first(keyframes)).toEqual({ transform: "translate(12px, 0px)", opacity: 1 })
    expect(last(keyframes)).toEqual({ transform: "translate(172px, 260px) scale(0.440)", opacity: 0 })
  })

  it("slams the banner in, or fades it in place under reduced motion", () => {
    expect(first(bannerKeyframes(false))).toEqual({ opacity: 0, transform: "translateY(0px) scale(2.2, 0.2)" })
    expect(last(bannerKeyframes(false))).toEqual({ opacity: 0, transform: "translateY(-16px) scale(1, 1)" })
    expect(first(bannerKeyframes(true))).toEqual({ opacity: 0 })
    expect(last(bannerKeyframes(true))).toEqual({ opacity: 0 })
  })

  it("pops the caption plate in from a flat squash to rest", () => {
    const keyframes = platePopKeyframes()
    expect(first(keyframes)).toEqual({ transform: "scale(1.2, 0.2)", opacity: 0 })
    expect(last(keyframes)).toEqual({ transform: "scale(1, 1)", opacity: 1 })
  })
})
