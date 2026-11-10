import type { Rarity } from "./card_types"

export type Layout = "wide" | "phone"
export type Step = 1 | 2
export type Field = "start" | "buyNow"
export type RefusalCode = "invalidPrice" | "belowMinimum" | "notAboveStart"

export type Edition = {
  ref: string
  title: string
  rarity: Rarity
  rarityName: string
  season: number
  free: number
  minimum: number
  stamp: number
}

export type Refusal = { field: Field; code: RefusalCode }

export type ListingState = {
  editions: readonly Edition[]
  basisPoints: number
  chosen: string | null
  start: string
  buyNow: string
  duration: string
  layout: Layout
  step: Step
  shown: Refusal | null
}

export type Lines = {
  stamp: number
  commission: number | null
  received: number | null
}

export type Typed = Readonly<{ start: string; buyNow: string; duration: string }>

const BASIS_POINTS = 10_000n
const MAX_SAFE = BigInt(Number.MAX_SAFE_INTEGER)
const PLAIN_AMOUNT = /^\d+$/

export function start(
  editions: readonly Edition[],
  basisPoints: number,
  typed: Typed,
  chosen: string | null,
  layout: Layout,
): ListingState {
  const known = chosen !== null && editions.some((edition) => edition.ref === chosen) ? chosen : null
  return {
    editions,
    basisPoints,
    chosen: known,
    ...typed,
    layout,
    step: known === null ? 1 : 2,
    shown: null,
  }
}

export function commission(price: bigint, basisPoints: number): bigint {
  return (price * BigInt(basisPoints)) / BASIS_POINTS
}

export function received(price: bigint, basisPoints: number): bigint {
  return price - commission(price, basisPoints)
}

export function amountOf(text: string): bigint | null {
  const typed = text.trim()
  return PLAIN_AMOUNT.test(typed) ? BigInt(typed) : null
}

export function chosenEdition(state: ListingState): Edition | null {
  return state.editions.find((edition) => edition.ref === state.chosen) ?? null
}

export function choose(state: ListingState, ref: string): ListingState {
  if (!state.editions.some((edition) => edition.ref === ref)) return state
  return { ...state, chosen: ref, step: 2, shown: null }
}

export function back(state: ListingState): ListingState {
  return state.step === 1 ? state : { ...state, step: 1 }
}

export function setStart(state: ListingState, start: string): ListingState {
  return { ...state, start, shown: null }
}

export function setBuyNow(state: ListingState, buyNow: string): ListingState {
  return { ...state, buyNow, shown: null }
}

export function setDuration(state: ListingState, duration: string): ListingState {
  return state.duration === duration ? state : { ...state, duration }
}

export function layoutAsked(state: ListingState, layout: Layout): ListingState {
  return state.layout === layout ? state : { ...state, layout }
}

function positive(price: bigint | null): price is bigint {
  return price !== null && price > 0n
}

// The same rules the server applies, in the same order, so a refusal here is the refusal the post would get.
export function refusal(state: ListingState): Refusal | null {
  const edition = chosenEdition(state)
  if (!edition) return null
  const price = amountOf(state.start)
  if (!positive(price)) return { field: "start", code: "invalidPrice" }
  const buyNow = state.buyNow.trim() === "" ? null : amountOf(state.buyNow)
  if (state.buyNow.trim() !== "" && !positive(buyNow)) return { field: "buyNow", code: "invalidPrice" }
  const minimum = BigInt(edition.minimum)
  if (price < minimum) return { field: "start", code: "belowMinimum" }
  if (buyNow === null) return null
  if (buyNow < minimum) return { field: "buyNow", code: "belowMinimum" }
  if (buyNow <= price) return { field: "buyNow", code: "notAboveStart" }
  return null
}

// The refusals appear when the player validates, and clear on the next edit.
export function validate(state: ListingState): ListingState {
  return { ...state, shown: refusal(state) }
}

function safeFigure(price: bigint | null): number | null {
  return price !== null && price <= MAX_SAFE ? Number(price) : null
}

export function lines(state: ListingState): Lines | null {
  const edition = chosenEdition(state)
  if (!edition) return null
  const price = amountOf(state.start)
  const fits = price !== null && price <= MAX_SAFE
  return {
    stamp: edition.stamp,
    commission: fits ? safeFigure(commission(price, state.basisPoints)) : null,
    received: fits ? safeFigure(received(price, state.basisPoints)) : null,
  }
}
