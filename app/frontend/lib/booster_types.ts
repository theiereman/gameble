import type { Rarity } from "./card_types"
import type { CelebrationResult } from "./celebration"
import type { OpeningAnswer, OpeningResult, OpeningSetTier } from "./opening"

export type BoosterPhase = "sealed" | "empty" | "opening" | "dealt"

export type BoosterStatus = "sealed" | "arming" | "ejecting" | "inventory" | "legendarySignal" | "complete" | "waiting"

export type Reserve = "standard" | "special"

export type BoosterBank = {
  available: number
  special: number
  openable: number
  reserveFull: boolean
  nextSpecialKind: string | null
  nextAvailableAt: string | null
  serverTime: string
  nextPackSize: number | null
}

export const REVEAL_GUARD = 400

export const CLICK_AFTER_DRAG = 300

export type Layout = "phone" | "narrow" | "wide"

export const PHONE_QUERY = "(max-width: 719px)"

export const NARROW_QUERY = "(max-width: 899px)"

export type RevealAllStep = { index: number; wait: "full" | "gap" }

export type OpeningOutcome = { kind: "opened" } | { kind: "refused"; code: string } | { kind: "failed" }

export type TierCounts = Record<Rarity, number>

export type Focus = "open" | "back" | "card" | { slot: number }

export type FocusTarget = "open" | "back" | { card: number } | { slot: number }

export type Banner = { key: number; tier: Rarity; large: boolean; line: string | null; reduced: boolean }

export type BannerAsked = Omit<Banner, "key">

export type BoosterState = Readonly<{
  bank: BoosterBank
  reserve: Reserve
  bankGeneration: number
  bankOwed: boolean
  phase: BoosterPhase
  status: BoosterStatus
  opening: boolean
  pendingKey: string | null
  answer: OpeningAnswer | null
  revealed: readonly boolean[]
  revealedAt: readonly (number | undefined)[]
  revealing: readonly number[]
  legendary: number | null
  legendaryRunning: boolean
  revealingAll: boolean
  storing: boolean
  stored: readonly boolean[]
  counts: TierCounts | null
  dealt: boolean
  armed: boolean
  headShown: boolean
  canisterAway: boolean
  docks: number
  reason: string | null
  banner: Banner | null
  bannerKey: number
  layout: Layout
  pendingLayout: Layout | null
  rebuilds: number
  zoom: number | null
  celebrationPending: readonly OpeningSetTier[] | null
  celebration: readonly CelebrationResult[] | null
  celebrationStill: boolean
  celebrationAnnounced: boolean
  celebrationSteps: number
  lockDepth: number
  focus: Focus | null
}>

export type BoosterStart = {
  bank: BoosterBank
  reserve: Reserve
  opened: OpeningAnswer | null
  layout: Layout
  now: number
  celebrationRemembered: boolean
  preview: boolean
}

export type OpeningRefusal = Exclude<OpeningResult, { kind: "opened" }>

export type Activation = "reveal" | "store" | "leave" | "none"

export type OpenVariant = "open" | "next" | "empty"

export type StatusTone = "alert" | "gold" | "done" | "rest"

export type Hint = { kind: "remaining" | "done"; count: number } | { kind: "tap" | "swipe" }

export type Controls = Readonly<{
  open: OpenVariant
  openDisabled: boolean
  busy: boolean
  locked: boolean
  revealAllDisabled: boolean
  tone: StatusTone
  hint: Hint | null
  storedCount: number
  top: number | null
  plate: number | null
  zoomPrevious: boolean
  zoomNext: boolean
}>
