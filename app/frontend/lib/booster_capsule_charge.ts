import { animate } from "./booster_effects"
import { fuseTiming } from "./booster_capsule_timeline"

// The charge rides the fuse's own run, so it holds with it at the blast while
// the answer is awaited. Percentages are the fuse's: the touch is at 13 %,
// the blast at 28 %, ms from the touch = % × 60 − 780.
const TOUCH = 13
const BLAST = 28
const CHARGE_SPAN = BLAST - TOUCH

const charged = (progress: number) => TOUCH + CHARGE_SPAN * progress

const at = (percent: number, frame: Keyframe): Keyframe => ({ ...frame, offset: percent / 100 })

const PRESSURE = "cubic-bezier(.5,0,.9,.6)"
const STEP = "steps(1, end)"

const squash = (x: number, y: number, light: number): Keyframe => ({
  transform: `scale(${x}, ${y})`,
  filter: `brightness(${light})`,
})

// Swells, flattens under the pressure, sucks in just before the blast, then
// springs back as it breaks.
const swellFrames = (): Keyframe[] => [
  at(0, squash(1, 1, 1)),
  at(TOUCH, { ...squash(1, 1, 1), easing: PRESSURE }),
  at(charged(0.35), { ...squash(1.02, 0.985, 1.06), easing: PRESSURE }),
  at(charged(0.7), { ...squash(1.045, 0.96, 1.12), easing: PRESSURE }),
  at(charged(0.87), { ...squash(1.09, 0.9, 1.3), easing: PRESSURE }),
  at(BLAST, squash(0.92, 1.07, 1.7)),
  at(BLAST + 0.01, { ...squash(1.12, 0.92, 1.7), easing: "ease-out" }),
  at(BLAST + 2.7, squash(1, 1, 1)),
  at(100, squash(1, 1, 1)),
]

// The seams' glow beats faster and faster up to the blast, then dies out.
const GLOW_BEATS: ReadonlyArray<readonly [number, number]> = [
  [0, 0],
  [0.18, 0.25],
  [0.3, 0.05],
  [0.48, 0.4],
  [0.58, 0.1],
  [0.7, 0.6],
  [0.78, 0.25],
  [0.86, 0.8],
  [0.92, 0.45],
  [1, 1],
]

const glowFrames = (): Keyframe[] => [
  at(0, { opacity: 0 }),
  ...GLOW_BEATS.map(([progress, opacity]) => at(charged(progress), { opacity })),
  at(BLAST + 5, { opacity: 0 }),
  at(100, { opacity: 0 }),
]

// The console's power surges in stutters as the fuse burns down.
const SURGE: ReadonlyArray<readonly [number, number]> = [
  [0, 0],
  [0.55, 0.25],
  [0.62, 0],
  [0.8, 0.35],
  [0.86, 0.05],
  [0.94, 0.5],
  [1, 0],
]

const surgeFrames = (): Keyframe[] => [
  at(0, { opacity: 0, easing: STEP }),
  ...SURGE.map(([progress, opacity]) => at(charged(progress), { opacity, easing: STEP })),
  at(100, { opacity: 0 }),
]

export function chargeCapsule(
  wrap: HTMLElement | null | undefined,
  scanlines: HTMLElement | null | undefined,
): Animation[] {
  const button = wrap?.querySelector<HTMLElement>(".booster-canister")
  const glow = wrap?.querySelector<HTMLElement>(".booster-canister__glow")
  const pieces: Array<[HTMLElement | null | undefined, Keyframe[]]> = [
    [button, swellFrames()],
    [glow, glowFrames()],
    [scanlines, surgeFrames()],
  ]
  return pieces.flatMap(([element, frames]) => animate(element, frames, fuseTiming) ?? [])
}

// ms from the touch at which the charge's taps land, light to heavy, on the glow's last beats.
export const CHARGE_TAPS: ReadonlyArray<readonly [number, 1 | 2 | 3]> = [
  [300, 1],
  [550, 2],
  [800, 3],
]
