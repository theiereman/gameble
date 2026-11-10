import { parse, reachesBuyNow, type AnnonceState, type Gate, type Submitter } from "./annonce"

export function multipleOf(amount: number, price: number): number {
  return Math.floor(amount / price)
}

function unusual({ terms }: AnnonceState, amount: number): boolean {
  const threshold = terms.unusualMultiple * terms.price
  return Number.isSafeInteger(threshold) && amount >= threshold
}

export function gate(state: AnnonceState, buyNowButton: boolean): Gate {
  const amount = parse(state.text)
  if (buyNowButton || (amount !== null && reachesBuyNow(state.terms, amount))) return "buy_now"
  return amount !== null && unusual(state, amount) ? "unusual" : "none"
}

export function ask(state: AnnonceState, asked: Exclude<Gate, "none">, submitter: Submitter): AnnonceState {
  return { ...state, pending: { gate: asked, submitter } }
}

export function grant(state: AnnonceState): AnnonceState {
  if (!state.pending) return state
  return { ...state, pending: null, consent: { submitter: state.pending.submitter, text: state.text } }
}

export function revoke(state: AnnonceState): AnnonceState {
  return state.pending === null && state.consent === null ? state : { ...state, pending: null, consent: null }
}

export function consented(state: AnnonceState, submitter: Submitter): boolean {
  return state.consent !== null && state.consent.submitter === submitter && state.consent.text === state.text
}
