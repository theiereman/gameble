export type Approach = "far" | "drawing" | "settled"

export type ApproachStep = { approach: Approach; act: "draw" | "give-up" | "none" }

export function sighted(approach: Approach, near: boolean): ApproachStep {
  if (approach === "far" && near) return { approach: "drawing", act: "draw" }
  if (approach === "drawing" && !near) return { approach: "far", act: "give-up" }
  return { approach, act: "none" }
}

export function drawSettled(approach: Approach): Approach {
  return approach === "drawing" ? "settled" : approach
}

export function nearNow(entries: readonly { isIntersecting: boolean }[]): boolean | undefined {
  return entries.at(-1)?.isIntersecting
}
