export function litSegments(value: number, max: number, segments: number): number {
  if (max <= 0) return 0
  return Math.floor((Math.min(Math.max(value, 0), max) * segments) / max)
}
