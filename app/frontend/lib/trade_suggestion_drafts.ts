import { readDraft } from "./trade_board_draft"

type DraftStorage = Parameters<typeof readDraft>[1]

export function draftedKeys(keys: readonly string[], storage?: DraftStorage): Set<string> {
  return new Set(keys.filter((key) => readDraft(key, storage) !== null))
}

export function successorOf(hidden: readonly boolean[], index: number): number | null {
  const after = hidden.findIndex((isHidden, position) => position > index && !isHidden)
  if (after !== -1) return after
  const before = hidden.slice(0, index).lastIndexOf(false)
  return before === -1 ? null : before
}
