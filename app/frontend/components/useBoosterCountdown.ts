// The booster screen's countdown to the next booster: whole seconds,
// paused while the page is hidden, and the screen refreshed a second after
// it reaches zero so the new booster can be opened.
import { useEffect, useRef, useState } from "react"
import { secondsUntil } from "../lib/booster"
import { refreshPage } from "../lib/booster_page"

/** A second after the countdown's zero: the new booster has had time to arrive. */
const REFRESH_AFTER_ZERO = 1000

/** Whole seconds to the next booster, counting down, paused while the page is hidden. */
export function useCountdown(nextAvailableAt: string | null, serverTime: string): number | null {
  const [left, setLeft] = useState(() => secondsUntil(nextAvailableAt, serverTime))
  useEffect(() => {
    const total = secondsUntil(nextAvailableAt, serverTime)
    setLeft(total)
    if (total === null) return
    const deadline = performance.now() + total * 1000
    let timer: number | undefined
    const tick = () => {
      timer = undefined
      const ms = deadline - performance.now()
      const seconds = Math.max(0, Math.ceil(ms / 1000))
      setLeft(seconds)
      if (seconds > 0 && !document.hidden) timer = window.setTimeout(tick, Math.max(16, ms - (seconds - 1) * 1000))
    }
    const onVisibility = () => {
      if (document.hidden) {
        window.clearTimeout(timer)
        timer = undefined
      } else if (timer === undefined) {
        tick()
      }
    }
    tick()
    document.addEventListener("visibilitychange", onVisibility)
    return () => {
      window.clearTimeout(timer)
      document.removeEventListener("visibilitychange", onVisibility)
    }
  }, [nextAvailableAt, serverTime])
  return left
}

/**
 * The countdown reaching zero while the page is shown: a second later the
 * screen refreshes, so the new booster can be opened, but only if
 * `canRefresh` says so then (the island idle). A clock already at zero when
 * the page drew never refreshes it.
 */
export function useRefreshAtZero(left: number | null, canRefresh: () => boolean): void {
  const latest = useRef(canRefresh)
  latest.current = canRefresh
  const previousLeft = useRef(left)
  useEffect(() => {
    const before = previousLeft.current
    previousLeft.current = left
    if (!(before !== null && before > 0 && left === 0)) return
    const timer = window.setTimeout(() => {
      if (latest.current()) refreshPage()
    }, REFRESH_AFTER_ZERO)
    return () => window.clearTimeout(timer)
  }, [left])
}
