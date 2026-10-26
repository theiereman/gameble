// The booster island's timing and motion. Pure: no DOM, no React. Every
// duration of the opening and the reveal lives here: the opening, reveal
// and Légendaire ones multiplied by TIME_SCALE; the others, the
// reduced-motion ones included (RM_*), unscaled.
import { RARITIES, type Rarity } from "./card_types"
import { formatNumber, t, type Template } from "./i18n"

/** The opening and reveal timings, slowed by 18 %. */
export const TIME_SCALE = 1.18

/** A base duration, scaled and rounded to the millisecond. */
export function scaled(base: number): number {
  return Math.round(base * TIME_SCALE)
}

// ---- Opening ----

/** ARMEMENT: the canister's squash while the request runs. */
export const ARM_MS = scaled(320)
/** The caps blowing off. */
export const CAPS_MS = scaled(620)
/** The body popping and fading. */
export const BODY_MS = scaled(150)
/** The canister's rays fading. */
export const RAYS_FADE_MS = scaled(220)
/** The opening's warm flash. */
export const FLASH_MS = scaled(170)
/** The opening's shake. */
export const SHAKE_MS = scaled(300)
/** From the blast to the result head and the deal. */
export const HEAD_DELAY = scaled(60)
/** One card's flight from the canister to its slot. */
export const DEAL_MS = scaled(460)
/** Between two cards leaving the canister. */
export const DEAL_STAGGER = scaled(45)
/** A card's landing shake. */
export const LAND_SHAKE_MS = scaled(110)
/** Where in its flight a card lands. */
export const DEAL_LAND_AT = 0.7

// ---- Reveal, per tier from common (0) to epic (3) ----

/** The tremble before the flip. */
export const TREMBLE_MS = [0, 90, 170, 280].map(scaled)
/** How high the card lifts while it trembles, in px. */
export const LIFT_PX = [0, 8, 16, 26]
/** A common card's small lift instead of a tremble. */
export const COMMON_LIFT_MS = scaled(70)
export const COMMON_LIFT_PX = 4
/** The flip, longer as the tier rises. */
export const FLIP_MS = [0, 1, 2, 3].map((tier) => scaled(300 + 40 * tier))
/** The settle after the flip. */
export const SETTLE_MS = [0, 1, 2, 3].map((tier) => scaled(380 + 60 * tier))
/** Rings around the burst. */
export const RINGS = [0, 1, 1, 2]
/** Where in its flip a card shows what it is. */
export const MARK_AT = 0.42
/** The epic's shake. */
export const EPIC_SHAKE_MS = scaled(280)
/** The epic's small banner. */
export const EPIC_BANNER_MS = scaled(1100)

// ---- Légendaire ----

/** The jump up and the charge. */
export const LEGENDARY_JUMP = scaled(520)
/** The one-and-a-half spin. */
export const SPIN = scaled(560)
/** From the spin's start to the mark. */
export const MARK_IN_SPIN = scaled(90)
/** From the spin's start to the impact. */
export const IMPACT_AT = scaled(420)
/** The impact's hold, from the impact to the drop. */
export const IMPACT = scaled(760)
/** The drop back with a bounce. */
export const DROP = scaled(380)
/** The impact's flash and shake. */
export const LEGENDARY_FLASH_MS = scaled(300)
export const LEGENDARY_SHAKE_MS = scaled(460)
/** The large banner. */
export const LEGENDARY_BANNER_MS = scaled(1500)
/** How high the card jumps, in px. */
export const LEGENDARY_JUMP_PX = 50

// ---- Unscaled ----

/** Tout révéler: between two cards. */
export const REVEAL_ALL_GAP = 180
/** Next booster: the cards sink and fade. */
export const SINK = 160
export const SINK_STAGGER = 22
export const SINK_PX = 80
/** Next booster: a new canister rises into place. */
export const DOCK = 260
export const DOCK_PX = 220

// ---- Reduced motion ----

export const RM_CANISTER_FADE = 200
export const RM_CARD_FADE = 240
export const RM_FADE_STAGGER = 40
export const RM_REVEAL_FADE = 220
export const RM_LEGENDARY_STILL = 1400

/** The longest wait for a card's art before it flips anyway. */
export const ART_WAIT_MAX = 6000
/** How often the art is looked at while waiting. */
export const ART_POLL = 50

/** A tier's place, from 0 (common) to 4 (legendary). */
export function tierIndex(tier: Rarity): number {
  return RARITIES.indexOf(tier)
}

/** The order cards leave the canister: centre out (5: 2, 1, 3, 0, 4). */
export function dealOrder(count: number): number[] {
  const centre = Math.floor(count / 2)
  const order = count > 0 ? [centre] : []
  for (let step = 1; order.length < count; step++) {
    if (centre - step >= 0) order.push(centre - step)
    if (centre + step < count) order.push(centre + step)
  }
  return order
}

export type SummaryStrings = {
  summary: Template
  summaryTier: Template
  rarityNames: Record<Rarity, string>
  delimiter: string
}

/** Tout révéler's one announcement: "3 cartes révélées : Légendaire × 1, Commune × 2.", rarest first. */
export function revealSummary(tiers: Rarity[], strings: SummaryStrings): string {
  const parts = [...RARITIES]
    .reverse()
    .map((tier) => ({ tier, n: tiers.filter((each) => each === tier).length }))
    .filter(({ n }) => n > 0)
    .map(({ tier, n }) => t(strings.summaryTier, { count: n, rarity: strings.rarityNames[tier], n: formatNumber(n, strings.delimiter) }))
  return t(strings.summary, { count: tiers.length, n: formatNumber(tiers.length, strings.delimiter), tiers: parts.join(", ") })
}

/** Burst: how many pixels fly off a card, by tier. */
export const BURST_PIXELS: Record<Rarity, number> = {
  common: 8,
  uncommon: 12,
  rare: 16,
  epic: 24,
  legendary: 32,
}

/** The steps of the burst's flight: each step lands on the 2 px grid. */
export const BURST_STEPS = 4

/**
 * The burst's pixels for a card: fixed offsets (the same on every
 * reveal), whole multiples of the grid at each step, flying outwards from
 * spots spread over the card. In CSS pixels, from the card's top left
 * corner.
 */
export function burstPixels(tier: Rarity, width: number, height: number): { x: number; y: number; dx: number; dy: number }[] {
  const count = BURST_PIXELS[tier]
  const grid = 2
  const stride = grid * BURST_STEPS
  const snap = (value: number) => Math.round(value / grid) * grid
  return Array.from({ length: count }, (_, index) => {
    // The golden angle spreads the pixels evenly around the card.
    const angle = index * 2.399963
    const ring = 0.25 + 0.2 * (index % 3)
    const x = snap(width / 2 + Math.cos(angle) * width * ring)
    const y = snap(height / 2 + Math.sin(angle) * height * ring)
    const reach = 2 + (index % 4)
    const dx = Math.round(Math.cos(angle) * reach) * stride
    const dy = Math.round(Math.sin(angle) * reach) * stride
    return { x, y, dx, dy }
  })
}

/** A transform: translate, rotate, scale. */
export function pose(x = 0, y = 0, rotate = 0, scaleX = 1, scaleY = scaleX): string {
  const round = (value: number, digits = 2) => Number(value.toFixed(digits))
  return `translate(${round(x, 1)}px, ${round(y, 1)}px) rotate(${round(rotate)}deg) scale(${round(scaleX, 3)}, ${round(scaleY, 3)})`
}

/**
 * A card's flight: from `dx`, `dy` (the canister's centre,
 * relative to its slot) up in an arc, squashing as it lands, to its rest
 * pose: none in the row, its place in the pile on the phone (pilePose), so
 * the flight ends where the stylesheet holds the card and nothing snaps.
 */
export function dealKeyframes(dx: number, dy: number, rotate: number, rest: PilePose = PILE_REST): Keyframe[] {
  const { y, scale, rotate: tilt } = rest
  return [
    { transform: pose(dx, dy, rotate, 0.2), opacity: 0, easing: "cubic-bezier(.15,.8,.3,1)" },
    { transform: pose(dx * 0.2, Math.min(dy * 0.4, 0) - 70, -rotate * 0.3, 1.1), opacity: 1, offset: 0.42, easing: "cubic-bezier(.6,0,.9,.5)" },
    { transform: pose(0, y + 10, tilt, scale * 1.14, scale * 0.84), opacity: 1, offset: DEAL_LAND_AT, easing: "ease-out" },
    { transform: pose(0, y - 6, tilt, scale * 0.95, scale * 1.06), opacity: 1, offset: 0.86, easing: "ease-in-out" },
    { transform: pose(0, y, tilt, scale), opacity: 1 },
  ]
}

/** The rotation a card leaves the canister with: fanned from the centre. */
export function dealRotation(index: number, count: number): number {
  return (index - Math.floor(count / 2)) * 26
}

/** A shake of `amplitude` px decaying over 8 steps, alternating sides. */
export function shakeKeyframes(amplitude: number): Keyframe[] {
  const steps = 8
  const frames: Keyframe[] = []
  for (let step = 0; step < steps; step++) {
    const reach = amplitude * (1 - step / steps) ** 2
    const side = step % 2 === 0 ? 1 : -1
    frames.push({ transform: `translate(${(side * reach).toFixed(1)}px, ${(-side * reach * 0.6).toFixed(1)}px)` })
  }
  frames.push({ transform: "translate(0px, 0px)" })
  return frames
}

/** The card backs the island draws; an unknown key shows the standard one. */
const CARD_BACKS: readonly string[] = ["standard"]

/** The class of a card's back for the answer's `pack.cardBack` key. */
export function cardBackClass(key: string): string {
  return `booster-card__back--${CARD_BACKS.includes(key) ? key : "standard"}`
}

// ---- The phone's pile ----

/** A card's place in the pile: lower, smaller and tilted a little more as it lies deeper. */
export type PilePose = { y: number; scale: number; rotate: number }

const PILE_REST: PilePose = { y: 0, scale: 1, rotate: 0 }

/**
 * The pose of the card `depth` cards under the top (5px offsets, ±1.4°
 * tilt): 5px lower and 2 % smaller per card, tilted one way then the
 * other, 2.8° at most. The top card (0) lies flat.
 */
export function pilePose(depth: number): PilePose {
  const rotate = depth === 0 ? 0 : (depth % 2 === 1 ? 1.4 : -1.4) * Math.min(depth, 2)
  return { y: 5 * depth, scale: Number((1 - 0.02 * depth).toFixed(3)), rotate }
}

/** The pose as a transform. */
export function pileTransform(depth: number): string {
  const { y, scale, rotate } = pilePose(depth)
  return pose(0, y, rotate, scale)
}

/** The order cards land in the pile: the bottom card first (5: 4, 3, 2, 1, 0), the first card on top. */
export function pileOrder(count: number): number[] {
  return Array.from({ length: count }, (_, index) => count - 1 - index)
}

/** How deep a card lies: the cards above it in the pile (those before it, not stored). */
export function pileDepth(index: number, stored: readonly boolean[]): number {
  let depth = 0
  for (let position = 0; position < index; position++) if (!stored[position]) depth++
  return depth
}

/** How far, in px, a finger travels on a revealed card before it drags it. */
export const SWIPE_START = 10

/**
 * A revealed card let go after a drag of `dx`, `dy` px: stored in the tray
 * for a long enough move sideways, up, or down toward the tray; otherwise
 * it springs back.
 */
export function swipeStores(dx: number, dy: number): boolean {
  return Math.abs(dx) > 64 || dy < -64 || dy > 90
}

/** The Légendaire's jump on the phone: 60 % of the room above the card, 50px at most, never out of the stage. */
export function phoneJump(headroom: number): number {
  return Math.max(0, Math.min(LEGENDARY_JUMP_PX, Math.floor(headroom * 0.6)))
}

/** The share of the reveal's swell (its scale) the phone keeps. */
export const PHONE_SWELL = 0.25

/**
 * A reveal's scale on the phone: a quarter of its swell, so the card-xl
 * card, 8px above the caption plate, never grows over it and stays inside
 * the stage.
 */
export function phoneSwell(scale: number): number {
  return Number((1 + (scale - 1) * PHONE_SWELL).toFixed(4))
}

// ---- The phone's timings ----

/** Cards landing in the pile: 1.5 times the row's stagger. */
export const PHONE_DEAL_STAGGER = Math.round(DEAL_STAGGER * 1.5)
/** A stored card shrinking into its slot. */
export const STORE_MS = 260
/** The slot popping as it receives the card. */
export const SLOT_POP_MS = 260
/** The caption plate popping in; longer for a Légendaire. */
export const PLATE_POP_MS = 320
export const PLATE_POP_LEGENDARY_MS = 380
/** A short drag let go: the card springs back. */
export const SPRING_BACK_MS = 260
/** Sparks at the slot of a stored Épique or better. */
export const TRAY_SPARKS = 10

/** Tout révéler on the phone: how long a revealed card shows before it is stored. */
export function phoneAllHold(tier: Rarity): number {
  return tierIndex(tier) >= 3 ? scaled(320) : scaled(150)
}
