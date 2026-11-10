export type Terms = {
  minimum: number
  available: number
  buyNow: number | null
  ownMaximum: number | null
}

export type AnnonceState = {
  terms: Terms
  text: string
  submitting: boolean
  posted: string
  answered: boolean
}

export type ButtonKind = "idle" | "bid" | "raise" | "buy"

export const LIVE_DELAY = 500

const SPACES = /[\s  ]/g
const PLAIN_AMOUNT = /^\d+$/

export function start(terms: Terms, answered = false): AnnonceState {
  return { terms, text: "", submitting: false, posted: "", answered }
}

export function parse(text: string): number | null {
  const digits = text.replace(SPACES, "")
  if (!PLAIN_AMOUNT.test(digits)) return null
  const amount = Number(digits)
  return Number.isSafeInteger(amount) && amount > 0 ? amount : null
}

export function reachesBuyNow(terms: Terms, amount: number): boolean {
  return terms.buyNow !== null && amount >= terms.buyNow
}

export function commitment(state: AnnonceState, amount: number): number {
  const { terms } = state
  return (reachesBuyNow(terms, amount) ? (terms.buyNow ?? amount) : amount) - (terms.ownMaximum ?? 0)
}

export function buttonKind(state: AnnonceState): ButtonKind {
  const amount = parse(state.text)
  if (amount === null) return "idle"
  if (reachesBuyNow(state.terms, amount)) return "buy"
  return state.terms.ownMaximum === null ? "bid" : "raise"
}

export function edit(state: AnnonceState, text: string): AnnonceState {
  return state.text === text && !state.answered ? state : { ...state, text, answered: false }
}

export function submit(state: AnnonceState): AnnonceState | null {
  return state.submitting ? null : { ...state, submitting: true }
}

export function submitted(state: AnnonceState): AnnonceState {
  return state.submitting ? { ...state, submitting: false } : state
}

export function posted(state: AnnonceState, live: string): AnnonceState {
  return state.posted === live ? state : { ...state, posted: live }
}
