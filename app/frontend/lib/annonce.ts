export type Terms = {
  minimum: number
  available: number
  buyNow: number | null
  ownMaximum: number | null
  price: number
  unusualMultiple: number
}

export type Gate = "none" | "unusual" | "buy_now"
export type Submitter = "bid" | "buy_now"
export type Pending = { gate: Exclude<Gate, "none">; submitter: Submitter }
export type Consent = { submitter: Submitter; text: string }

export type AnnonceState = {
  terms: Terms
  text: string
  submitting: boolean
  posted: string
  answered: boolean
  pending: Pending | null
  consent: Consent | null
}

export type ButtonKind = "idle" | "bid" | "raise" | "buy"

export const LIVE_DELAY = 500

const SPACES = /[\s  ]/g
const PLAIN_AMOUNT = /^\d+$/

export function start(terms: Terms, answered = false): AnnonceState {
  return { terms, text: "", submitting: false, posted: "", answered, pending: null, consent: null }
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

export function retermed(state: AnnonceState, terms: Terms, answered: boolean): AnnonceState {
  return { ...state, terms, answered }
}

export function edit(state: AnnonceState, text: string): AnnonceState {
  return state.text === text && !state.answered
    ? state
    : { ...state, text, answered: false, pending: null, consent: null }
}

export function submit(state: AnnonceState): AnnonceState | null {
  return state.submitting ? null : { ...state, submitting: true, pending: null, consent: null }
}

export function submitted(state: AnnonceState): AnnonceState {
  return state.submitting ? { ...state, submitting: false } : state
}

export function posted(state: AnnonceState, live: string): AnnonceState {
  return state.posted === live ? state : { ...state, posted: live }
}
