// The one switch for reduced motion, read by Stimulus controllers. CSS
// reads the same two sources: `html[data-motion]`, which the server
// renders from the player's "Animations réduites" setting, else its
// cookie (ApplicationController#forced_motion), and, when that attribute is
// absent, the system preference.
export const REDUCED_MOTION_QUERY = "(prefers-reduced-motion: reduce)"

// Whether motion is reduced right now: read at the moment of use, never
// cached, so a change of the attribute or of the system preference is seen
// by the next call.
export function motionReduced(): boolean {
  const forced = typeof document !== "undefined" ? document.documentElement.dataset.motion : undefined
  if (forced === "reduced") return true
  if (forced === "full") return false
  return typeof window !== "undefined" && typeof window.matchMedia === "function" && window.matchMedia(REDUCED_MOTION_QUERY).matches
}

// Calls `listener` with the new state whenever the switch flips, either
// source (the `data-motion` attribute or the system preference). For what
// is already running when the switch flips (a transition, a loop a
// controller started). Returns the function that stops listening, for a
// controller's disconnect.
export function onMotionChange(listener: (reduced: boolean) => void): () => void {
  let last = motionReduced()
  const check = (): void => {
    const now = motionReduced()
    if (now === last) return
    last = now
    listener(now)
  }

  const stops: Array<() => void> = []
  if (typeof document !== "undefined" && typeof MutationObserver === "function") {
    const observer = new MutationObserver(check)
    observer.observe(document.documentElement, { attributes: true, attributeFilter: ["data-motion"] })
    stops.push(() => observer.disconnect())
  }
  if (typeof window !== "undefined" && typeof window.matchMedia === "function") {
    const query = window.matchMedia(REDUCED_MOTION_QUERY)
    query.addEventListener("change", check)
    stops.push(() => query.removeEventListener("change", check))
  }
  return () => stops.forEach((stop) => stop())
}
