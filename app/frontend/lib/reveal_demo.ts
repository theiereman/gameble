export type RevealDemoState = { revealed: boolean; index: number }

export const REVEAL_DEMO_START: RevealDemoState = { revealed: false, index: 0 }

export const FLIP_MS = 700
export const CROSSFADE_MS = 220

export function pressRevealDemo(state: RevealDemoState, count: number): RevealDemoState {
  if (count <= 0) return state
  if (!state.revealed) return { revealed: true, index: state.index }
  return { revealed: false, index: (state.index + 1) % count }
}

export function revealDemoLabel(state: RevealDemoState, labels: { reveal: string; restart: string }): string {
  return state.revealed ? labels.restart : labels.reveal
}

export function turnDuration(reduced: boolean): number {
  return reduced ? CROSSFADE_MS : FLIP_MS
}
