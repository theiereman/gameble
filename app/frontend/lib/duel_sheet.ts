export type SheetPhase = "choosing" | "waiting" | "ended"

export type SheetState = { readonly phase: SheetPhase; readonly landing: string | null }

export type FriendOption = { readonly token: string; readonly ariaDisabled: string | null }

export function startSheet(waiting: boolean): SheetState {
  return { phase: waiting ? "waiting" : "choosing", landing: null }
}

export function challengeSent(state: SheetState): SheetState {
  return state.phase === "choosing" ? { ...state, phase: "waiting" } : state
}

export function outcomeArrived(state: SheetState, landing: string | null): SheetState {
  return { phase: "ended", landing: landing || null }
}

export function isBlocked(ariaDisabled: string | null): boolean {
  return ariaDisabled === "true"
}

export function friendToSelect(options: readonly FriendOption[], token: string | undefined): string | undefined {
  return options.find((option) => option.token === token && !isBlocked(option.ariaDisabled))?.token
}

export function focusAfter(state: SheetState): "choice" | "waiting" | "outcome" {
  if (state.phase === "ended") return "outcome"
  return state.phase === "waiting" ? "waiting" : "choice"
}
