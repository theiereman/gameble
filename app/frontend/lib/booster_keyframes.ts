// The booster protocol's inline keyframe lists: the opacity fades, the
// canister's arming, caps, body and dock, the cards' sink, reveal,
// Légendaire sequence, store, slot pop and spring back, and the banner.
// Pure: each list from its inputs, no DOM. The durations come from
// lib/booster_motion.ts and the easings are chosen at the island's call sites,
// except that the arming list carries its own easings between frames and
// the tremble takes its step count from TREMBLE_MS. A reveal's swell (its
// scale) comes in as a function, so the island damps it on the phone.
import { DOCK_PX, SINK_PX, TREMBLE_MS, pose, scaled } from "./booster_motion"

/** A reveal's scale, as the layout draws it. */
export type Swell = (scale: number) => number

/** A box on the page, as getBoundingClientRect gives it. */
export type Box = { left: number; top: number; width: number; height: number }

const easeOut = (progress: number) => 1 - (1 - progress) ** 3

/** An opacity fade, without motion. */
export function fadeKeyframes(from: number, to: number): Keyframe[] {
  return [{ opacity: from }, { opacity: to }]
}

// ---- The canister ----

/** ARMEMENT: the canister squashes and stretches while the request runs. */
export function armKeyframes(): Keyframe[] {
  return [
    { transform: pose(), easing: "cubic-bezier(.4,0,.6,1)" },
    { transform: pose(0, 8, 0, 1.1, 0.9), offset: 0.4, easing: "cubic-bezier(.3,.9,.4,1)" },
    { transform: pose(-1.5, -2, -1, 0.96, 1.06), offset: 0.62 },
    { transform: pose(1.5, -3, 1, 0.97, 1.07), offset: 0.76 },
    { transform: pose(-1, -4, -1, 0.96, 1.09), offset: 0.9 },
    { transform: pose(0, -4, 0, 0.95, 1.1) },
  ]
}

/** The top cap blowing off, up and to the left. */
export function capTopKeyframes(): Keyframe[] {
  return [
    { transform: pose(), opacity: 1 },
    { transform: pose(-60, -300, -230), opacity: 1, offset: 0.72 },
    { transform: pose(-76, -360, -290), opacity: 0 },
  ]
}

/** The bottom cap blowing off, down and to the right. */
export function capBottomKeyframes(): Keyframe[] {
  return [
    { transform: pose(), opacity: 1 },
    { transform: pose(70, 270, 210), opacity: 1, offset: 0.72 },
    { transform: pose(88, 330, 260), opacity: 0 },
  ]
}

/** The body popping and fading. */
export function bodyKeyframes(): Keyframe[] {
  return [
    { transform: pose(), opacity: 1 },
    { transform: pose(0, 0, 0, 1.16, 0.9), opacity: 1, offset: 0.35 },
    { transform: pose(0, 0, 0, 1.3, 1.3), opacity: 0 },
  ]
}

/** A new canister rising into place. */
export function dockKeyframes(): Keyframe[] {
  return [
    { transform: `translateY(${DOCK_PX}px)`, opacity: 0 },
    { transform: "translateY(-8px)", opacity: 1, offset: 0.75 },
    { transform: "none", opacity: 1 },
  ]
}

// ---- The cards ----

/** A card sinking and fading from `from`, its pose. */
export function sinkKeyframes(from: string): Keyframe[] {
  return [{ transform: from, opacity: 1 }, { transform: pose(0, SINK_PX, 0, 0.92), opacity: 0 }]
}

/** An uncommon to epic card trembling as it lifts `height` px before its flip. */
export function trembleKeyframes(level: number, height: number, swell: Swell): Keyframe[] {
  const steps = Math.max(4, Math.round(TREMBLE_MS[level] / scaled(40)))
  const amplitude = level * 0.9
  const keyframes: Keyframe[] = [{ transform: pose() }]
  for (let step = 1; step < steps; step++) {
    const progress = step / steps
    const side = step % 2 === 1 ? 1 : -1
    keyframes.push({ transform: pose(side * amplitude * progress * 0.8, -height * easeOut(progress), side * amplitude * progress * 0.6, swell(1 + 0.06 * easeOut(progress))) })
  }
  keyframes.push({ transform: pose(0, -height, 0, swell(1.06)) })
  return keyframes
}

/** A common card's small lift instead of a tremble. */
export function liftKeyframes(height: number, swell: Swell): Keyframe[] {
  return [{ transform: pose() }, { transform: pose(0, -height, 0, swell(1.03)) }]
}

/** The turn, past the face and back onto it. */
export function flipKeyframes(): Keyframe[] {
  return [
    { transform: "rotateY(0deg)" },
    { transform: "rotateY(200deg)", offset: 0.72 },
    { transform: "rotateY(172deg)", offset: 0.88 },
    { transform: "rotateY(180deg)" },
  ]
}

/** The card settling back from `height` px after its flip, squashing as it lands. */
export function settleKeyframes(height: number, swell: Swell): Keyframe[] {
  return [
    { transform: pose(0, -height, 0, swell(1.06)) },
    { transform: pose(0, -height * 0.4, 0, swell(1.14), swell(0.9)), offset: 0.25 },
    { transform: pose(0, 4, 0, swell(0.95), swell(1.06)), offset: 0.6 },
    { transform: pose() },
  ]
}

// ---- Légendaire ----

/** The jump up `rise` px and the charge, shaking harder as it rises. */
export function legendaryJumpKeyframes(rise: number, swell: Swell): Keyframe[] {
  const jump: Keyframe[] = [{ transform: pose() }]
  for (let step = 1; step <= 14; step++) {
    const progress = step / 14
    const side = step % 2 === 1 ? 1 : -1
    jump.push({
      transform: pose(side * progress * 3, -rise * easeOut(Math.min(1, progress * 1.6)), side * (1 + progress * 4), swell(1 + 0.15 * easeOut(progress))),
    })
  }
  jump.push({ transform: pose(0, -rise, 0, swell(1.15)) })
  return jump
}

/** The one-and-a-half spin. */
export function legendarySpinKeyframes(): Keyframe[] {
  return [{ transform: "rotateY(0deg)" }, { transform: "rotateY(560deg)", offset: 0.8 }, { transform: "rotateY(540deg)" }]
}

/** The impact, `rise` px up: a squash and a stretch. */
export function legendaryImpactKeyframes(rise: number, swell: Swell): Keyframe[] {
  return [
    { transform: pose(0, -rise, 0, swell(1.15)) },
    { transform: pose(0, -rise + 4, 0, swell(1.28), swell(1.02)), offset: 0.22 },
    { transform: pose(0, -rise - 2, 0, swell(1.08), swell(1.22)), offset: 0.5 },
    { transform: pose(0, -rise, 0, swell(1.15)) },
  ]
}

/** The drop back from `rise` px. */
export function legendaryDropKeyframes(rise: number, swell: Swell): Keyframe[] {
  return [{ transform: pose(0, -rise, 0, swell(1.15)) }, { transform: pose() }]
}

// ---- The phone's tray ----

/** A card shrinking from `start` (where a swipe left it) in its frame `from` into its tray slot `to`, then fading. */
export function storeKeyframes(start: string, from: Box, to: Box): Keyframe[] {
  const dx = to.left + to.width / 2 - (from.left + from.width / 2)
  const dy = to.top + to.height / 2 - (from.top + from.height / 2)
  const end = `translate(${Math.round(dx)}px, ${Math.round(dy)}px) scale(${(to.width / Math.max(1, from.width)).toFixed(3)})`
  return [
    { transform: start, opacity: 1 },
    { transform: end, opacity: 1, offset: 0.82 },
    { transform: end, opacity: 0 },
  ]
}

/** The slot popping as it receives the card. */
export function slotPopKeyframes(): Keyframe[] {
  return [
    { transform: "scale(1)" },
    { transform: "scale(1.22)", offset: 0.4 },
    { transform: "scale(1)" },
  ]
}

/** A card let go after a short drag, from `from` back to the top of the pile. */
export function springBackKeyframes(from: string): Keyframe[] {
  return [{ transform: from }, { transform: "none" }]
}

// ---- The banner ----

/** The banner slamming in, holding, then rising away; under reduced motion a still fade in and out. */
export function bannerKeyframes(reduced: boolean): Keyframe[] {
  return reduced
    ? [{ opacity: 0 }, { opacity: 1, offset: 0.15 }, { opacity: 1, offset: 0.85 }, { opacity: 0 }]
    : [
        { opacity: 0, transform: "translateY(0px) scale(2.2, 0.2)" },
        { opacity: 1, transform: "translateY(0px) scale(0.86, 1.24)", offset: 0.1 },
        { opacity: 1, transform: "translateY(0px) scale(1.06, 0.95)", offset: 0.18 },
        { opacity: 1, transform: "translateY(0px) scale(1, 1)", offset: 0.26 },
        { opacity: 1, transform: "translateY(0px) scale(1, 1)", offset: 0.8 },
        { opacity: 0, transform: "translateY(-16px) scale(1, 1)" },
      ]
}
