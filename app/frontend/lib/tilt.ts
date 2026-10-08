// A card face's tilt under the pointer, and the glare that follows it
// (DESIGN.md, Rarity effects; EXPERIENCE.md, Implementation notes; AD-27).
// The face eases toward its target in animation frames and writes it as
// custom properties the stylesheet reads (styles/card.css):
//   --tilt-rx, --tilt-ry    the rotation, in degrees
//   --glare-dx, --glare-dy  the glare's offset from the card's centre, in px
// and marks the face:
//   data-tilting            while a pointer drives it
//   data-tilt="moving"      while it eases
//   data-tilt="held"        once settled on a target other than rest
// Everything is removed once it is back at rest. A mouse or pen tilts it
// as it moves over it; a finger held still for HOLD_MS tilts it until
// released (the click that follows is swallowed, so a card in a link does
// not open), and a drag before then scrolls the page. Under reduced motion
// (motionReduced() when a pointer starts) nothing happens.
import { motionReduced } from "./motion"

export type Tilt = { rx: number; ry: number; glareDx: number; glareDy: number }
export type Box = { left: number; top: number; width: number; height: number }

/** The share of the remaining way covered each frame. */
export const EASE = 0.16
/** How long a finger stays still before it tilts the card. */
export const HOLD_MS = 150
/** How far a finger moves, in px, before the hold gives way to a scroll. */
export const TOUCH_SLOP = 6

/** Close enough to snap: in degrees, then in px. */
const SNAP_DEGREES = 0.01
const SNAP_PIXELS = 0.1

export const REST: Tilt = { rx: 0, ry: 0, glareDx: 0, glareDy: 0 }

const PROPERTIES = ["--tilt-rx", "--tilt-ry", "--glare-dx", "--glare-dy"] as const

const unit = (value: number) => Math.min(1, Math.max(0, value))

/**
 * The tilt for a pointer at (`x`, `y`) over a card laid out at `rect`: the
 * side under the pointer goes down, up to `max` degrees at an edge
 * (EXPERIENCE.md, Motion: about 10°, 16° in the booster); the glare's
 * centre sits under the pointer.
 */
export function tiltTarget(x: number, y: number, rect: Box, max: number): Tilt {
  const px = rect.width > 0 ? unit((x - rect.left) / rect.width) : 0.5
  const py = rect.height > 0 ? unit((y - rect.top) / rect.height) : 0.5
  return {
    rx: -(py - 0.5) * 2 * max + 0,
    ry: (px - 0.5) * 2 * max + 0,
    glareDx: (px - 0.5) * rect.width + 0,
    glareDy: (py - 0.5) * rect.height + 0,
  }
}

const settled = (a: Tilt, b: Tilt) =>
  Math.abs(a.rx - b.rx) < SNAP_DEGREES &&
  Math.abs(a.ry - b.ry) < SNAP_DEGREES &&
  Math.abs(a.glareDx - b.glareDx) < SNAP_PIXELS &&
  Math.abs(a.glareDy - b.glareDy) < SNAP_PIXELS

const atRest = (tilt: Tilt) => settled(tilt, REST)

/** One frame of easing from `current` toward `target`, snapping onto it when close. */
export function easeToward(current: Tilt, target: Tilt, factor = EASE): Tilt {
  const next = {
    rx: current.rx + (target.rx - current.rx) * factor,
    ry: current.ry + (target.ry - current.ry) * factor,
    glareDx: current.glareDx + (target.glareDx - current.glareDx) * factor,
    glareDy: current.glareDy + (target.glareDy - current.glareDy) * factor,
  }
  return settled(next, target) ? { ...target } : next
}

/**
 * The card's layout box: its untransformed size around the centre of what
 * the screen shows. Measured once when a pointer starts driving it (the
 * card then at rest, or nearly), and kept until it lets go or the page
 * scrolls, so the card's own tilt never moves the target it aims for.
 */
function layoutBox(element: HTMLElement): Box {
  const rect = element.getBoundingClientRect()
  const width = element.offsetWidth || rect.width
  const height = element.offsetHeight || rect.height
  return { left: rect.left + rect.width / 2 - width / 2, top: rect.top + rect.height / 2 - height / 2, width, height }
}

type Hold = { id: number; startX: number; startY: number; x: number; y: number; timer: ReturnType<typeof setTimeout> }

/** Tilts `element` under the pointer; returns the function that undoes it all. */
export function attachTilt(element: HTMLElement, { max }: { max: number }): () => void {
  let current = REST
  let target = REST
  let frame: number | null = null
  let driver: { id: number; touch: boolean } | null = null
  let hold: Hold | null = null
  let box: Box | null = null
  let swallowClick = false
  let glarePlaced = false

  const clear = () => {
    for (const property of PROPERTIES) element.style.removeProperty(property)
    delete element.dataset.tilt
    delete element.dataset.tilting
  }

  const write = () => {
    element.style.setProperty("--tilt-rx", `${current.rx}deg`)
    element.style.setProperty("--tilt-ry", `${current.ry}deg`)
    element.style.setProperty("--glare-dx", `${current.glareDx}px`)
    element.style.setProperty("--glare-dy", `${current.glareDy}px`)
  }

  const step = () => {
    frame = null
    current = easeToward(current, target)
    const still = settled(current, target)
    if (still && driver === null && atRest(target)) {
      current = REST
      clear()
      return
    }
    write()
    // Driven but resting (the pointer on the centre): neither moving nor held.
    if (still && atRest(target)) delete element.dataset.tilt
    else element.dataset.tilt = still ? "held" : "moving"
    if (!still) frame = requestAnimationFrame(step)
  }

  const schedule = () => {
    if (frame === null) frame = requestAnimationFrame(step)
  }

  const placeGlareUnderPointer = () => {
    current = { ...current, glareDx: target.glareDx, glareDy: target.glareDy }
    glarePlaced = true
    write()
  }

  const aim = (x: number, y: number) => {
    box ??= layoutBox(element)
    target = tiltTarget(x, y, box, max)
    if (!glarePlaced) placeGlareUnderPointer()
    schedule()
  }

  const drive = (id: number, touch: boolean) => {
    driver = { id, touch }
    glarePlaced = false
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

  // A finger tilting the card does not scroll the page under it.
  const onTouchMove = (event: TouchEvent) => {
    if (driver?.touch && event.cancelable) event.preventDefault()
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

  return () => {
    view?.removeEventListener("scroll", onScroll, { capture: true })
    element.removeEventListener("pointerdown", onPointerDown)
    element.removeEventListener("pointermove", onPointerMove)
    element.removeEventListener("pointerleave", onPointerLeave)
    element.removeEventListener("pointerup", onPointerEnd)
    element.removeEventListener("pointercancel", onPointerEnd)
    element.removeEventListener("touchmove", onTouchMove)
    element.removeEventListener("click", onClick, { capture: true })
    cancelHold()
    if (frame !== null) cancelAnimationFrame(frame)
    frame = null
    driver = null
    box = null
    current = target = REST
    clear()
  }
}
