export const REDUCED_MOTION_QUERY = "(prefers-reduced-motion: reduce)"

export function motionReduced(): boolean {
  const forced = typeof document !== "undefined" ? document.documentElement.dataset.motion : undefined
  if (forced === "reduced") return true
  if (forced === "full") return false
  return (
    typeof window !== "undefined" &&
    typeof window.matchMedia === "function" &&
    window.matchMedia(REDUCED_MOTION_QUERY).matches
  )
}

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
