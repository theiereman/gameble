// The pack reveal's timing and card states (CAP-5; EXPERIENCE.md, Face-down
// card, Flip all; story 3.6). Pure: no DOM, no React. Every duration of the
// reveal lives here; the stylesheet (styles/reveal.css) reads them from the
// custom properties the island writes on each card.
import type { Rarity } from "../components/Card"

/** A card's place in the reveal: under dust, wiped (seal shown), turned (face shown). */
export type CardState = "dusty" | "wiped" | "flipped"

/** The turn, the same for every card. */
export const TURN_MS = 400

/** The flourish after the turn, longer as the rarity rises. */
export const FLOURISH_MS: Record<Rarity, number> = {
  common: 200,
  uncommon: 350,
  rare: 700,
  epic: 1100,
  legendary: 2400,
}

/** The dust fading off a wiped card. */
export const WIPE_MS = 200

/** Flip all: the gap between two quick cards. */
export const STAGGER_MS = 150

/** Dust burst: how many pixels fly off a card, by rarity. */
export const BURST_PIXELS: Record<Rarity, number> = {
  common: 8,
  uncommon: 12,
  rare: 16,
  epic: 24,
  legendary: 32,
}

/** The steps of the burst's flight: each step lands on the 2 px grid. */
export const BURST_STEPS = 4

/** How a card is flipped: at its own length, or quickly by flip all. */
export type FlipMode = "full" | "quick"

/** A card's whole reveal, turn and flourish. */
export function revealLength(rarity: Rarity): number {
  return TURN_MS + FLOURISH_MS[rarity]
}

/** The length a card plays when flipped this way. A legendary card always plays its full length. */
export function flipLength(rarity: Rarity, mode: FlipMode): number {
  return mode === "quick" && rarity !== "legendary" ? revealLength("common") : revealLength(rarity)
}

/** Wiping a dusty card shows its seal; any other card is left as it is. */
export function wipe(state: CardState): CardState {
  return state === "dusty" ? "wiped" : state
}

/** Flipping shows the face; a dusty card is wiped on the way. */
export function flip(_state: CardState): CardState {
  return "flipped"
}

/** One card of flip all: flipped `at` ms after the start, playing `length` ms. */
export type FlipAllStep = { index: number; at: number; mode: FlipMode; length: number }

/**
 * Flip all, planned: the cards not yet flipped, in order. A quick card is
 * followed by the next one a stagger later; a legendary card, wiped or not, plays
 * its full length before the next starts. `end` is when the last card's
 * reveal is over.
 */
export function planFlipAll(rarities: Rarity[], states: CardState[]): { steps: FlipAllStep[]; end: number } {
  const steps: FlipAllStep[] = []
  let at = 0
  let end = 0
  rarities.forEach((rarity, index) => {
    if (states[index] === "flipped") return
    const mode: FlipMode = rarity === "legendary" ? "full" : "quick"
    const length = flipLength(rarity, mode)
    steps.push({ index, at, mode, length })
    end = Math.max(end, at + length)
    at += mode === "full" ? length : STAGGER_MS
  })
  return { steps, end }
}

/** The timers flip all runs on; the browser's by default, fake ones in tests. */
export type Timers = {
  setTimeout: (callback: () => void, ms: number) => unknown
  clearTimeout: (handle: unknown) => void
}

const browserTimers: Timers = {
  setTimeout: (callback, ms) => globalThis.setTimeout(callback, ms),
  clearTimeout: (handle) => globalThis.clearTimeout(handle as ReturnType<typeof globalThis.setTimeout>),
}

/**
 * Runs a flip all plan: `onStep` for each card at its time, then `onEnd`.
 * Each timer is set when the previous one fires, so a card is never flipped
 * sooner after the one before than the plan says, however late a timer
 * fires: a legendary card is always held its full length. Returns a cancel
 * function that clears the pending timer (on unmount).
 */
export function runFlipAll(
  plan: { steps: FlipAllStep[]; end: number },
  { onStep, onEnd }: { onStep: (step: FlipAllStep) => void; onEnd: () => void },
  timers: Timers = browserTimers,
): () => void {
  let pending: unknown = null
  let cancelled = false
  const at = (position: number) => (position < plan.steps.length ? plan.steps[position].at : plan.end)
  const run = (position: number) => {
    pending = null
    if (cancelled) return
    if (position === plan.steps.length) {
      onEnd()
      return
    }
    onStep(plan.steps[position])
    pending = timers.setTimeout(() => run(position + 1), at(position + 1) - at(position))
  }
  pending = timers.setTimeout(() => run(0), at(0))
  return () => {
    cancelled = true
    if (pending !== null) timers.clearTimeout(pending)
  }
}

/**
 * The burst's pixels for a card: fixed offsets (the same on every render),
 * whole multiples of the grid at each step, flying outwards from spots
 * spread over the card. In CSS pixels, from the card's top left corner.
 */
export function burstPixels(rarity: Rarity, width: number, height: number): { x: number; y: number; dx: number; dy: number }[] {
  const count = BURST_PIXELS[rarity]
  const grid = 2
  const stride = grid * BURST_STEPS
  const snap = (value: number) => Math.round(value / grid) * grid
  return Array.from({ length: count }, (_, index) => {
    // The golden angle spreads the pixels evenly around the card.
    const angle = index * 2.399963
    const ring = 0.25 + 0.2 * (index % 3)
    const x = snap(width / 2 + Math.cos(angle) * width * ring)
    const y = snap(height / 2 + Math.sin(angle) * height * ring)
    const reach = 2 + (index % 4)
    const dx = Math.round(Math.cos(angle) * reach) * stride
    const dy = Math.round(Math.sin(angle) * reach) * stride
    return { x, y, dx, dy }
  })
}
