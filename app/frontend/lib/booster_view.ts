import { reserveCount } from "./booster_bank"
import { allRevealed, handDone, storedAfterRebuild, topOfPile, zoomNeighbour } from "./booster_rules"
import { celebrate, idle, locked } from "./booster_state"
import {
  CLICK_AFTER_DRAG,
  REVEAL_GUARD,
  type Activation,
  type BoosterState,
  type Controls,
  type Hint,
  type Layout,
  type OpenVariant,
} from "./booster_types"

export const nextCapsuleSize = ({ bank, reserve }: BoosterState): number | null =>
  reserve === "special" ? bank.nextSpecialSize : bank.nextPackSize

export function originKind(state: BoosterState): string | null {
  if (state.reserve !== "special") return null
  const showsHand = state.phase === "dealt" && !nextCapsuleWaiting(state)
  return (showsHand ? state.answer?.pack.kind : state.bank.nextSpecialKind) || null
}

export const onTable = (state: BoosterState): boolean =>
  state.layout === "phone" && state.dealt && (state.answer?.cards.length ?? 0) > 0

export const nextCapsuleWaiting = (state: BoosterState): boolean =>
  state.layout === "phone" &&
  state.phase === "dealt" &&
  handDone(state) &&
  state.celebration === null &&
  reserveCount(state.bank, state.reserve) > 0

export const canisterDocks = (state: BoosterState): number => state.docks + (nextCapsuleWaiting(state) ? 1 : 0)

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

const zoomable = (state: BoosterState): readonly boolean[] => (state.layout === "phone" ? state.stored : state.revealed)

export function zoomOpened(state: BoosterState, index: number): BoosterState {
  if (!idle(state) || !zoomable(state)[index] || state.zoom === index) return state
  return { ...state, zoom: index }
}

export function zoomClosed(state: BoosterState): BoosterState {
  const { zoom } = state
  if (zoom === null) return { ...state, focus: "card" }
  return { ...state, zoom: null, focus: state.layout === "phone" ? { slot: zoom } : { card: zoom } }
}

export function zoomStepped(state: BoosterState, step: -1 | 1): BoosterState {
  if (state.zoom === null) return state
  const next = zoomNeighbour(zoomable(state), state.zoom, step)
  return next === null ? state : { ...state, zoom: next }
}

export function activation(state: BoosterState, index: number, now: number, lastDragEnd = -Infinity): Activation {
  if (!state.answer?.cards[index]) return "none"
  if (!state.revealed[index]) return "reveal"
  if (state.layout === "phone") return now - lastDragEnd >= CLICK_AFTER_DRAG ? "store" : "none"
  if (locked(state) || state.opening || state.revealingAll || state.revealing.includes(index)) return "none"
  const at = state.revealedAt[index]
  return at !== undefined && now - at >= REVEAL_GUARD ? "zoom" : "none"
}

function hintOf(state: BoosterState, total: number, revealedCount: number, top: number | null): Hint {
  if (state.layout === "phone") {
    if (top === null) return { kind: "done", count: total }
    return { kind: state.revealed[top] ? "swipe" : "tap" }
  }
  const remaining = total - revealedCount
  return remaining > 0 ? { kind: "remaining", count: remaining } : { kind: "done", count: total }
}

function openVariant(state: BoosterState, reserveEmpty: boolean): OpenVariant {
  if (state.phase === "opening") return "skip"
  if (reserveEmpty) return "empty"
  return state.phase === "dealt" ? "next" : "open"
}

export function controls(state: BoosterState): Controls {
  const total = state.answer?.cards.length ?? 0
  const revealedCount = state.revealed.filter(Boolean).length
  const everyRevealed = total > 0 && revealedCount === total
  const handOnTable = state.phase === "dealt" && total > 0
  const reserveEmpty = reserveCount(state.bank, state.reserve) <= 0 && state.phase !== "opening"
  const top = handOnTable ? topOfPile(state.revealed, state.stored) : null
  const isLocked = locked(state)
  const { zoom } = state
  return {
    open: openVariant(state, reserveEmpty),
    openDisabled: reserveEmpty || (state.phase === "dealt" && !everyRevealed),
    busy: state.phase === "opening" || state.revealingAll || isLocked || state.storing,
    revealAllDisabled: !handOnTable || everyRevealed || state.revealingAll || state.storing || state.legendary !== null,
    hint: handOnTable ? hintOf(state, total, revealedCount, top) : null,
    storedCount: state.stored.filter(Boolean).length,
    top,
    plate: state.layout === "phone" && top !== null && state.revealed[top] ? top : null,
    zoomPrevious: zoom !== null && zoomNeighbour(zoomable(state), zoom, -1) !== null,
    zoomNext: zoom !== null && zoomNeighbour(zoomable(state), zoom, 1) !== null,
  }
}
