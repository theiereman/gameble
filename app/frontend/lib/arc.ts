export type Point = { x: number; y: number }

export const ARC_SAMPLES = 16
export const ARC_LIFT = 70

const easeOut = (t: number): number => 1 - Math.pow(1 - t, 3)

export function arcPoints(from: Point, to: Point, samples = ARC_SAMPLES, lift = ARC_LIFT): Point[] {
  const control = { x: (from.x + to.x) / 2, y: Math.min(from.y, to.y) - lift }
  return Array.from({ length: samples + 1 }, (_, i) => {
    const t = easeOut(i / samples)
    const u = 1 - t
    return {
      x: u * u * from.x + 2 * u * t * control.x + t * t * to.x,
      y: u * u * from.y + 2 * u * t * control.y + t * t * to.y,
    }
  })
}
