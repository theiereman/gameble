// The navigation lock an island holds while it runs (the top bar's back,
// the tab bar, the island's own way back): counted, so nested holders
// release it once, announced through `gameble:navigation-locked`, and
// released if the island unmounts while holding it.
import { useCallback, useEffect, useRef, useState, type RefObject } from "react"
import { dispatchGameble } from "../lib/events"

export type NavigationLock = {
  locked: boolean
  /** How many holders hold the lock now. */
  depth: RefObject<number>
  lock: () => void
  /** Releases one hold; `onReleased` runs once the last one is released. */
  unlock: (onReleased: () => void) => void
}

export function useNavigationLock(): NavigationLock {
  const [locked, setLocked] = useState(false)
  const depth = useRef(0)

  const lock = useCallback(() => {
    if (depth.current++ === 0) {
      setLocked(true)
      dispatchGameble("gameble:navigation-locked", { locked: true })
    }
  }, [])
  const unlock = useCallback((onReleased: () => void) => {
    if (depth.current === 0) return
    if (--depth.current === 0) {
      setLocked(false)
      dispatchGameble("gameble:navigation-locked", { locked: false })
      onReleased()
    }
  }, [])

  useEffect(
    () => () => {
      if (depth.current > 0) {
        depth.current = 0
        dispatchGameble("gameble:navigation-locked", { locked: false })
      }
    },
    [],
  )

  return { locked, depth, lock, unlock }
}
