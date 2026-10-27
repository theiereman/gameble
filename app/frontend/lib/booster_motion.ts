import { RARITIES, type Rarity } from "./card_types"
import { formatNumber, t, type Template } from "./i18n"

export const TIME_SCALE = 1.18

export function scaled(base: number): number {
  return Math.round(base * TIME_SCALE)
}

export const ARM_MS = scaled(320)
export const CAPS_MS = scaled(620)
export const BODY_MS = scaled(150)
export const RAYS_FADE_MS = scaled(220)
export const FLASH_MS = scaled(170)
export const SHAKE_MS = scaled(300)
export const HEAD_DELAY = scaled(60)
export const DEAL_MS = scaled(460)
export const DEAL_STAGGER = scaled(45)
export const LAND_SHAKE_MS = scaled(110)
export const DEAL_LAND_AT = 0.7

export const TREMBLE_MS = [0, 90, 170, 280].map(scaled)
export const LIFT_PX = [0, 8, 16, 26]
export const COMMON_LIFT_MS = scaled(70)
export const COMMON_LIFT_PX = 4
export const FLIP_MS = [0, 1, 2, 3].map((tier) => scaled(300 + 40 * tier))
export const SETTLE_MS = [0, 1, 2, 3].map((tier) => scaled(380 + 60 * tier))
export const RINGS = [0, 1, 1, 2]
export const MARK_AT = 0.42
export const EPIC_SHAKE_MS = scaled(280)
export const EPIC_BANNER_MS = scaled(1100)

export const LEGENDARY_JUMP = scaled(520)
export const SPIN = scaled(560)
export const MARK_IN_SPIN = scaled(90)
export const IMPACT_AT = scaled(420)
export const IMPACT = scaled(760)
export const DROP = scaled(380)
export const LEGENDARY_FLASH_MS = scaled(300)
export const LEGENDARY_SHAKE_MS = scaled(460)
export const LEGENDARY_BANNER_MS = scaled(1500)
export const LEGENDARY_JUMP_PX = 50

export const REVEAL_ALL_GAP = 180
export const SINK = 160
export const SINK_STAGGER = 22
export const SINK_PX = 80
export const DOCK = 260
export const DOCK_PX = 220

export const RM_CANISTER_FADE = 200
export const RM_CARD_FADE = 240
export const RM_FADE_STAGGER = 40
export const RM_REVEAL_FADE = 220
export const RM_LEGENDARY_STILL = 1400

export function bannerDuration({ reduced, large }: { reduced: boolean; large: boolean }): number {
  return reduced ? RM_LEGENDARY_STILL : large ? LEGENDARY_BANNER_MS : EPIC_BANNER_MS
}

export const ART_WAIT_MAX = 6000
export const ART_POLL = 50

export function tierIndex(tier: Rarity): number {
  return RARITIES.indexOf(tier)
}

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

export function revealSummary(tiers: Rarity[], strings: SummaryStrings): string {
  const parts = [...RARITIES]
    .reverse()
    .map((tier) => ({ tier, n: tiers.filter((each) => each === tier).length }))
    .filter(({ n }) => n > 0)
    .map(({ tier, n }) =>
      t(strings.summaryTier, { count: n, rarity: strings.rarityNames[tier], n: formatNumber(n, strings.delimiter) }),
    )
  return t(strings.summary, {
    count: tiers.length,
    n: formatNumber(tiers.length, strings.delimiter),
    tiers: parts.join(", "),
  })
}

export const BURST_PIXELS: Record<Rarity, number> = {
  common: 8,
  uncommon: 12,
  rare: 16,
  epic: 24,
  legendary: 32,
}

export const BURST_STEPS = 4

export function burstPixels(
  tier: Rarity,
  width: number,
  height: number,
): { x: number; y: number; dx: number; dy: number }[] {
  const count = BURST_PIXELS[tier]
  const grid = 2
  const stride = grid * BURST_STEPS
  const snap = (value: number) => Math.round(value / grid) * grid
  return Array.from({ length: count }, (_, index) => {
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

export function pose(x = 0, y = 0, rotate = 0, scaleX = 1, scaleY = scaleX): string {
  const round = (value: number, digits = 2) => Number(value.toFixed(digits))
  return `translate(${round(x, 1)}px, ${round(y, 1)}px) rotate(${round(rotate)}deg) scale(${round(scaleX, 3)}, ${round(scaleY, 3)})`
}

export function dealKeyframes(dx: number, dy: number, rotate: number, rest: PilePose = PILE_REST): Keyframe[] {
  const { y, scale, rotate: tilt } = rest
  return [
    { transform: pose(dx, dy, rotate, 0.2), opacity: 0, easing: "cubic-bezier(.15,.8,.3,1)" },
    {
      transform: pose(dx * 0.2, Math.min(dy * 0.4, 0) - 70, -rotate * 0.3, 1.1),
      opacity: 1,
      offset: 0.42,
      easing: "cubic-bezier(.6,0,.9,.5)",
    },
    {
      transform: pose(0, y + 10, tilt, scale * 1.14, scale * 0.84),
      opacity: 1,
      offset: DEAL_LAND_AT,
      easing: "ease-out",
    },
    { transform: pose(0, y - 6, tilt, scale * 0.95, scale * 1.06), opacity: 1, offset: 0.86, easing: "ease-in-out" },
    { transform: pose(0, y, tilt, scale), opacity: 1 },
  ]
}

export function dealRotation(index: number, count: number): number {
  return (index - Math.floor(count / 2)) * 26
}

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

const CARD_BACKS: readonly string[] = ["standard"]

export function cardBackClass(key: string): string {
  return `booster-card__back--${CARD_BACKS.includes(key) ? key : "standard"}`
}

export type PilePose = { y: number; scale: number; rotate: number }

const PILE_REST: PilePose = { y: 0, scale: 1, rotate: 0 }

export function pilePose(depth: number): PilePose {
  const rotate = depth === 0 ? 0 : (depth % 2 === 1 ? 1.4 : -1.4) * Math.min(depth, 2)
  return { y: 5 * depth, scale: Number((1 - 0.02 * depth).toFixed(3)), rotate }
}

export function pileTransform(depth: number): string {
  const { y, scale, rotate } = pilePose(depth)
  return pose(0, y, rotate, scale)
}

export function pileOrder(count: number): number[] {
  return Array.from({ length: count }, (_, index) => count - 1 - index)
}

export function pileDepth(index: number, stored: readonly boolean[]): number {
  let depth = 0
  for (let position = 0; position < index; position++) if (!stored[position]) depth++
  return depth
}

export const SWIPE_START = 10

export function swipeStores(dx: number, dy: number): boolean {
  return Math.abs(dx) > 64 || dy < -64 || dy > 90
}

export function phoneJump(headroom: number): number {
  return Math.max(0, Math.min(LEGENDARY_JUMP_PX, Math.floor(headroom * 0.6)))
}

export const PHONE_SWELL = 0.25

export function phoneSwell(scale: number): number {
  return Number((1 + (scale - 1) * PHONE_SWELL).toFixed(4))
}

export const PHONE_DEAL_STAGGER = Math.round(DEAL_STAGGER * 1.5)
export const STORE_MS = 260
export const SLOT_POP_MS = 260
export const PLATE_POP_MS = 320
export const PLATE_POP_LEGENDARY_MS = 380
export const SPRING_BACK_MS = 260
export const TRAY_SPARKS = 10

export function phoneAllHold(tier: Rarity): number {
  return tierIndex(tier) >= 3 ? scaled(320) : scaled(150)
}
