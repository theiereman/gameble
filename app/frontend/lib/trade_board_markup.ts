import type { Dataset } from "./booster_markup"
import type { Rarity } from "./card_types"
import type { Line, TradeCard } from "./trade_board"

const number = (value: string | undefined): number => Number(value ?? 0) || 0

export function cardFrom({ key = "", title = "", rarity = "common", owned, reserved, max, copies, otherCopies }: Dataset): TradeCard {
  return {
    key,
    title,
    rarity: rarity as Rarity,
    owned: number(owned),
    reserved: number(reserved),
    max: number(max),
    copies: number(copies),
    otherCopies: number(otherCopies),
  }
}

export function lineFrom({ key, quantity }: Dataset): Line {
  return { key: key ?? "", quantity: number(quantity) }
}
