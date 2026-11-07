import { RESERVES, bankAfterHeld, countsKept, heldSkippingQueued } from "./booster_bank"
import { bankOfAnswer, handOpened } from "./booster_opening"
import { NO_COUNTS, allRevealed, countsAfterReveal, handDone, owedRevealOf } from "./booster_rules"
import { bankFetched, celebrate } from "./booster_state"
import type { BoosterState, OwedReveal, Reserve } from "./booster_types"
import type { HeldCapsule, OpeningAnswer, OpeningBank } from "./opening"
import { withQueued, withoutQueued, type QueuedOpening } from "./opening_queue"

export type OpeningRoute = "held" | "await" | "send"

export const heldFor = (state: BoosterState): HeldCapsule | null => state.held[state.reserve]

export const confirmationAwaited = (state: BoosterState, reserve: Reserve = state.reserve): boolean =>
  state.confirming.some((entry) => entry.reserve === reserve)

export function openingRoute(state: BoosterState): OpeningRoute {
  if (heldFor(state)) return "held"
  return confirmationAwaited(state) ? "await" : "send"
}

export function heldEntry(state: BoosterState, key: string): QueuedOpening | null {
  const held = heldFor(state)
  return held ? { token: held.pack.token, key, reserve: state.reserve } : null
}

function provisionalAnswer(held: HeldCapsule, state: BoosterState): OpeningAnswer {
  const countsBefore = state.counts ?? held.tierCountsBefore
  const bank: OpeningBank = { ...state.bank, scheduledAt: [] }
  return {
    pack: held.pack,
    cards: held.cards,
    bank,
    serverTime: state.bank.serverTime,
    tierCountsBefore: { ...countsBefore },
    setTiers: [],
    goalsReached: [],
    next: null,
  }
}

export function heldOpened(state: BoosterState, entry: QueuedOpening): BoosterState {
  const held = state.held[entry.reserve]
  if (entry.reserve !== state.reserve || held?.pack.token !== entry.token) return state
  const answer = provisionalAnswer(held, state)
  const opened = handOpened(
    { ...state, held: { ...state.held, [entry.reserve]: null } },
    answer,
    bankAfterHeld(state.bank, entry.reserve),
  )
  return {
    ...opened,
    pendingKey: state.pendingKey,
    provisional: true,
    celebrationPending: null,
    goalsPending: [],
    confirming: withQueued(state.confirming, entry),
  }
}

export function openingConfirmed(state: BoosterState, token: string, answer: OpeningAnswer): BoosterState {
  const entry = state.confirming.find((queued) => queued.token === token)
  if (!entry) return state
  const confirming = withoutQueued(state.confirming, token)
  const othersPending = RESERVES.filter(
    (reserve) => reserve !== entry.reserve && confirming.some((queued) => queued.reserve === reserve),
  )
  const { bank, held } = heldSkippingQueued(
    {
      bank: countsKept(bankOfAnswer(answer), state.bank, othersPending),
      held: { ...state.held, [entry.reserve]: answer.next ?? null },
    },
    confirming,
    [entry.reserve],
  )
  const owed = state.revealsOwed.find((reveal) => reveal.token === token) ?? null
  const adopted = bankFetched(
    {
      ...state,
      confirming,
      held,
      revealsOwed: owed ? state.revealsOwed.filter((reveal) => reveal !== owed) : state.revealsOwed,
      revealDue: owed ?? state.revealDue,
    },
    bank,
    state.bankGeneration,
  )
  if (state.provisional && state.answer?.pack.token === token) return handConfirmed(adopted, answer)
  return answer.goalsReached.length > 0 ? { ...adopted, goalsReached: answer.goalsReached } : adopted
}

function handConfirmed(state: BoosterState, answer: OpeningAnswer): BoosterState {
  const shown = state.answer!
  const sameLength = shown.cards.length === answer.cards.length
  const kept = answer.cards.map((card, index) => sameLength && card.slug === shown.cards[index].slug)
  const redrawn =
    kept.includes(false) || answer.cards.some((card, index) => card.firstCopy !== shown.cards[index]?.firstCopy)
  const revealed = answer.cards.map((_, index) => kept[index] && (state.revealed[index] ?? false))
  const counts = answer.cards.reduce(
    (sum, card, index) => (revealed[index] ? countsAfterReveal(sum, card.tier) : sum),
    { ...NO_COUNTS, ...answer.tierCountsBefore },
  )
  const confirmed: BoosterState = {
    ...state,
    answer: redrawn ? answer : shown,
    provisional: false,
    revealed,
    revealedAt: answer.cards.map((_, index) => (kept[index] ? state.revealedAt[index] : undefined)),
    stored: answer.cards.map((_, index) => kept[index] && (state.stored[index] ?? false)),
    counts,
    celebrationPending: answer.setTiers,
    goalsPending: answer.goalsReached,
    rebuilds: state.rebuilds + (redrawn ? 1 : 0),
  }
  const due = withRevealDue(confirmed)
  if (state.status !== "complete") return due
  return handDone(due) ? celebrate(due) : { ...due, status: "inventory", focus: "card" }
}

function withRevealDue(state: BoosterState): BoosterState {
  const owed: OwedReveal | null = allRevealed(state) ? owedRevealOf(state) : null
  return owed ? { ...state, revealDue: owed } : state
}

export function confirmationRefused(state: BoosterState, token: string): BoosterState {
  if (!state.confirming.some((entry) => entry.token === token)) return state
  const onTable = state.provisional && state.answer?.pack.token === token
  return {
    ...state,
    provisional: onTable ? false : state.provisional,
    confirming: withoutQueued(state.confirming, token),
    revealsOwed: state.revealsOwed.filter((reveal) => reveal.token !== token),
  }
}
