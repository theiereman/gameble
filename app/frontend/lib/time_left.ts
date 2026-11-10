export type TimeLeft = { kind: "hours" | "minutes" | "under"; hours: number; minutes: number }

const MINUTE = 60
const HOUR = 3600

export function timeLeft(seconds: number): TimeLeft {
  if (seconds < MINUTE) return { kind: "under", hours: 0, minutes: 0 }
  const whole = Math.floor(seconds / MINUTE)
  if (seconds < HOUR) return { kind: "minutes", hours: 0, minutes: whole }
  return { kind: "hours", hours: Math.floor(whole / 60), minutes: whole % 60 }
}

// Milliseconds until the minute label changes, or null once it reads "under a minute" and cannot change again.
export function msToNextChange(seconds: number): number | null {
  if (seconds < MINUTE) return null
  return (seconds % MINUTE) * 1000 + 1
}
