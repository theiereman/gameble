export const SCREEN_FRAME = "grand-inventory"
export const DEFAULT_VIEW = "cards"

export type Pending = "scope" | "tab" | null

export type AfterLoad = "announce" | "focus-view" | "none"

export function afterLoad(pending: Pending): AfterLoad {
  if (pending === "scope") return "announce"
  if (pending === "tab") return "focus-view"
  return "none"
}

export function viewField(view: string): { value: string; disabled: boolean } {
  return { value: view, disabled: view === DEFAULT_VIEW }
}

export function pressed<T>(chips: readonly T[], chosen: T | null | undefined): boolean[] {
  if (chosen === null || chosen === undefined || !chips.includes(chosen)) return chips.map(() => false)
  return chips.map((chip) => chip === chosen)
}

export function setsExpanded(current: string | null): boolean {
  return current !== "true"
}
