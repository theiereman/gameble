import { SWIPE_START } from "./booster_motion"

export type Pointer = { id: number; x: number; y: number }

export type SwipeMove = { kind: "none" } | { kind: "started" | "dragging"; dx: number; dy: number }

export type SwipeRelease = { index: number; dx: number; dy: number; abandoned: boolean }

type Gesture = {
  id: number
  index: number
  x: number
  y: number
  dragging: boolean
  tilted: boolean
  tiltingAtPress: boolean
}

const NONE: SwipeMove = { kind: "none" }

export function dragTransform(dx: number, dy: number): string {
  return `translate(${Math.round(dx)}px, ${Math.round(dy)}px) rotate(${(dx * 0.05).toFixed(2)}deg)`
}

export class CardSwipe {
  private gesture: Gesture | null = null
  private ended = -Infinity

  get active(): boolean {
    return this.gesture !== null
  }

  get index(): number | null {
    return this.gesture?.index ?? null
  }

  get lastDragEnd(): number {
    return this.ended
  }

  press({ id, x, y }: Pointer, index: number, tiltingAtPress: boolean): void {
    if (this.gesture) return
    this.gesture = { id, index, x, y, dragging: false, tilted: false, tiltingAtPress }
  }

  move({ id, x, y }: Pointer, tilting: boolean): SwipeMove {
    const gesture = this.gesture
    if (!gesture || gesture.id !== id || gesture.tilted) return NONE
    if (!gesture.tiltingAtPress && tilting) {
      gesture.tilted = true
      return NONE
    }
    const dx = x - gesture.x
    const dy = y - gesture.y
    if (gesture.dragging) return { kind: "dragging", dx, dy }
    if (Math.hypot(dx, dy) <= SWIPE_START) return NONE
    gesture.dragging = true
    return { kind: "started", dx, dy }
  }

  end({ id, x, y }: Pointer, cancelled: boolean, now: number): SwipeRelease | null {
    const gesture = this.gesture
    if (!gesture || gesture.id !== id) return null
    this.gesture = null
    if (!gesture.dragging) return null
    this.ended = now
    return { index: gesture.index, dx: x - gesture.x, dy: y - gesture.y, abandoned: cancelled || gesture.tilted }
  }

  forget(): void {
    this.gesture = null
  }
}
