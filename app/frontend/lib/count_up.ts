export const COUNT_UP_MS = 900

export function countedAt(amount: number, elapsed: number, duration = COUNT_UP_MS): number {
  if (elapsed >= duration) return amount
  const progress = Math.max(elapsed, 0) / duration
  return Math.floor(amount * (1 - (1 - progress) ** 3))
}
