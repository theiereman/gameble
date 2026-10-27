export function formatClock(seconds: number): string {
  const whole = Math.max(0, Math.ceil(seconds))
  const hours = Math.floor(whole / 3600)
  const minutes = Math.floor((whole % 3600) / 60)
  const rest = whole % 60
  const pad = (value: number) => String(value).padStart(2, "0")
  return hours > 0 ? `${hours}:${pad(minutes)}:${pad(rest)}` : `${pad(minutes)}:${pad(rest)}`
}

export function formatDailyClock(seconds: number): string {
  const whole = Math.max(0, Math.ceil(seconds))
  const pad = (value: number) => String(value).padStart(2, "0")
  return `${pad(Math.floor(whole / 3600))}:${pad(Math.floor((whole % 3600) / 60))}:${pad(whole % 60)}`
}

export function secondsUntil(nextAvailableAt: string | null, serverTime: string): number | null {
  if (nextAvailableAt === null) return null
  const left = Date.parse(nextAvailableAt) - Date.parse(serverTime)
  return Number.isNaN(left) ? null : Math.max(0, Math.ceil(left / 1000))
}
