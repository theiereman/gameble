import type { BoosterState, MarketMove, MarketPlace } from "./booster"
import type { Transition } from "./booster_host"
import { csrfToken } from "./booster_page"
import type { Rarity } from "./card_types"
import { dispatchGameble } from "./events"
import type { OpeningCard } from "./opening"

export type BoosterMarket = Readonly<{
  entrustUrl?: string
  sellUrl?: string
  settings?: string
  duration?: number
  entrustment?: Partial<Record<Rarity, number>>
  minimumPrice?: Partial<Record<Rarity, number>>
}>

export type CardMarketHost = Readonly<{
  market: BoosterMarket
  state: () => BoosterState | undefined
  apply: (transition: Transition) => unknown
  failed: string
}>

export const marketMoveKey = (token: string, index: number): string => `${token}:${index}`

export function marketMoved(state: BoosterState, key: string, move: MarketMove): BoosterState {
  return { ...state, marketMoves: { ...state.marketMoves, [key]: move } }
}

export function marketMoveSent(state: BoosterState, key: string): BoosterState {
  const move = state.marketMoves[key]
  return move ? marketMoved(state, key, { ...move, sent: true }) : state
}

export function marketMoveDropped(state: BoosterState, key: string): BoosterState {
  if (!(key in state.marketMoves)) return state
  const { [key]: _dropped, ...kept } = state.marketMoves
  return { ...state, marketMoves: kept }
}

type MarketRequest = Readonly<{ url: string; body: URLSearchParams }>

export function marketRequest(market: BoosterMarket, place: MarketPlace, card: OpeningCard): MarketRequest | null {
  const ref = `${card.slug}:${card.season}`
  const settings = market.settings ?? ""
  if (place === "entrust") {
    return market.entrustUrl
      ? { url: market.entrustUrl, body: new URLSearchParams({ selection: `${ref}=1`, settings }) }
      : null
  }
  const price = market.minimumPrice?.[card.tier]
  if (!market.sellUrl || price === undefined) return null
  const body = new URLSearchParams({
    ref,
    starting_price: String(price),
    duration_hours: String(market.duration),
    settings,
  })
  return { url: market.sellUrl, body }
}

export function marketAmount(market: BoosterMarket, place: MarketPlace, tier: Rarity): number | undefined {
  return (place === "entrust" ? market.entrustment : market.minimumPrice)?.[tier]
}

// The refusal's message, or null once the server took the move.
export async function sendMarketMove(
  { url, body }: MarketRequest,
  failed: string,
  send: typeof globalThis.fetch = globalThis.fetch,
): Promise<string | null> {
  const headers: Record<string, string> = { Accept: "application/json" }
  const token = csrfToken()
  if (token) headers["X-CSRF-Token"] = token
  let response: Response
  try {
    response = await send(url, { method: "POST", headers, body, credentials: "same-origin", keepalive: true })
  } catch {
    return failed
  }
  if (response.ok) return null
  try {
    const answer: unknown = await response.json()
    const message = (answer as { error?: { message?: unknown } } | null)?.error?.message
    return typeof message === "string" ? message : failed
  } catch {
    return failed
  }
}

// A card's entrust or sale stays undoable while its hand shows; it is posted only once the player leaves that hand.
export class CardMarket {
  private readonly pending = new Map<string, MarketRequest>()
  private readonly leave = (): void => this.flush(false)

  constructor(private readonly host: CardMarketHost) {}

  move(index: number, place: MarketPlace): void {
    const answer = this.host.state()?.answer
    const card = answer?.cards[index]
    if (!answer || !card) return
    const key = marketMoveKey(answer.pack.token, index)
    const amount = marketAmount(this.host.market, place, card.tier)
    const request = marketRequest(this.host.market, place, card)
    if (key in (this.host.state()?.marketMoves ?? {}) || amount === undefined || !request) return
    this.host.apply((s) => marketMoved(s, key, { place, amount, sent: false }))
    this.pending.set(key, request)
    window.addEventListener("pagehide", this.leave)
  }

  undo(index: number): void {
    const token = this.host.state()?.answer?.pack.token
    const key = token === undefined ? null : marketMoveKey(token, index)
    if (key === null || !this.pending.delete(key)) return
    this.host.apply((s) => marketMoveDropped(s, key))
  }

  // onScreen: the hand still shows (a new capsule opening), so its overlays lose their undo.
  flush(onScreen: boolean): void {
    window.removeEventListener("pagehide", this.leave)
    const sending = [...this.pending]
    this.pending.clear()
    for (const [key, request] of sending) void this.post(key, request, onScreen)
  }

  private async post(key: string, request: MarketRequest, onScreen: boolean): Promise<void> {
    if (onScreen) this.host.apply((s) => marketMoveSent(s, key))
    const refusal = await sendMarketMove(request, this.host.failed)
    if (refusal === null) return
    if (onScreen) this.host.apply((s) => marketMoveDropped(s, key))
    dispatchGameble("gameble:toast", { message: refusal, tone: "alert" })
  }
}
