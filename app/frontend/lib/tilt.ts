// Eases a card face toward the pointer's tilt and writes it, with the reflection that rides it, as custom properties for styles/card.css.
// A held finger tilts it (the click after is swallowed); a drag scrolls instead; reduced motion does nothing.
import { motionReduced } from "./motion"

export type Tilt = { rx: number; ry: number }
export type Box = { left: number; top: number; width: number; height: number }
export type Reflection = { strip: number; fresnel: number; horizon: number; hue: number }

/** The share of the remaining way covered each frame while a pointer drives the card. */
export const EASE_ENTER = 0.08
/** The share of the remaining way covered each frame once it lets go. */
export const EASE_LEAVE = 0.075
/** How long a finger stays still before it tilts the card. */
export const HOLD_MS = 150
/** How far a finger moves, in px, before the hold gives way to a scroll. */
export const TOUCH_SLOP = 6
/** How far the reflection slides for a given tilt. */
export const TRAVEL = 2.5

/** Close enough to snap, in degrees. */
const SNAP_DEGREES = 0.01
/** A card face's width over its height, until one is measured. */
const CARD_ASPECT = 2 / 3

export const REST: Tilt = { rx: 0, ry: 0 }

export const TILT_PROPERTIES = [
  "--tilt-rx",
  "--tilt-ry",
  "--reflection-strip",
  "--reflection-fresnel",
  "--reflection-horizon",
  "--reflection-hue",
] as const

const unit = (value: number) => Math.min(1, Math.max(0, value))

const withoutNegativeZero = (value: number) => value + 0

/** The tilt for a pointer at (`x`, `y`) over a card at `rect`, up to `max` degrees at an edge. */
export function tiltTarget(x: number, y: number, rect: Box, max: number): Tilt {
  const px = rect.width > 0 ? unit((x - rect.left) / rect.width) : 0.5
  const py = rect.height > 0 ? unit((y - rect.top) / rect.height) : 0.5
  return { rx: withoutNegativeZero(-(py - 0.5) * 2 * max), ry: withoutNegativeZero((px - 0.5) * 2 * max) }
}

/** The reflection of a card tilted toward (`dx`, `dy`), each from -0.5 to 0.5, on a card `aspect` times as wide as tall. */
export function reflection(dx: number, dy: number, aspect: number): Reflection {
  const tilt2 = Math.min(1, (dx * dx + dy * dy) / 0.5)
  return {
    strip: withoutNegativeZero(30 - dx * TRAVEL * 55 - dy * TRAVEL * 30),
    fresnel: withoutNegativeZero(0.8 + 0.6 * tilt2),
    horizon: withoutNegativeZero(-0.32 - dy * TRAVEL - 0.2 * dx * TRAVEL * aspect),
    hue: withoutNegativeZero(50 + (dx * 0.6 + dy * 0.3) * TRAVEL * 120),
  }
}

export const REST_REFLECTION = reflection(0, 0, CARD_ASPECT)

/** Where a card showing `tilt`, out of `max` degrees at an edge, leans: `dx` across and `dy` down, from -0.5 to 0.5. */
export function leaning(tilt: Tilt, max: number): { dx: number; dy: number } {
  return { dx: withoutNegativeZero(tilt.ry / (2 * max)), dy: withoutNegativeZero(-tilt.rx / (2 * max)) }
}

/** The reflection of a card showing `tilt`, out of `max` degrees at an edge. */
export function reflectionOf(tilt: Tilt, max: number, aspect: number): Reflection {
  const { dx, dy } = leaning(tilt, max)
  return reflection(dx, dy, aspect)
}

const settled = (a: Tilt, b: Tilt) => Math.abs(a.rx - b.rx) < SNAP_DEGREES && Math.abs(a.ry - b.ry) < SNAP_DEGREES

const atRest = (tilt: Tilt) => settled(tilt, REST)

/** One frame of easing from `current` toward `target`, snapping onto it when close. */
export function easeToward(current: Tilt, target: Tilt, factor: number): Tilt {
  const next = {
    rx: current.rx + (target.rx - current.rx) * factor,
    ry: current.ry + (target.ry - current.ry) * factor,
  }
  return settled(next, target) ? { ...target } : next
}

/** The card's untransformed layout box, measured once when a pointer starts driving it so its own tilt never moves its target. */
function layoutBox(element: HTMLElement): Box {
  const rect = element.getBoundingClientRect()
  const width = element.offsetWidth || rect.width
  const height = element.offsetHeight || rect.height
  return { left: rect.left + rect.width / 2 - width / 2, top: rect.top + rect.height / 2 - height / 2, width, height }
}

type Hold = { id: number; startX: number; startY: number; x: number; y: number; timer: ReturnType<typeof setTimeout> }

/** Tilts `element` under the pointer; `onTilt` hears the eased tilt each frame, (0, 0) once at rest or detached. Returns the undo. */
export function attachTilt(
  element: HTMLElement,
  { max, onTilt }: { max: number; onTilt?: (dx: number, dy: number) => void },
): () => void {
  let current = REST
  let target = REST
  let frame: number | null = null
  let driver: { id: number; touch: boolean } | null = null
  let hold: Hold | null = null
  let box: Box | null = null
  let aspect = CARD_ASPECT
  let swallowClick = false

  const clear = () => {
    for (const property of TILT_PROPERTIES) element.style.removeProperty(property)
    delete element.dataset.tilt
    delete element.dataset.tilting
    onTilt?.(0, 0)
  }

  const write = () => {
    const { dx, dy } = leaning(current, max)
    const { strip, fresnel, horizon, hue } = reflection(dx, dy, aspect)
    element.style.setProperty("--tilt-rx", `${current.rx}deg`)
    element.style.setProperty("--tilt-ry", `${current.ry}deg`)
    element.style.setProperty("--reflection-strip", `${strip}%`)
    element.style.setProperty("--reflection-fresnel", `${fresnel}`)
    element.style.setProperty("--reflection-horizon", `${horizon}`)
    element.style.setProperty("--reflection-hue", `${hue}%`)
    onTilt?.(dx, dy)
  }

  const step = () => {
    frame = null
    current = easeToward(current, target, driver === null ? EASE_LEAVE : EASE_ENTER)
    const still = settled(current, target)
    if (still && driver === null) {
      clear()
      return
    }
    write()
    if (still && atRest(target)) delete element.dataset.tilt
    else element.dataset.tilt = still ? "held" : "moving"
    if (!still) frame = requestAnimationFrame(step)
  }

  const schedule = () => {
    if (frame === null) frame = requestAnimationFrame(step)
  }

  const measure = () => {
    const measured = layoutBox(element)
    if (measured.width > 0 && measured.height > 0) aspect = measured.width / measured.height
    return measured
  }

  const aim = (x: number, y: number) => {
    box ??= measure()
    target = tiltTarget(x, y, box, max)
    schedule()
  }

  const drive = (id: number, touch: boolean) => {
    driver = { id, touch }
    element.dataset.tilting = ""
  }

  const release = () => {
    driver = null
    box = null
    delete element.dataset.tilting
    target = REST
    schedule()
  }

  const cancelHold = () => {
    if (hold) clearTimeout(hold.timer)
    hold = null
  }

  const onPointerDown = (event: PointerEvent) => {
    swallowClick = false
    if (event.pointerType !== "touch" || driver !== null || hold !== null) return
    const id = event.pointerId
    const timer = setTimeout(() => {
      const held = hold
      hold = null
      if (!held || motionReduced()) return
      drive(id, true)
      aim(held.x, held.y)
    }, HOLD_MS)
    hold = { id, startX: event.clientX, startY: event.clientY, x: event.clientX, y: event.clientY, timer }
  }

  const onPointerMove = (event: PointerEvent) => {
    if (event.pointerType === "touch") {
      if (hold?.id === event.pointerId) {
        if (Math.hypot(event.clientX - hold.startX, event.clientY - hold.startY) > TOUCH_SLOP) cancelHold()
        else Object.assign(hold, { x: event.clientX, y: event.clientY })
        return
      }
    } else if (driver === null) {
      if (motionReduced()) return
      drive(event.pointerId, false)
    }
    if (driver?.id === event.pointerId) aim(event.clientX, event.clientY)
  }

  const onPointerLeave = (event: PointerEvent) => {
    if (event.pointerType !== "touch" && driver?.id === event.pointerId) release()
  }

  const onPointerEnd = (event: PointerEvent) => {
    if (hold?.id === event.pointerId) cancelHold()
    if (driver?.id === event.pointerId && (driver.touch || event.type === "pointercancel")) {
      swallowClick = driver.touch && event.type === "pointerup"
      release()
    }
  }

  const onClick = (event: Event) => {
    if (!swallowClick) return
    swallowClick = false
    event.preventDefault()
    event.stopPropagation()
  }

  const onTouchMove = (event: TouchEvent) => {
    if (driver?.touch && event.cancelable) event.preventDefault()
  }

  const onContextMenu = (event: Event) => {
    if (driver?.touch) event.preventDefault()
  }

  const onScroll = () => {
    box = null
  }

  const view = element.ownerDocument?.defaultView
  view?.addEventListener("scroll", onScroll, { capture: true, passive: true })
  element.addEventListener("pointerdown", onPointerDown)
  element.addEventListener("pointermove", onPointerMove)
  element.addEventListener("pointerleave", onPointerLeave)
  element.addEventListener("pointerup", onPointerEnd)
  element.addEventListener("pointercancel", onPointerEnd)
  element.addEventListener("touchmove", onTouchMove, { passive: false })
  element.addEventListener("click", onClick, { capture: true })
  element.addEventListener("contextmenu", onContextMenu)

  return () => {
    view?.removeEventListener("scroll", onScroll, { capture: true })
    element.removeEventListener("pointerdown", onPointerDown)
    element.removeEventListener("pointermove", onPointerMove)
    element.removeEventListener("pointerleave", onPointerLeave)
    element.removeEventListener("pointerup", onPointerEnd)
    element.removeEventListener("pointercancel", onPointerEnd)
    element.removeEventListener("touchmove", onTouchMove)
    element.removeEventListener("click", onClick, { capture: true })
    element.removeEventListener("contextmenu", onContextMenu)
    cancelHold()
    if (frame !== null) cancelAnimationFrame(frame)
    frame = null
    driver = null
    box = null
    current = target = REST
    clear()
  }
}
