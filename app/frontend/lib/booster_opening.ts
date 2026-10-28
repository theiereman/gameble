import { otherReserve, reserveCount } from "./booster_bank"
import { bankChanged, celebrate, completed, idle } from "./booster_state"
import {
  NO_COUNTS,
  allRevealed,
  countsAfterReveal,
  handDone,
  keyAfter,
  planRevealAll,
  topOfPile,
} from "./booster_rules"
import {
  REVEAL_GUARD,
  type BoosterBank,
  type BoosterState,
  type OpeningOutcome,
  type OpeningRefusal,
  type RevealAllStep,
} from "./booster_types"
import type { OpeningAnswer } from "./opening"

export function canOpen(state: BoosterState): boolean {
  if (state.opening || state.revealing.length > 0 || state.revealingAll || state.storing) return false
  if (reserveCount(state.bank, state.reserve) <= 0) return false
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

export function openingRefused(state: BoosterState, result: OpeningRefusal, failed: string): BoosterState {
  const refused = result.kind === "refused"
  const outcome: OpeningOutcome = refused ? { kind: "refused", code: result.code } : { kind: "failed" }
  const emptied = refused && result.code === "no_pack_available"
  const after = emptied ? bankChanged(state, withoutReserve(state)) : state
  const empty = reserveCount(after.bank, after.reserve) <= 0
  return {
    ...after,
    pendingKey: keyFor(state, outcome),
    bankOwed: refused ? false : state.bankOwed,
    armed: false,
    status: empty ? "waiting" : "sealed",
    phase: empty ? "empty" : "sealed",
    reason: refused ? result.message : failed,
    opening: false,
    focus: empty ? "home" : state.focus,
  }
}

function withoutReserve({ bank, reserve }: BoosterState): BoosterBank {
  const standard = reserve === "standard" ? 0 : bank.available
  const special = reserve === "special" ? 0 : bank.special
  return {
    ...bank,
    available: standard,
    special,
    openable: standard + special,
    reserveFull: false,
    nextPackSize: null,
  }
}

function reserveAfterOpening({ bank, reserve }: BoosterState): BoosterState["reserve"] {
  return reserveCount(bank, reserve) === 0 && reserveCount(bank, otherReserve(reserve)) > 0
    ? otherReserve(reserve)
    : reserve
}

export function openingAnswered(state: BoosterState, answer: OpeningAnswer): BoosterState {
  const { available, special, openable, reserveFull, nextSpecialKind, nextAvailableAt, nextPackSize } = answer.bank
  const bank: BoosterBank = {
    available,
    special,
    openable,
    reserveFull,
    nextSpecialKind,
    nextAvailableAt,
    serverTime: answer.serverTime,
    nextPackSize: nextPackSize ?? null,
  }
  const changed = bankChanged(state, bank)
  return {
    ...changed,
    reserve: reserveAfterOpening(changed),
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
  return (
    state.answer !== null && state.phase === "dealt" && !state.revealingAll && !state.legendaryRunning && !state.storing
  )
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
