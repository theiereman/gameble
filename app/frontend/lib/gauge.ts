export function litSegments(value: number, max: number, segments: number): number {
  if (max <= 0) return 0
  return Math.floor((Math.min(Math.max(value, 0), max) * segments) / max)
}

export function segmentSteps(from: number, to: number): number[] {
  const step = from > to ? -1 : 1
  const steps = [from]
  for (let lit = from; lit !== to;) steps.push((lit += step))
  return steps
}
