// The one switch for reduced motion (EXPERIENCE.md, Reduced motion; AD-27),
// read by Stimulus controllers and islands. CSS reads the same two sources:
// the system preference and `html[data-motion=reduced]` (set once the
// player's "Animations réduites" setting exists).
export const REDUCED_MOTION_QUERY = "(prefers-reduced-motion: reduce)"

export function motionReduced(): boolean {
  if (typeof document !== "undefined" && document.documentElement.dataset.motion === "reduced") return true
  return typeof window !== "undefined" && typeof window.matchMedia === "function" && window.matchMedia(REDUCED_MOTION_QUERY).matches
}
