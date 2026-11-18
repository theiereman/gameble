export const GUARD_MS = 400
export const REVEAL_MS = 5000
export const RETRY_MS = 2000

export type Field = "card" | "stat" | "direction"
export type Kind = "call" | "answer"

const LATEST_FIRST: readonly Field[] = ["direction", "stat", "card"]

export type Reveal = { readonly round: number; readonly endsAt: number }

export type DuelState = {
  readonly moveNumber: number
  readonly card: string | null
  readonly stat: string | null
  readonly direction: string | null
  readonly activeSince: number | null
  readonly dismissed: number
  readonly reveal: Reveal | null
  readonly hand: readonly string[] | null
  readonly sending: boolean
  readonly deadlineAt: number | null
}

export function startDuel(moveNumber: number): DuelState {
  return {
    moveNumber,
    card: null,
    stat: null,
    direction: null,
    activeSince: null,
    dismissed: 0,
    reveal: null,
    hand: null,
    sending: false,
    deadlineAt: null,
  }
}

export function acceptsView(state: DuelState, moveNumber: number): boolean {
  return moveNumber > state.moveNumber
}

export function viewShown(state: DuelState, moveNumber: number): DuelState {
  return { ...state, moveNumber }
}

export function moveNumberFrom(text: string | null | undefined): number | null {
  return text != null && /^\d+$/.test(text) ? Number(text) : null
}

export function boardShown(state: DuelState, moveNumber: number, deadlineAt: number | null = null): DuelState {
  return {
    ...viewShown(state, moveNumber),
    card: null,
    stat: null,
    direction: null,
    activeSince: null,
    sending: false,
    deadlineAt,
  }
}

export function sendFailed(state: DuelState): DuelState {
  return state.sending ? state : { ...state, sending: true }
}

export function retryOpen(state: DuelState, now: number): boolean {
  return state.sending && (state.deadlineAt === null || now < state.deadlineAt)
}

export function choose(state: DuelState, field: Field, value: string, blocked = false): DuelState {
  if (blocked || state.sending || state[field] === value) return state
  const chosen = { ...state, [field]: value }
  return field === "stat" ? { ...chosen, direction: null } : chosen
}

export function picked(state: DuelState, stat: string, direction: string, blocked = false): DuelState {
  if (blocked || state.sending) return state
  return choose(choose(state, "stat", stat), "direction", direction)
}

export function cleared(state: DuelState): DuelState {
  if (state.sending) return state
  const field = LATEST_FIRST.find((name) => state[name] !== null)
  return field ? { ...state, [field]: null } : state
}

export function ready(state: DuelState, kind: Kind): boolean {
  return state.card !== null && (kind === "answer" || (state.stat !== null && state.direction !== null))
}

export function withReadiness(state: DuelState, isReady: boolean, now: number): DuelState {
  if (isReady === (state.activeSince !== null)) return state
  return { ...state, activeSince: isReady ? now : null }
}

export function released(state: DuelState, now: number): boolean {
  return state.activeSince !== null && now - state.activeSince >= GUARD_MS
}

export function revealSeen(state: DuelState, round: number | null, now: number): DuelState {
  if (round === null || round <= state.dismissed) return state.reveal ? { ...state, reveal: null } : state
  if (state.reveal?.round === round) return state
  return { ...state, reveal: { round, endsAt: now + REVEAL_MS } }
}

export function revealDismissed(state: DuelState): DuelState {
  if (state.reveal === null) return state
  return { ...state, dismissed: Math.max(state.dismissed, state.reveal.round), reveal: null }
}

export function drawnCards(state: DuelState, hand: readonly string[]): readonly string[] {
  const before = state.hand
  return before === null ? [] : hand.filter((card) => !before.includes(card))
}

export function handShown(state: DuelState, hand: readonly string[]): DuelState {
  return { ...state, hand }
}
