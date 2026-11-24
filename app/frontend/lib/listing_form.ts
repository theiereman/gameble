import { amountDigits, groupDigits } from "./amount"
import type { Rarity } from "./card_types"

export type Layout = "wide" | "phone"
export type Step = 1 | 2
export type Field = "start"
export type RefusalCode = "invalidPrice" | "belowMinimum"

export type Edition = {
  ref: string
  title: string
  rarity: Rarity
  rarityName: string
  season: number
  free: number
  minimum: number
  stamp: number
  order: number | null
  orders: readonly number[]
}

export type Refusal = { field: Field; code: RefusalCode }

export type ListingState = {
  editions: Readonly<Record<string, Edition>>
  loaded: readonly string[]
  basisPoints: number
  incrementBasisPoints: number
  chosen: string | null
  start: string
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

export type Opening = { price: number | null; left: readonly number[] }

export type Typed = Readonly<{ start: string; duration: string }>

const BASIS_POINTS = 10_000n
const MAX_SAFE = BigInt(Number.MAX_SAFE_INTEGER)

function byRef(editions: readonly Edition[]): Record<string, Edition> {
  return Object.fromEntries(editions.map((edition) => [edition.ref, edition]))
}

// The cells loaded in the grid are `loaded`; `editions` also keeps the chosen one when no loaded page holds its cell.
export function start(
  editions: readonly Edition[],
  basisPoints: number,
  typed: Typed,
  chosen: string | null,
  layout: Layout,
  loaded: readonly string[] = editions.map((edition) => edition.ref),
  incrementBasisPoints = 0,
): ListingState {
  const byRefs = byRef(editions)
  const known = chosen !== null && chosen in byRefs ? chosen : null
  return {
    editions: byRefs,
    loaded,
    basisPoints,
    incrementBasisPoints,
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
  const digits = amountDigits(text)
  return digits === null ? null : BigInt(digits)
}

export function chosenEdition(state: ListingState): Edition | null {
  return state.chosen === null ? null : (state.editions[state.chosen] ?? null)
}

// The grid's cells as they stand after a page loaded or the filters reloaded it; the chosen edition stays chosen.
export function know(state: ListingState, editions: readonly Edition[], loaded: readonly string[]): ListingState {
  return { ...state, editions: { ...state.editions, ...byRef(editions) }, loaded }
}

export function lowestOrder(edition: Edition | null): number | null {
  return edition === null || edition.orders.length === 0 ? null : Math.min(...edition.orders)
}

// The start the seller has not typed: empty, or the lowest order's price the chosen edition prefilled.
function untouched(state: ListingState): boolean {
  const prefilled = lowestOrder(chosenEdition(state))
  const typed = amountOf(state.start)
  return state.start.trim() === "" || (prefilled !== null && typed === BigInt(prefilled))
}

// Choosing an edition whose orders exist starts the auction at the lowest one's price, so that every order becomes a bid.
export function choose(state: ListingState, ref: string, locale = "en"): ListingState {
  if (!(ref in state.editions)) return state
  const lowest = lowestOrder(state.editions[ref])
  const start = untouched(state) ? (lowest === null ? "" : groupDigits(String(lowest), locale)) : state.start
  return { ...state, chosen: ref, step: 2, shown: null, start }
}

export function back(state: ListingState): ListingState {
  return state.step === 1 ? state : { ...state, step: 1 }
}

export function setStart(state: ListingState, start: string): ListingState {
  return { ...state, start, shown: null }
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

export function refusal(state: ListingState): Refusal | null {
  const edition = chosenEdition(state)
  if (!edition) return null
  const price = amountOf(state.start)
  if (!positive(price)) return { field: "start", code: "invalidPrice" }
  if (price < BigInt(edition.minimum)) return { field: "start", code: "belowMinimum" }
  return null
}

function ceilDiv(numerator: bigint, denominator: bigint): bigint {
  return (numerator + denominator - 1n) / denominator
}

// The price AuctionMath gives over the orders at or above the start, best first: the start for one, else the best or the runner-up raised by an increment.
function openingPrice(reaching: readonly number[], at: bigint, incrementBasisPoints: number): number {
  if (reaching.length === 1) return Number(at)
  const second = BigInt(reaching[1])
  const raised = second + ceilDiv(second * BigInt(incrementBasisPoints), BASIS_POINTS)
  return Number(raised < BigInt(reaching[0]) ? raised : BigInt(reaching[0]))
}

// What the typed start does with the chosen edition's orders: the price the auction opens at, and the orders under the start that stay open.
export function opening(state: ListingState): Opening | null {
  const edition = chosenEdition(state)
  const at = amountOf(state.start)
  if (!edition || edition.orders.length === 0 || !positive(at)) return null
  const orders = [...edition.orders].sort((first, second) => second - first)
  const reaching = orders.filter((order) => BigInt(order) >= at)
  return {
    price: reaching.length === 0 ? null : openingPrice(reaching, at, state.incrementBasisPoints),
    left: orders.filter((order) => BigInt(order) < at),
  }
}

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
