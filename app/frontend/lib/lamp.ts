export interface Point {
  x: number
  y: number
}

export interface Size {
  width: number
  height: number
}

export interface LampCard extends Point {
  radius: number
}

export type Radii = readonly [number, number, number]
export type LampMode = "auto" | "manual"

export const RADII_DESKTOP: Radii = [70, 96, 124]
export const RADII_PHONE: Radii = [50, 70, 90]

export const POWER_ON_DELAY_MS = 350
export const POWER_ON_MS = 300
export const POWER_STEPS = 5
export const MANUAL_HOLD_MS = 2500
export const FOUND_HOLD_MS = 1600
export const FOLLOW_RATE = 12
export const SWEEP_RATE = 1.6
export const FOUND_REACH = 0.4
export const SETTLED_DISTANCE = 0.5

const clamp = (value: number, low: number, high: number): number => Math.max(low, Math.min(high, value))

const distance = (from: Point, to: Point): number => Math.hypot(from.x - to.x, from.y - to.y)

export function powerAt(elapsedMs: number): number {
  return Math.round(clamp((elapsedMs - POWER_ON_DELAY_MS) / POWER_ON_MS, 0, 1) * POWER_STEPS) / POWER_STEPS
}

export function scaleRadii(radii: Radii, power: number): Radii {
  return [radii[0] * power, radii[1] * power, radii[2] * power]
}

export function approach(from: number, to: number, dtSeconds: number, rate: number): number {
  return from + (to - from) * (1 - Math.exp(-dtSeconds * rate))
}

export function wanderPoint(area: Size, seconds: number): Point {
  return {
    x: area.width * (0.5 + 0.36 * Math.sin(seconds * 0.45)),
    y: area.height * (0.5 + 0.34 * Math.sin(seconds * 0.71 + 1))
  }
}

export function lampMode(input: { pointerHeld: boolean }): LampMode {
  return input.pointerHeld ? "manual" : "auto"
}

export function pointerHeld(input: { inside: boolean; movedAt: number; now: number }): boolean {
  return input.inside && input.now - input.movedAt < MANUAL_HOLD_MS
}

export interface LampInput {
  now: number
  dt: number
  pointer: Point | null
  pointerHeld: boolean
}

export interface LampFrame {
  x: number
  y: number
  power: number
  radii: Radii
  mode: LampMode
  lit: boolean[]
  found: boolean[]
  foundCount: number
  settled: boolean
}

export class Lamp {
  private x = 0
  private y = 0
  private found: boolean[]
  private aim = -1
  private holdUntil = 0
  private wanderSeconds = 0
  private lastFound = -1

  constructor(
    private cards: readonly LampCard[],
    private area: Size,
    private readonly radii: Radii,
    private readonly startedAt: number
  ) {
    this.found = this.cards.map(() => false)
    this.rest()
  }

  remeasure(cards: readonly LampCard[], area: Size): void {
    const sameCards = cards.length === this.cards.length
    this.x = this.area.width > 0 ? (this.x * area.width) / this.area.width : area.width / 2
    this.y = this.area.height > 0 ? (this.y * area.height) / this.area.height : area.height / 2
    this.cards = cards
    this.area = area
    if (!sameCards) {
      this.found = cards.map(() => false)
      this.aim = -1
      this.lastFound = -1
      this.rest()
    }
  }

  advance(input: LampInput): LampFrame {
    const power = powerAt(input.now - this.startedAt)
    const mode = lampMode({ pointerHeld: input.pointerHeld })
    const radii = scaleRadii(this.radii, power)

    this.travel(input, mode, power)

    const here = { x: this.x, y: this.y }
    const lit = this.cards.map((card) => power > 0 && distance(here, card) < radii[1] + card.radius)
    this.cards.forEach((card, index) => {
      if (this.found[index] || power < 1 || distance(here, card) >= radii[0] + card.radius * FOUND_REACH) return
      this.found[index] = true
      this.lastFound = index
      this.holdUntil = input.now + FOUND_HOLD_MS
    })

    return { x: this.x, y: this.y, power, radii, mode, lit, found: [...this.found], foundCount: this.foundCount(), settled: this.settled(mode) }
  }

  private foundCount(): number {
    return this.found.filter(Boolean).length
  }

  private allFound(): boolean {
    return this.cards.length > 0 && this.foundCount() === this.cards.length
  }

  private rest(): void {
    const first = this.cards[0]
    this.x = first ? first.x : this.area.width / 2
    this.y = first ? first.y : this.area.height / 2
  }

  private travel(input: LampInput, mode: LampMode, power: number): void {
    const target = mode === "manual" && input.pointer ? input.pointer : this.sweepTarget(input)
    if (power === 0) return
    const rate = mode === "manual" ? FOLLOW_RATE : SWEEP_RATE
    this.x = approach(this.x, target.x, input.dt, rate)
    this.y = approach(this.y, target.y, input.dt, rate)
  }

  private sweepTarget(input: LampInput): Point {
    if (this.allFound()) return this.cards[this.lastFound] ?? this.cards[this.cards.length - 1]
    if (this.lastFound >= 0 && input.now <= this.holdUntil) return this.cards[this.lastFound]
    if (this.aim < 0 || this.found[this.aim]) this.aim = this.found.indexOf(false)
    return this.cards[this.aim] ?? wanderPoint(this.area, (this.wanderSeconds += input.dt))
  }

  private settled(mode: LampMode): boolean {
    if (mode !== "auto" || !this.allFound()) return false
    const last = this.cards[this.lastFound]
    return last !== undefined && distance({ x: this.x, y: this.y }, last) < SETTLED_DISTANCE
  }
}
