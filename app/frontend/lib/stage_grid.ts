export type Point = readonly [number, number]

export type Pointer = Readonly<{ x: number; y: number; pull: number }>

export const GRID_STEP = 24
export const SAMPLE_STEP = 8
export const WARP_SPREAD = 300
export const WARP_DEPTH = 10
export const HALO_RADIUS = 380
export const FOLLOW = 0.25
export const EASE = 0.12

// The grid bulges away from the pointer: a wide, shallow Gaussian, flat at the pointer itself.
export function warp([x, y]: Point, { x: px, y: py, pull }: Pointer): Point {
  if (pull < 0.001) return [x, y]
  const dx = px - x
  const dy = py - y
  const distanceSquared = dx * dx + dy * dy
  const distance = Math.sqrt(distanceSquared) || 1
  const strength = pull * Math.exp(-distanceSquared / (2 * WARP_SPREAD * WARP_SPREAD))
  const shift = WARP_DEPTH * strength * Math.min(1, distance / 60)
  return [x - (dx / distance) * shift, y - (dy / distance) * shift]
}

export function approach(from: number, to: number, rate: number): number {
  return from + (to - from) * rate
}

export function settled(pointer: Pointer, target: Pointer): boolean {
  return Math.abs(target.pull - pointer.pull) <= 0.002 && Math.hypot(target.x - pointer.x, target.y - pointer.y) <= 0.3
}

export function translucent(hex: string, alpha: number): string {
  const value = hex.trim().replace("#", "")
  const channel = (index: number) => parseInt(value.slice(index, index + 2), 16)
  return `rgba(${channel(0)}, ${channel(2)}, ${channel(4)}, ${alpha})`
}
