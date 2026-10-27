// A Légendaire's glitter: flakes on the varnish that flash when the card's eased tilt faces their normal and otherwise twinkle in groups.
// The field is drawn from the card's seed, so a card shows the same flakes on every render.

export type FlakeColour = "white" | "gold" | "violet" | "blue"

export type Flake = {
  x: number
  y: number
  nx: number
  ny: number
  cross: boolean
  colour: FlakeColour
  group: number
}

export type Twinkle = { period: number; delay: number }

export type FlakeField = { groups: Twinkle[]; flakes: Flake[] }

export type Glitter = { update(dx: number, dy: number): void; detach(): void }

/** The seed of a card that names none. */
export const DEFAULT_SEED = 20261013
/** How many flakes cover a 200 × 300 px card; a card of another size gets as many per area. */
export const FLAKES_PER_CARD = 28
/** How many groups a face's flakes twinkle in, one animation each. */
export const TWINKLE_GROUPS = 3
/** How far, in tilt, a flake keeps flashing around its normal. */
export const FLASH_REACH = 0.14
/** How bright a flash marks its flake as flashing. */
export const FLASH_THRESHOLD = 0.25

const REFERENCE_AREA = 200 * 300
const EDGE = 8
const ART_PIXEL = 2
const NORMAL_SPREAD = 0.9
const CROSS_SHARE = 0.35
const COLOURS: readonly FlakeColour[] = ["white", "white", "white", "gold", "gold", "violet", "blue"]

/** A seeded generator of numbers in [0, 1) (mulberry32). */
function randomFrom(seed: number): () => number {
  let state = seed | 0
  return () => {
    state = (state + 0x6d2b79f5) | 0
    let t = Math.imul(state ^ (state >>> 15), 1 | state)
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

/** The seed a face names in `data-glitter-seed`, or DEFAULT_SEED when it names none. */
export function glitterSeed(value: string | undefined): number {
  const seed = Number.parseInt(value ?? "", 10)
  return Number.isNaN(seed) ? DEFAULT_SEED : seed
}

const onPixelGrid = (value: number) => Math.round(value / ART_PIXEL) * ART_PIXEL

/** The flakes of a card `width` × `height` px and the rhythms of their twinkle groups, the same for the same seed. */
export function flakeField(seed: number, width: number, height: number): FlakeField {
  const random = randomFrom(seed)
  const groups = Array.from({ length: TWINKLE_GROUPS }, () => ({
    period: 2.4 + random() * 3.6,
    delay: -random() * 6,
  }))
  const count = Math.round((FLAKES_PER_CARD * width * height) / REFERENCE_AREA)
  const flakes = Array.from({ length: count }, () => ({
    x: onPixelGrid(EDGE + random() * (width - 2 * EDGE)),
    y: onPixelGrid(EDGE + random() * (height - 2 * EDGE)),
    nx: (random() - 0.5) * NORMAL_SPREAD,
    ny: (random() - 0.5) * NORMAL_SPREAD,
    cross: random() < CROSS_SHARE,
    colour: COLOURS[Math.floor(random() * COLOURS.length)],
    group: Math.floor(random() * TWINKLE_GROUPS),
  }))
  return { groups, flakes }
}

/** How brightly `flake` flashes on a card tilted toward (`dx`, `dy`): 1 facing its normal, 0 beyond FLASH_REACH. */
export function flakeFlash(flake: Pick<Flake, "nx" | "ny">, dx: number, dy: number): number {
  return Math.max(0, 1 - Math.hypot(dx - flake.nx, dy - flake.ny) / FLASH_REACH) ** 1.5
}

/** A flake's brightness for a flash, in quarter steps from 0.5 to 1. */
export function flakeLevel(flash: number): number {
  return 0.5 + (0.5 * Math.round(flash * 4)) / 4
}

function flakeElement(document: Document, flake: Flake): HTMLElement {
  const element = document.createElement("span")
  element.className = `card__flake card__flake--${flake.colour}${flake.cross ? " card__flake--cross" : ""}`
  element.style.setProperty("left", `${flake.x}px`)
  element.style.setProperty("top", `${flake.y}px`)
  const glint = document.createElement("span")
  glint.className = "card__flake-glint"
  element.append(glint)
  return element
}

function groupElement(document: Document, twinkle: Twinkle): HTMLElement {
  const element = document.createElement("span")
  element.className = "card__flake-group"
  element.style.setProperty("--flake-period", `${twinkle.period}s`)
  element.style.setProperty("--flake-delay", `${twinkle.delay}s`)
  return element
}

/** Draws the flakes of a card `width` × `height` px into `container`, each in its twinkle group; returns how to light them and to take them away. */
export function attachGlitter(container: HTMLElement, { seed, width, height }: { seed: number; width: number; height: number }): Glitter {
  const document = container.ownerDocument
  const field = flakeField(seed, width, height)
  const groups = field.groups.map((twinkle) => groupElement(document, twinkle))
  const flakes = field.flakes.map((flake) => ({ flake, element: flakeElement(document, flake), group: groups[flake.group], flashing: false, level: "" }))
  for (const { element, group } of flakes) group.append(element)
  container.replaceChildren(...groups)

  return {
    update(dx: number, dy: number) {
      for (const entry of flakes) {
        const flash = flakeFlash(entry.flake, dx, dy)
        const flashing = flash > FLASH_THRESHOLD
        if (flashing !== entry.flashing) {
          entry.element.toggleAttribute("data-flash", flashing)
          // A group's opacity dims its whole subtree, so a flashing flake waits outside it.
          const parent = flashing ? container : entry.group
          parent.append(entry.element)
          entry.flashing = flashing
        }
        const level = `${flakeLevel(flash)}`
        if (level === entry.level) continue
        entry.element.style.setProperty("--flake-level", level)
        entry.level = level
      }
    },
    detach() {
      container.replaceChildren()
    },
  }
}
