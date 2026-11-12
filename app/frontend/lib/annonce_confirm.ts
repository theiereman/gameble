import { parse, type AnnonceState, type Gate } from "./annonce"

export function multipleOf(amount: number, price: number): number {
  return Math.floor(amount / price)
}

function unusual({ terms }: AnnonceState, amount: number): boolean {
  const threshold = terms.unusualMultiple * terms.price
  return Number.isSafeInteger(threshold) && amount >= threshold
}

export function gate(state: AnnonceState): Gate {
  const amount = parse(state.text)
  return amount !== null && unusual(state, amount) ? "unusual" : "none"
}

export function ask(state: AnnonceState): AnnonceState {
  return { ...state, pending: true }
}

export function grant(state: AnnonceState): AnnonceState {
  if (!state.pending) return state
  return { ...state, pending: false, consent: state.text }
}

export function revoke(state: AnnonceState): AnnonceState {
  return !state.pending && state.consent === null ? state : { ...state, pending: false, consent: null }
}

export function consented(state: AnnonceState): boolean {
  return state.consent !== null && state.consent === state.text
}
