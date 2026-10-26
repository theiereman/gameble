// The swipe on the phone booster's revealed top card (EXPERIENCE.md,
// Interaction Primitives: "Swipe, always with a button"; story 8.12): a
// touch, pen or mouse pointer pressed on the card drags it once it has
// travelled SWIPE_START px (the card's __float layer follows it: translate
// and a slight rotation, transform only); let go, the island stores the
// card or springs it back (lib/booster_motion.ts, swipeStores). A finger held
// still long enough tilts the card instead (lib/tilt.ts marks the face
// `data-tilting`): a gesture during which that mark appears is a tilt,
// never a swipe (a mouse tilts the face as soon as it hovers it: a mark
// already there when the button goes down does not count). The pointer is
// captured while it drags; a cancelled pointer springs the card back. The
// handlers live on the card's slot (React's own listeners, gone with it).
import { useMemo, useRef } from "react"
import type { CardGestures } from "./BoosterCard"
import { SWIPE_START } from "../lib/booster_motion"

export type SwipeTarget = {
  /** The card may start a drag now (the revealed top card, nothing running). */
  canStart: (index: number) => boolean
  slot: (index: number) => HTMLElement | null
  float: (index: number) => HTMLElement | null
  /** Let go after a drag of `dx`, `dy` px (not called for a tap). */
  release: (index: number, dx: number, dy: number, abandoned: boolean) => void
}

type Gesture = { id: number; index: number; x: number; y: number; dragging: boolean; tilted: boolean; tiltingAtPress: boolean }

/** The card's handlers, and when the last drag ended (a click right after it belongs to the drag). */
export function useCardSwipe(target: SwipeTarget): { gestures: CardGestures; lastDragEnd: () => number; forget: () => void } {
  const latest = useRef(target)
  latest.current = target
  const gesture = useRef<Gesture | null>(null)
  const ended = useRef(-Infinity)

  const gestures = useMemo<CardGestures>(() => {
    const end = (event: { pointerId: number; clientX: number; clientY: number }, cancelled: boolean) => {
      const current = gesture.current
      if (!current || current.id !== event.pointerId) return
      gesture.current = null
      if (!current.dragging) return
      ended.current = performance.now()
      latest.current.release(current.index, event.clientX - current.x, event.clientY - current.y, cancelled || current.tilted)
    }
    return {
      onPointerDown(index, event) {
        if (!event.isPrimary || gesture.current || !latest.current.canStart(index)) return
        const tiltingAtPress = Boolean(latest.current.slot(index)?.querySelector("[data-tilting]"))
        gesture.current = { id: event.pointerId, index, x: event.clientX, y: event.clientY, dragging: false, tilted: false, tiltingAtPress }
      },
      onPointerMove(_index, event) {
        const current = gesture.current
        if (!current || current.id !== event.pointerId || current.tilted) return
        if (!current.tiltingAtPress && latest.current.slot(current.index)?.querySelector("[data-tilting]")) {
          current.tilted = true
          return
        }
        const dx = event.clientX - current.x
        const dy = event.clientY - current.y
        const float = latest.current.float(current.index)
        if (!float) return
        if (!current.dragging) {
          if (Math.hypot(dx, dy) <= SWIPE_START) return
          current.dragging = true
          float.getAnimations?.().forEach((animation) => animation.cancel())
          try {
            event.currentTarget.setPointerCapture(event.pointerId)
          } catch {
            // A pointer the browser does not track (a synthetic one): no capture.
          }
        }
        float.style.transform = `translate(${Math.round(dx)}px, ${Math.round(dy)}px) rotate(${(dx * 0.05).toFixed(2)}deg)`
      },
      onPointerUp(_index, event) {
        end(event, false)
      },
      onPointerCancel(_index, event) {
        end(event, true)
      },
    }
  }, [])

  return useMemo(
    () => ({
      gestures,
      lastDragEnd: () => ended.current,
      forget: () => {
        gesture.current = null
      },
    }),
    [gestures],
  )
}
