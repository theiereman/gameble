import { secondsUntil } from "./booster_clock"

export const ALERT_SECONDS = 10

export type DuelClock = { readonly total: number; readonly announced: boolean }

export function startClock(deadline: string, serverTime: string): DuelClock | null {
  const seconds = secondsUntil(deadline, serverTime)
  return seconds === null ? null : { total: seconds, announced: false }
}

export function secondsLeft(clock: DuelClock, elapsedMs: number): number {
  return Math.max(0, Math.ceil(clock.total - elapsedMs / 1000))
}

export function inAlert(seconds: number): boolean {
  return seconds <= ALERT_SECONDS
}

export function shouldAnnounce(clock: DuelClock, seconds: number): boolean {
  return !clock.announced && seconds > 0 && inAlert(seconds)
}

export function clockText(template: string, seconds: number): string {
  return template.replace("{seconds}", String(seconds))
}
