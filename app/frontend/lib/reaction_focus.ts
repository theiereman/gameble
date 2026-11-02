export const FOCUS_WINDOW_MS = 5_000

export interface PressedReaction {
  frameId: string
  kind: string
  at: number
}

// The reaction a player pressed, kept until the server's answer replaces the
// bar, so the new bar can give the focus back to the same button.
export class PressedFocus {
  private pressed: PressedReaction | null = null

  remember(frameId: string, kind: string, at: number): void {
    this.pressed = { frameId, kind, at }
  }

  take(frameId: string, at: number): string | null {
    const pressed = this.pressed
    if (!pressed || pressed.frameId !== frameId) return null

    this.pressed = null
    return at - pressed.at <= FOCUS_WINDOW_MS ? pressed.kind : null
  }
}
