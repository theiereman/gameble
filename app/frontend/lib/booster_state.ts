import { atZero, owedBankDue, phaseForBank, reserveCount, type ScreenMoment } from "./booster_bank"
import { handDone, storedAfterRebuild, topOfPile } from "./booster_rules"
import {
  REVEAL_GUARD,
  type BannerAsked,
  type BoosterBank,
  type BoosterStart,
  type BoosterState,
  type FocusTarget,
} from "./booster_types"
import { celebrationResults, restoredCelebration, type CelebrationResult } from "./celebration"

export function start({
  bank,
  reserve,
  opened,
  layout,
  now,
  celebrationRemembered,
  preview,
}: BoosterStart): BoosterState {
  const sealed = reserveCount(bank, reserve) > 0
  const fresh: BoosterState = {
    bank,
    reserve,
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

const moment = (state: BoosterState): ScreenMoment => ({
  phase: state.phase,
  idle: idle(state),
  handPutAway: handDone(state),
})

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
  return reserveCount(state.bank, state.reserve) > 0 ? "open" : "back"
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
  return {
    ...state,
    celebrationPending: null,
    celebration: results,
    celebrationStill: false,
    celebrationAnnounced: false,
    celebrationSteps: 0,
  }
}

export function shownCelebration(state: BoosterState): readonly CelebrationResult[] | null {
  return state.banner === null ? state.celebration : null
}

export function celebrationToAnnounce(state: BoosterState): readonly CelebrationResult[] | null {
  return state.celebrationAnnounced ? null : shownCelebration(state)
}

export function celebrationStepped(state: BoosterState): BoosterState {
  return state.celebration !== null && state.celebration.length > 1
    ? { ...state, celebrationSteps: state.celebrationSteps + 1 }
    : state
}

export function shownResult(state: BoosterState): number {
  const count = state.celebration?.length ?? 0
  return count > 0 ? state.celebrationSteps % count : 0
}

export function celebrationSpoken(state: BoosterState): BoosterState {
  return state.celebrationAnnounced ? state : { ...state, celebrationAnnounced: true }
}

export function completed(state: BoosterState): BoosterState {
  return celebrate({
    ...state,
    status: "complete",
    focus: reserveCount(state.bank, state.reserve) > 0 ? "open" : "back",
  })
}

export function bankChanged(state: BoosterState, bank: BoosterBank): BoosterState {
  return { ...state, bank, bankGeneration: state.bankGeneration + 1 }
}

export function bankFetched(state: BoosterState, bank: BoosterBank, generation: number): BoosterState {
  if (generation !== state.bankGeneration) return state
  const changed = bankChanged(state, bank)
  const phase = phaseForBank(state.phase, reserveCount(bank, state.reserve))
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
