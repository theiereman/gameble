import { amountDigits } from "./amount"

export type Terms = {
  minimum: number
  available: number
  ownMaximum: number | null
  price: number
  unusualMultiple: number
}

export type Gate = "none" | "unusual"

export type AnnonceState = {
  terms: Terms
  text: string
  submitting: boolean
  posted: string
  answered: boolean
  pending: boolean
  consent: string | null
}

export type ButtonKind = "idle" | "bid" | "raise"

export const LIVE_DELAY = 500

export function start(terms: Terms, answered = false): AnnonceState {
  return { terms, text: "", submitting: false, posted: "", answered, pending: false, consent: null }
}

export function parse(text: string): number | null {
  const digits = amountDigits(text)
  if (digits === null) return null
  const amount = Number(digits)
  return Number.isSafeInteger(amount) && amount > 0 ? amount : null
}

export function commitment(state: AnnonceState, amount: number): number {
  return amount - (state.terms.ownMaximum ?? 0)
}

export function buttonKind(state: AnnonceState): ButtonKind {
  const amount = parse(state.text)
  if (amount === null) return "idle"
  return state.terms.ownMaximum === null ? "bid" : "raise"
}

export function retermed(state: AnnonceState, terms: Terms, answered: boolean): AnnonceState {
  return { ...state, terms, answered }
}

export function edit(state: AnnonceState, text: string): AnnonceState {
  return state.text === text && !state.answered
    ? state
    : { ...state, text, answered: false, pending: false, consent: null }
}

export function submit(state: AnnonceState): AnnonceState | null {
  return state.submitting ? null : { ...state, submitting: true, pending: false, consent: null }
}

export function submitted(state: AnnonceState): AnnonceState {
  return state.submitting ? { ...state, submitting: false } : state
}

export function posted(state: AnnonceState, live: string): AnnonceState {
  return state.posted === live ? state : { ...state, posted: live }
}
