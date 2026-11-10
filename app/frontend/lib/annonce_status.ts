export const STATUS_INTERVAL_MS = 10_000
export const OWN_BID_QUIET_MS = 5_000

const HOUR_MS = 3_600_000
const SOON_MS = 180_000

export type StatusKind = "update" | "extension" | "milestone" | "end"

export type StatusLine = { text: string; endsAt: string; bidder: boolean }

export type Throttle = { lastSaidAt: number | null; lastText: string; waiting: string | null }

export type Step = { throttle: Throttle; say: string | null; wait: number | null }

export const idle: Throttle = { lastSaidAt: null, lastText: "", waiting: null }

function said(text: string, now: number): Step {
  return { throttle: { lastSaidAt: now, lastText: text, waiting: null }, say: text, wait: null }
}

function ready(throttle: Throttle, now: number): boolean {
  return throttle.lastSaidAt === null || now - throttle.lastSaidAt >= STATUS_INTERVAL_MS
}

function held(throttle: Throttle, text: string, now: number): Step {
  const first = throttle.waiting === null
  const wait = first && throttle.lastSaidAt !== null ? STATUS_INTERVAL_MS - (now - throttle.lastSaidAt) : null
  return { throttle: { ...throttle, waiting: text }, say: null, wait }
}

export function offer(throttle: Throttle, text: string, kind: StatusKind, now: number, reduced: boolean): Step {
  if (text === "") return { throttle, say: null, wait: null }
  if (kind === "end" || kind === "extension") return said(text, now)
  if (kind === "update" && reduced) return { throttle, say: null, wait: null }
  if (kind === "update" && text === throttle.lastText)
    return { throttle: { ...throttle, waiting: null }, say: null, wait: null }
  return ready(throttle, now) ? said(text, now) : held(throttle, text, now)
}

export function flush(throttle: Throttle, now: number): Step {
  return throttle.waiting === null ? { throttle, say: null, wait: null } : said(throttle.waiting, now)
}

export function milestones(endsAt: string, now: number): number[] {
  const end = Date.parse(endsAt)
  if (Number.isNaN(end)) return []
  return [HOUR_MS, SOON_MS].map((before) => end - before - now).filter((delay) => delay > 0)
}

export function readLine(root: ParentNode): StatusLine | null {
  const element = root.querySelector<HTMLElement>("[data-status-text]")
  const { statusText: text, statusEndsAt: endsAt, statusBidder: bidder } = element?.dataset ?? {}
  return text && endsAt ? { text, endsAt, bidder: bidder === "true" } : null
}

export function readOutcome(root: ParentNode): string | null {
  return root.querySelector("#listing-outcome-heading")?.textContent?.trim() || null
}
