import type { Rarity } from "./card_types"

export type ToastAction = { label: string; href: string; download?: string }

export type ToastDetail = {
  message: string
  title?: string
  tone?: "notice" | "alert"
  action?: ToastAction
}

export type TierRevealedDetail = { tier: Rarity; counts: Record<Rarity, number> }

export type BankChangedDetail = { available: number; reserveFull: boolean; nextAvailableAt: string | null; serverTime: string }

export type NavigationLockedDetail = { locked: boolean }

export type OpeningRevealingDetail = { revealing: boolean }

export type StreamUpdatedDetail = Record<string, never>

export interface GamebleEventMap {
  "gameble:toast": ToastDetail
  "gameble:tier-revealed": TierRevealedDetail
  "gameble:bank-changed": BankChangedDetail
  "gameble:navigation-locked": NavigationLockedDetail
  "gameble:opening-revealing": OpeningRevealingDetail
  "gameble:trades-updated": StreamUpdatedDetail
  "gameble:friends-updated": StreamUpdatedDetail
}

export type GamebleEventName = keyof GamebleEventMap

export function dispatchGameble<K extends GamebleEventName>(name: K, detail: GamebleEventMap[K], target: EventTarget = window): void {
  target.dispatchEvent(new CustomEvent(name, { detail }))
}

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
