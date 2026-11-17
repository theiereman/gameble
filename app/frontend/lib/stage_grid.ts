export type Pointer = Readonly<{ x: number; y: number; pull: number }>

export const GRID_STEP = 24
export const HALO_RADIUS = 380
export const POINTER_GLOW_RADIUS = 360
export const HALO_SPAN = 2 * 16 * GRID_STEP
export const FOLLOW = 0.25
export const EASE = 0.12

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

export function haloOriginOnGrid(at: number): number {
  return Math.round((at - HALO_SPAN / 2) / GRID_STEP) * GRID_STEP
}

export function gridLines(from: number, to: number): number[] {
  const lines: number[] = []
  for (let at = Math.ceil(from / GRID_STEP) * GRID_STEP; at <= to; at += GRID_STEP) lines.push(at)
  return lines
}
