export type TimeLeft = { kind: "days" | "hours" | "minutes" | "under"; days: number; hours: number; minutes: number }

const MINUTE = 60
const HOUR = 3600
const DAY = 86_400

export function timeLeft(seconds: number): TimeLeft {
  if (seconds < MINUTE) return { kind: "under", days: 0, hours: 0, minutes: 0 }
  const whole = Math.floor(seconds / MINUTE)
  if (seconds < HOUR) return { kind: "minutes", days: 0, hours: 0, minutes: whole }
  const hours = Math.floor(whole / 60)
  if (seconds < DAY) return { kind: "hours", days: 0, hours, minutes: whole % 60 }
  return { kind: "days", days: Math.floor(hours / 24), hours: hours % 24, minutes: whole % 60 }
}

// Milliseconds until the minute label changes, or null once it reads "under a minute" and cannot change again.
export function msToNextChange(seconds: number): number | null {
  if (seconds < MINUTE) return null
  return (seconds % MINUTE) * 1000 + 1
}
