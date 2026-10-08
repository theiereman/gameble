// The timers of an island's choreography, gone with the island: `wait`
// resolves after a delay, `later` runs an action after one, and once the
// island unmounts every pending timer is cleared and `disposed` is set, so
// a running sequence stops where it is.
import { useCallback, useEffect, useRef, type RefObject } from "react"

export type IslandTimers = {
  /** Set once the island has unmounted. */
  disposed: RefObject<boolean>
  wait: (ms: number) => Promise<void>
  later: (ms: number, action: () => void) => void
}

export function useIslandTimers(): IslandTimers {
  const disposed = useRef(false)
  const timers = useRef(new Set<number>())

  const wait = useCallback(
    (ms: number) =>
      new Promise<void>((resolve) => {
        const timer = window.setTimeout(() => {
          timers.current.delete(timer)
          // Unmounted: the sequence stops here, its promise left pending.
          if (!disposed.current) resolve()
        }, Math.max(0, ms))
        timers.current.add(timer)
      }),
    [],
  )
  const later = useCallback(
    (ms: number, action: () => void) => {
      void wait(ms).then(action)
    },
    [wait],
  )

  useEffect(() => {
    disposed.current = false
    const pending = timers.current
    return () => {
      disposed.current = true
      pending.forEach((timer) => window.clearTimeout(timer))
      pending.clear()
    }
  }, [])

  return { disposed, wait, later }
}
