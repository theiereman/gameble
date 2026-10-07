import type { Point } from "./arc"

export const SWAP_MS = 750
export const SWAP_CROSSFADE_MS = 200
export const SWAP_LIFT = 90
export const SWAP_SAMPLES = 12
export const SWAP_LANDING = 0.82
export const SWAP_BURST_AT = 0.45

const easeInOut = (t: number): number => (t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2)

const tenth = (value: number): number => Math.round(value * 10) / 10 || 0

export function swapPath(offset: Point, lift = SWAP_LIFT, samples = SWAP_SAMPLES): Point[] {
  const length = Math.hypot(offset.x, offset.y)
  const normal = length === 0 ? { x: 0, y: 0 } : { x: -offset.y / length, y: offset.x / length }
  const control = { x: offset.x / 2 - normal.x * lift, y: offset.y / 2 - normal.y * lift }
  return Array.from({ length: samples + 1 }, (_, i) => {
    const t = easeInOut(i / samples)
    const u = 1 - t
    return { x: tenth(u * u * offset.x + 2 * u * t * control.x), y: tenth(u * u * offset.y + 2 * u * t * control.y) }
  })
}

export function swapKeyframes(offset: Point, lift = SWAP_LIFT, samples = SWAP_SAMPLES): Keyframe[] {
  const flight = swapPath(offset, lift, samples).map((point, i) => ({
    offset: Math.round(((SWAP_LANDING * i) / samples) * 1000) / 1000,
    transform: `translate(${point.x}px, ${point.y}px)`,
  }))
  return [
    ...flight,
    { offset: 0.9, transform: "translate(0px, 0px) scale(1.12, 0.86)" },
    { offset: 1, transform: "translate(0px, 0px) scale(1, 1)" },
  ]
}

export function confettiDirections(count: number, distance: number): Point[] {
  return Array.from({ length: count }, (_, i) => {
    const angle = (2 * Math.PI * i) / count
    const reach = distance * (i % 2 === 0 ? 1 : 0.65)
    return { x: tenth(Math.cos(angle) * reach), y: tenth(Math.sin(angle) * reach) }
  })
}
