// The application's own DOM events (architecture, Consistency Conventions:
// `gameble:<noun-verb>`, declared here only). Each name maps to its detail;
// dispatchGameble and onGameble keep both ends typed.
import type { Rarity } from "./card_types"
import type { SideCount } from "./trade_board"

// A toast to show (EXPERIENCE.md, Toast): the shell's toast region appends
// it from its server-rendered template.
export type ToastDetail = {
  message: string
  title?: string
  tone?: "notice" | "alert"
}

// The booster island revealed a card of `tier`: the player's copies per
// tier now, read by the top bar's rarity counter.
export type TierRevealedDetail = { tier: Rarity; counts: Record<Rarity, number> }

// The player's reserve changed (an opening's answer): read by the booster
// screen's reserve chip. Times are UTC ISO 8601.
export type BankChangedDetail = { available: number; reserveFull: boolean; nextAvailableAt: string | null; serverTime: string }

// The booster island locks the in-app navigation (top bar back button, tab
// bar) while it opens a booster or reveals a card, and unlocks it after.
export type NavigationLockedDetail = { locked: boolean }

// The player's private stream says their trades, or their friends and
// invitations, changed.
export type StreamUpdatedDetail = Record<string, never>
export type TradeChangedDetail = { give: SideCount; take: SideCount }

export interface GamebleEventMap {
  "gameble:toast": ToastDetail
  "gameble:tier-revealed": TierRevealedDetail
  "gameble:bank-changed": BankChangedDetail
  "gameble:navigation-locked": NavigationLockedDetail
  "gameble:trades-updated": StreamUpdatedDetail
  "gameble:friends-updated": StreamUpdatedDetail
  "gameble:trade-changed": TradeChangedDetail
}

export type GamebleEventName = keyof GamebleEventMap

export function dispatchGameble<K extends GamebleEventName>(name: K, detail: GamebleEventMap[K], target: EventTarget = window): void {
  target.dispatchEvent(new CustomEvent(name, { detail }))
}

// Listens on `target` (window by default) and returns the function that
// removes the listener, for a controller's disconnect.
export function onGameble<K extends GamebleEventName>(
  name: K,
  listener: (detail: GamebleEventMap[K], event: CustomEvent<GamebleEventMap[K]>) => void,
  target: EventTarget = window
): () => void {
  const handler = (event: Event): void => {
    const custom = event as CustomEvent<GamebleEventMap[K]>
    listener(custom.detail, custom)
  }
  target.addEventListener(name, handler)
  return () => target.removeEventListener(name, handler)
}
