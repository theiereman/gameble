export type DuelState = { readonly moveNumber: number }

export function startDuel(moveNumber: number): DuelState {
  return { moveNumber }
}

export function acceptsView(state: DuelState, moveNumber: number): boolean {
  return moveNumber > state.moveNumber
}

export function viewShown(state: DuelState, moveNumber: number): DuelState {
  return { ...state, moveNumber }
}

export function moveNumberFrom(text: string | null | undefined): number | null {
  return text != null && /^\d+$/.test(text) ? Number(text) : null
}
