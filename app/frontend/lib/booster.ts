import { atZero, handPutAway, owedBankDue, phaseForBank, type ScreenMoment } from "./booster_bank"
import type { Rarity } from "./card_types"
import { celebrationResults, restoredCelebration, type CelebrationResult } from "./celebration"
import type { OpeningAnswer, OpeningResult, OpeningSetTier } from "./opening"

export type BoosterPhase = "sealed" | "empty" | "opening" | "dealt"

export type BoosterStatus = "sealed" | "arming" | "ejecting" | "inventory" | "legendarySignal" | "complete" | "waiting"

export type BoosterBank = {
  available: number
  reserveFull: boolean
  nextAvailableAt: string | null
  serverTime: string
  nextPackSize: number | null
}

export const REVEAL_GUARD = 400

export const CLICK_AFTER_DRAG = 300

export type Layout = "phone" | "narrow" | "wide"

export const PHONE_QUERY = "(max-width: 719px)"

export const NARROW_QUERY = "(max-width: 899px)"

export function layoutFor(phone: boolean, narrow: boolean): Layout {
  return phone ? "phone" : narrow ? "narrow" : "wide"
}

export function faceSize(layout: Layout): "xl" | "s" | "m" {
  return layout === "phone" ? "xl" : layout === "narrow" ? "s" : "m"
}

const REVEALING_STATUSES: readonly BoosterStatus[] = ["arming", "ejecting", "inventory", "legendarySignal"]

export function revealingOpening(status: BoosterStatus): boolean {
  return REVEALING_STATUSES.includes(status)
}

export type RevealAllStep = { index: number; wait: "full" | "gap" }

export function planRevealAll(tiers: readonly Rarity[], revealed: readonly boolean[]): RevealAllStep[] {
  return tiers.flatMap((tier, index) => (revealed[index] ? [] : [{ index, wait: tier === "legendary" ? "full" : "gap" } as const]))
}

export type OpeningOutcome = { kind: "opened" } | { kind: "refused"; code: string } | { kind: "failed" }

export function keyAfter(outcome: OpeningOutcome, key: string): string | null {
  if (outcome.kind === "failed") return key
  if (outcome.kind === "refused" && outcome.code === "throttled") return key
  return null
}

export type TierCounts = Record<Rarity, number>

const NO_COUNTS: TierCounts = { common: 0, uncommon: 0, rare: 0, epic: 0, legendary: 0 }

export function countsAfterReveal(counts: TierCounts, tier: Rarity): TierCounts {
  return { ...counts, [tier]: counts[tier] + 1 }
}

export function topOfPile(revealed: readonly boolean[], stored: readonly boolean[]): number | null {
  const index = revealed.findIndex((_, position) => !stored[position])
  return index === -1 ? null : index
}

export function zoomNeighbour(stored: readonly boolean[], index: number, step: -1 | 1): number | null {
  for (let position = index + step; position >= 0 && position < stored.length; position += step) {
    if (stored[position]) return position
  }
  return null
}

export function storedAfterRebuild(revealed: readonly boolean[], stored: readonly boolean[], layout: Layout): boolean[] {
  return layout === "phone" ? revealed.map((shown, index) => shown || (stored[index] ?? false)) : revealed.map(() => false)
}

export type Focus = "open" | "back" | "card" | { slot: number }

export type FocusTarget = "open" | "back" | { card: number } | { slot: number }

export type Banner = { key: number; tier: Rarity; large: boolean; line: string | null; reduced: boolean }

export type BannerAsked = Omit<Banner, "key">

export type BoosterState = Readonly<{
  bank: BoosterBank
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
  opened: OpeningAnswer | null
  layout: Layout
  now: number
  celebrationRemembered: boolean
  preview: boolean
}

export function start({ bank, opened, layout, now, celebrationRemembered, preview }: BoosterStart): BoosterState {
  const sealed = bank.available > 0
  const fresh: BoosterState = {
    bank,
    bankGeneration: 0,
    bankOwed: false,
    phase: sealed ? "sealed" : "empty",
    status: sealed ? "sealed" : "waiting",
    opening: false,
    pendingKey: null,
    answer: null,
    revealed: [],
    revealedAt: [],
    revealing: [],
    legendary: null,
    legendaryRunning: false,
    revealingAll: false,
    storing: false,
    stored: [],
    counts: null,
    dealt: false,
    armed: false,
    headShown: false,
    canisterAway: false,
    docks: 0,
    reason: null,
    banner: null,
    bannerKey: 0,
    layout,
    pendingLayout: null,
    rebuilds: 0,
    zoom: null,
    celebrationPending: null,
    celebration: null,
    celebrationStill: false,
    celebrationAnnounced: false,
    celebrationSteps: 0,
    lockDepth: 0,
    focus: preview ? null : sealed ? "open" : "back",
  }
  if (!opened) return fresh
  const revealed = opened.cards.map(() => true)
  const celebration = restoredCelebration(opened.setTiers, celebrationRemembered)
  return {
    ...fresh,
    phase: "dealt",
    status: "complete",
    answer: opened,
    revealed,
    revealedAt: opened.cards.map(() => now - REVEAL_GUARD),
    stored: storedAfterRebuild(revealed, [], layout),
    dealt: true,
    headShown: true,
    canisterAway: true,
    celebration,
    celebrationStill: celebration !== null,
    celebrationAnnounced: celebration !== null,
  }
}

export function idle(state: BoosterState): boolean {
  return (
    !state.opening &&
    state.revealing.length === 0 &&
    !state.revealingAll &&
    !state.storing &&
    state.lockDepth === 0 &&
    state.phase !== "opening"
  )
}

const allRevealed = (state: BoosterState): boolean => state.revealed.length > 0 && state.revealed.every(Boolean)

const handDone = (state: BoosterState): boolean => handPutAway(state.layout, state.revealed, state.stored)

const moment = (state: BoosterState): ScreenMoment => ({ phase: state.phase, idle: idle(state), handPutAway: handDone(state) })

export function lock(state: BoosterState): BoosterState {
  return { ...state, lockDepth: state.lockDepth + 1 }
}

export function unlock(state: BoosterState): BoosterState {
  return state.lockDepth === 0 ? state : { ...state, lockDepth: state.lockDepth - 1 }
}

export function lockReleased(state: BoosterState): BoosterState {
  return state.lockDepth === 0 ? state : { ...state, lockDepth: 0 }
}

export function locked(state: BoosterState): boolean {
  return state.lockDepth > 0
}

function cardToFocus(state: BoosterState): number | null {
  if (state.phase !== "dealt" || !state.answer) return null
  if (state.layout === "phone") return topOfPile(state.revealed, state.stored)
  const index = state.revealed.findIndex((shown) => !shown)
  return index === -1 ? null : index
}

export function focusTarget(state: BoosterState): FocusTarget | null {
  const { focus } = state
  if (focus === null) return null
  if (typeof focus === "object" || focus === "open" || focus === "back") return focus
  const index = cardToFocus(state)
  if (index !== null) return { card: index }
  return state.bank.available > 0 ? "open" : "back"
}

export function focusGiven(state: BoosterState): BoosterState {
  return state.focus === null ? state : { ...state, focus: null }
}

export function bannerShown(state: BoosterState, banner: BannerAsked): BoosterState {
  if (state.layout === "phone") return state
  const key = state.bannerKey + 1
  return { ...state, bannerKey: key, banner: { key, ...banner } }
}

export function bannerEnded(state: BoosterState, key: number): BoosterState {
  return state.banner?.key === key ? { ...state, banner: null } : state
}

export function celebrate(state: BoosterState): BoosterState {
  const reached = state.celebrationPending
  if (reached === null) return state
  const results = celebrationResults(reached)
  if (results.length === 0) return { ...state, celebrationPending: null }
  return { ...state, celebrationPending: null, celebration: results, celebrationStill: false, celebrationAnnounced: false, celebrationSteps: 0 }
}

export function shownCelebration(state: BoosterState): readonly CelebrationResult[] | null {
  return state.banner === null ? state.celebration : null
}

export function celebrationToAnnounce(state: BoosterState): readonly CelebrationResult[] | null {
  return state.celebrationAnnounced ? null : shownCelebration(state)
}

export function celebrationStepped(state: BoosterState): BoosterState {
  return state.celebration !== null && state.celebration.length > 1 ? { ...state, celebrationSteps: state.celebrationSteps + 1 } : state
}

export function shownResult(state: BoosterState): number {
  const count = state.celebration?.length ?? 0
  return count > 0 ? state.celebrationSteps % count : 0
}

export function celebrationSpoken(state: BoosterState): BoosterState {
  return state.celebrationAnnounced ? state : { ...state, celebrationAnnounced: true }
}

function completed(state: BoosterState): BoosterState {
  return celebrate({ ...state, status: "complete", focus: state.bank.available > 0 ? "open" : "back" })
}

export function bankChanged(state: BoosterState, bank: BoosterBank): BoosterState {
  return { ...state, bank, bankGeneration: state.bankGeneration + 1 }
}

export function bankFetched(state: BoosterState, bank: BoosterBank, generation: number): BoosterState {
  if (generation !== state.bankGeneration) return state
  const changed = bankChanged(state, bank)
  const phase = phaseForBank(state.phase, bank.available)
  if (phase === state.phase) return changed
  return { ...changed, phase, status: phase === "sealed" ? "sealed" : "waiting", reason: null }
}

export function countdownAtZero(state: BoosterState): "page" | "bank" | "owe" {
  return atZero(moment(state))
}

export function bankFetchOwed(state: BoosterState): BoosterState {
  return state.bankOwed ? state : { ...state, bankOwed: true }
}

export function bankDue(state: BoosterState): boolean {
  return state.bankOwed && owedBankDue(moment(state))
}

export function owedBankTaken(state: BoosterState): BoosterState {
  return state.bankOwed ? { ...state, bankOwed: false } : state
}

export function canOpen(state: BoosterState): boolean {
  if (state.opening || state.revealing.length > 0 || state.revealingAll || state.storing) return false
  if (state.bank.available <= 0) return false
  if (state.phase === "dealt") return state.revealed.every(Boolean)
  return state.phase === "sealed"
}

export function openingStarted(state: BoosterState): BoosterState {
  if (!canOpen(state)) return state
  return { ...state, opening: true, reason: null, celebrationPending: null, celebration: null, celebrationSteps: 0 }
}

export function retracting(state: BoosterState): BoosterState {
  return state.headShown ? { ...state, headShown: false } : state
}

export function retracted(state: BoosterState): BoosterState {
  return {
    ...state,
    answer: null,
    revealed: [],
    revealedAt: [],
    stored: [],
    dealt: false,
    armed: false,
    celebration: null,
    canisterAway: false,
    status: "sealed",
    docks: state.docks + 1,
  }
}

export function arming(state: BoosterState, freshKey: string): BoosterState {
  return { ...state, phase: "opening", status: "arming", pendingKey: state.pendingKey ?? freshKey }
}

const keyFor = (state: BoosterState, outcome: OpeningOutcome): string | null =>
  state.pendingKey === null ? null : keyAfter(outcome, state.pendingKey)

export type OpeningRefusal = Exclude<OpeningResult, { kind: "opened" }>

export function openingRefused(state: BoosterState, result: OpeningRefusal, failed: string): BoosterState {
  const refused = result.kind === "refused"
  const outcome: OpeningOutcome = refused ? { kind: "refused", code: result.code } : { kind: "failed" }
  const emptied = refused && result.code === "no_pack_available"
  const after = emptied ? bankChanged(state, { ...state.bank, available: 0, reserveFull: false, nextPackSize: null }) : state
  const empty = after.bank.available <= 0
  return {
    ...after,
    pendingKey: keyFor(state, outcome),
    bankOwed: refused ? false : state.bankOwed,
    armed: false,
    status: empty ? "waiting" : "sealed",
    phase: empty ? "empty" : "sealed",
    reason: refused ? result.message : failed,
    opening: false,
    focus: empty ? "back" : state.focus,
  }
}

export function openingAnswered(state: BoosterState, answer: OpeningAnswer): BoosterState {
  const { available, reserveFull, nextAvailableAt, nextPackSize } = answer.bank
  const bank: BoosterBank = { available, reserveFull, nextAvailableAt, serverTime: answer.serverTime, nextPackSize: nextPackSize ?? null }
  return {
    ...bankChanged(state, bank),
    pendingKey: keyFor(state, { kind: "opened" }),
    counts: { ...answer.tierCountsBefore },
    celebrationPending: answer.setTiers,
    answer,
    revealed: answer.cards.map(() => false),
    revealedAt: answer.cards.map(() => undefined),
    stored: answer.cards.map(() => false),
  }
}

export function ejecting(state: BoosterState): BoosterState {
  return { ...state, armed: true, status: "ejecting" }
}

export function resultHeadShown(state: BoosterState): BoosterState {
  return state.headShown ? state : { ...state, headShown: true }
}

export function cardsDealt(state: BoosterState): BoosterState {
  return state.dealt ? state : { ...state, dealt: true }
}

export function openingEnded(state: BoosterState): BoosterState {
  return { ...state, canisterAway: true, status: "inventory", phase: "dealt", opening: false, focus: "card" }
}

export function canReveal(state: BoosterState, index: number, fromAll: boolean): boolean {
  if (!state.answer?.cards[index] || state.phase !== "dealt") return false
  if (state.revealed[index] || state.revealing.includes(index)) return false
  return fromAll || (!state.revealingAll && !state.legendaryRunning)
}

export function revealStarted(state: BoosterState, index: number, fromAll: boolean): BoosterState {
  if (!canReveal(state, index, fromAll)) return state
  const legendary = state.answer?.cards[index].tier === "legendary"
  return { ...state, revealing: [...state.revealing, index], legendaryRunning: state.legendaryRunning || legendary }
}

export function revealMarked(state: BoosterState, index: number, now: number): BoosterState {
  const card = state.answer?.cards[index]
  if (!card || state.revealed[index]) return state
  return {
    ...state,
    revealed: state.revealed.map((shown, position) => shown || position === index),
    revealedAt: state.revealedAt.map((at, position) => (position === index ? now : at)),
    counts: countsAfterReveal(state.counts ?? NO_COUNTS, card.tier),
  }
}

export function legendarySignalled(state: BoosterState, shown: number | null): BoosterState {
  return { ...state, status: "legendarySignal", legendaryRunning: true, legendary: shown }
}

export function legendaryEnded(state: BoosterState): BoosterState {
  return { ...state, status: "inventory", legendaryRunning: false, legendary: null }
}

export function revealEnded(state: BoosterState, index: number, fromAll: boolean): BoosterState {
  const next = { ...state, revealing: state.revealing.filter((position) => position !== index) }
  const handComplete = !fromAll && next.layout !== "phone" && next.revealing.length === 0 && allRevealed(next)
  return handComplete ? completed(next) : next
}

export function canRevealAll(state: BoosterState): boolean {
  return state.answer !== null && state.phase === "dealt" && !state.revealingAll && !state.legendaryRunning && !state.storing
}

export function revealAllPlan(state: BoosterState): RevealAllStep[] {
  if (!state.answer) return []
  const covered = state.revealed.map((shown, index) => shown || state.revealing.includes(index))
  return planRevealAll(
    state.answer.cards.map((card) => card.tier),
    covered,
  )
}

export function revealAllStarted(state: BoosterState): BoosterState {
  return canRevealAll(state) ? { ...state, revealingAll: true } : state
}

export function revealAllEnded(state: BoosterState): BoosterState {
  const next = { ...state, revealingAll: false }
  return handDone(next) ? completed(next) : next
}

export function canStore(state: BoosterState, index: number, fromAll: boolean, now: number): boolean {
  if (state.layout !== "phone" || state.phase !== "dealt" || !state.answer?.cards[index]) return false
  if (!state.revealed[index] || state.stored[index] || state.storing) return false
  if (topOfPile(state.revealed, state.stored) !== index) return false
  if (fromAll) return true
  if (state.lockDepth > 0 || state.opening || state.revealingAll || state.revealing.length > 0) return false
  const at = state.revealedAt[index]
  return at !== undefined && now - at >= REVEAL_GUARD
}

export function storeStarted(state: BoosterState, index: number, fromAll: boolean, now: number): BoosterState {
  return canStore(state, index, fromAll, now) ? { ...state, storing: true } : state
}

export function cardStored(state: BoosterState, index: number): BoosterState {
  if (state.stored[index] !== false) return state
  return { ...state, stored: state.stored.map((done, position) => done || position === index) }
}

export function storeEnded(state: BoosterState, fromAll: boolean): BoosterState {
  const next = { ...state, storing: false }
  if (fromAll) return next
  return next.stored.every(Boolean) ? completed(next) : { ...next, focus: "card" }
}

export function layoutAsked(state: BoosterState, layout: Layout): BoosterState {
  return state.pendingLayout === layout ? state : { ...state, pendingLayout: layout }
}

export function layoutApplied(state: BoosterState, focusedInside: boolean): BoosterState {
  const next = state.pendingLayout
  if (next === null || !idle(state)) return state
  if (next === state.layout) return { ...state, pendingLayout: null }
  const rebuilt: BoosterState = {
    ...state,
    pendingLayout: null,
    layout: next,
    stored: storedAfterRebuild(state.revealed, state.stored, next),
    rebuilds: state.rebuilds + 1,
    celebrationSteps: 0,
    zoom: null,
    banner: null,
    focus: focusedInside ? "card" : state.focus,
  }
  return state.phase === "dealt" && allRevealed(state) ? celebrate({ ...rebuilt, status: "complete" }) : rebuilt
}

export function zoomOpened(state: BoosterState, index: number): BoosterState {
  if (!idle(state) || !state.stored[index] || state.zoom === index) return state
  return { ...state, zoom: index }
}

export function zoomClosed(state: BoosterState): BoosterState {
  return { ...state, zoom: null, focus: state.zoom === null ? "card" : { slot: state.zoom } }
}

export function zoomStepped(state: BoosterState, step: -1 | 1): BoosterState {
  if (state.zoom === null) return state
  const next = zoomNeighbour(state.stored, state.zoom, step)
  return next === null ? state : { ...state, zoom: next }
}

export type Activation = "reveal" | "store" | "leave" | "none"

export function activation(state: BoosterState, index: number, now: number, lastDragEnd = -Infinity): Activation {
  if (!state.answer?.cards[index]) return "none"
  if (!state.revealed[index]) return "reveal"
  if (state.layout === "phone") return now - lastDragEnd >= CLICK_AFTER_DRAG ? "store" : "none"
  if (locked(state) || state.opening || state.revealingAll || state.revealing.includes(index)) return "none"
  const at = state.revealedAt[index]
  return at !== undefined && now - at >= REVEAL_GUARD ? "leave" : "none"
}

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

function toneOf(status: BoosterStatus): StatusTone {
  if (status === "arming" || status === "ejecting") return "alert"
  if (status === "legendarySignal") return "gold"
  return status === "complete" ? "done" : "rest"
}

function hintOf(state: BoosterState, total: number, revealedCount: number, top: number | null): Hint {
  if (state.layout === "phone") {
    if (top === null) return { kind: "done", count: total }
    return { kind: state.revealed[top] ? "swipe" : "tap" }
  }
  const remaining = total - revealedCount
  return remaining > 0 ? { kind: "remaining", count: remaining } : { kind: "done", count: total }
}

export function controls(state: BoosterState): Controls {
  const total = state.answer?.cards.length ?? 0
  const revealedCount = state.revealed.filter(Boolean).length
  const everyRevealed = total > 0 && revealedCount === total
  const handOnTable = state.phase === "dealt" && total > 0
  const reserveEmpty = state.bank.available <= 0 && state.phase !== "opening"
  const top = handOnTable ? topOfPile(state.revealed, state.stored) : null
  const isLocked = locked(state)
  const { zoom } = state
  return {
    open: reserveEmpty ? "empty" : state.phase === "dealt" ? "next" : "open",
    openDisabled: reserveEmpty || (state.phase === "dealt" && !everyRevealed),
    busy: state.phase === "opening" || state.revealingAll || isLocked || state.storing,
    locked: isLocked,
    revealAllDisabled: !handOnTable || everyRevealed || state.revealingAll || state.storing || state.legendary !== null,
    tone: toneOf(state.status),
    hint: handOnTable ? hintOf(state, total, revealedCount, top) : null,
    storedCount: state.stored.filter(Boolean).length,
    top,
    plate: state.layout === "phone" && top !== null && state.revealed[top] ? top : null,
    zoomPrevious: zoom !== null && zoomNeighbour(state.stored, zoom, -1) !== null,
    zoomNext: zoom !== null && zoomNeighbour(state.stored, zoom, 1) !== null,
  }
}
