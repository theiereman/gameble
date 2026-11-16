import { BLAST_AT, blastTiming } from "./booster_capsule_timeline"
import { animate, settle } from "./booster_effects"
import type { PilePose } from "./booster_motion"

// The cards leave the capsule's centre, the centre card first, arc, squash
// down and bounce into their place. The reference draws
// 104 × 146 cards: its pixel distances scale with the real card's height.
const REFERENCE_CARD_HEIGHT = 146
const FIRST_OUT = 1056
const RANK_STAGGER = 48
const SQUASH_AT = 378

export type Flight = Readonly<{
  dx: number
  dy: number
  rank: number
  turn: number
  height: number
  rest: PilePose
}>

// A card squashes onto its place this long after it leaves the capsule.
export const CARD_LANDS_AFTER_LEAVING = SQUASH_AT

export const ROW_REST: PilePose = { y: 0, scale: 1, rotate: 0 }

export const leavesAfterBlast = (rank: number) => FIRST_OUT + rank * RANK_STAGGER - BLAST_AT

export const flightTurn = (index: number, count: number) => (index - (count - 1) / 2) * 12

export const flightRank = (index: number, count: number) => Math.abs(index - (count - 1) / 2)

const round = (value: number, digits: number) => Number(value.toFixed(digits))

const place = (x: number, y: number, scaleX: number, scaleY: number, turn: number) =>
  `translate(${round(x, 1)}px, ${round(y, 1)}px) scale(${round(scaleX, 3)}, ${round(scaleY, 3)}) rotate(${round(turn, 2)}deg)`

export function cardFlight({ dx, dy, rank, turn, height, rest }: Flight): {
  keyframes: Keyframe[]
  options: KeyframeAnimationOptions
} {
  const k = height / REFERENCE_CARD_HEIGHT
  const { y, scale, rotate: tilt } = rest
  const resting = place(0, y, scale, scale, tilt)
  const start = FIRST_OUT + rank * RANK_STAGGER
  const steps: Array<[number, Keyframe]> = [
    [-6, { opacity: 0, transform: place(dx, dy, 0.2, 0.2, 0) }],
    [0, { opacity: 1, transform: place(dx, dy, 0.35, 0.35, 0), easing: "cubic-bezier(.2,.9,.4,1)" }],
    [
      210,
      {
        opacity: 1,
        transform: place(dx * 0.45, dy * 0.45 - 74 * k, 1.14, 1.14, turn),
        easing: "cubic-bezier(.6,0,.9,.5)",
      },
    ],
    [
      SQUASH_AT,
      { opacity: 1, transform: place(0, y + 5 * k, scale * 1.1, scale * 0.88, tilt - turn * 0.35), easing: "ease-out" },
    ],
    [
      492,
      {
        opacity: 1,
        transform: place(0, y - 7 * k, scale * 0.95, scale * 1.06, tilt + turn * 0.15),
        easing: "ease-in-out",
      },
    ],
    [600, { opacity: 1, transform: resting, easing: "ease-in-out" }],
  ]
  const first = steps[0][0]
  const duration = steps[steps.length - 1][0] - first
  return {
    keyframes: steps.map(([time, frame]) => ({ ...frame, offset: (time - first) / duration })),
    options: { duration, delay: start + first - BLAST_AT, fill: "backwards", easing: "linear" },
  }
}

const at = (percents: number[], frame: Keyframe): Keyframe[] =>
  percents.map((percent) => ({ ...frame, offset: percent / 100 }))

const GLOW_FRAMES: Keyframe[] = [...at([0, 31], { opacity: 0 }), ...at([37, 86, 100], { opacity: 1 })]

const TWINKLE_FRAMES: Keyframe[] = [
  ...at([0, 38], { opacity: 0, transform: "scale(0.5)" }),
  ...at([41], { opacity: 1, transform: "scale(1.3)" }),
  ...at([46, 60], { opacity: 0, transform: "scale(0.5)" }),
  ...at([64], { opacity: 1, transform: "scale(1)" }),
  ...at([70, 100], { opacity: 0, transform: "scale(0.5)" }),
]

// The reference's row of five, its glow and its twinkles, in its scene's pixels.
const ROW = { left: 72, top: 319, width: 576, height: 146 }
const GLOW = { left: 40, top: 259, width: 640, height: 266 }
const TWINKLES: ReadonlyArray<readonly [number, number]> = [
  [60, 299],
  [660, 329],
  [300, 289],
  [470, 479],
  [180, 471],
]

// The glow and twinkles laid on the dealt row, scaled from the reference row to the real one.
export function lightRow(layer: HTMLElement | null, frames: DOMRect[]): void {
  if (!layer || frames.length === 0) return
  const box = layer.getBoundingClientRect()
  const left = Math.min(...frames.map((frame) => frame.left)) - box.left
  const top = Math.min(...frames.map((frame) => frame.top)) - box.top
  const scaleX = (Math.max(...frames.map((frame) => frame.right)) - box.left - left) / ROW.width
  const scaleY = (Math.max(...frames.map((frame) => frame.bottom)) - box.top - top) / ROW.height
  const x = (reference: number) => `${Math.round(left + (reference - ROW.left) * scaleX)}px`
  const y = (reference: number) => `${Math.round(top + (reference - ROW.top) * scaleY)}px`
  const [glow, ...twinkles] = Array.from(layer.children) as HTMLElement[]
  settle(glow)
  const cardsMiddle = top + (ROW.height * scaleY) / 2
  Object.assign(glow.style, {
    left: x(GLOW.left),
    top: `${Math.round(cardsMiddle - (GLOW.height * scaleX) / 2)}px`,
    width: `${Math.round(GLOW.width * scaleX)}px`,
    height: `${Math.round(GLOW.height * scaleX)}px`,
  })
  animate(glow, GLOW_FRAMES, blastTiming)
  twinkles.forEach((twinkle, index) => {
    const [tx, ty] = TWINKLES[index % TWINKLES.length]
    settle(twinkle)
    Object.assign(twinkle.style, { left: x(tx), top: y(ty) })
    animate(twinkle, TWINKLE_FRAMES, blastTiming)
  })
}

export const darkenRow = (layer: HTMLElement | null) =>
  Array.from(layer?.children ?? []).forEach((element) => settle(element))
