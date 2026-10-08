// The booster island's effects, drawn as plain spans or played on the
// elements they are given: WAAPI on transform and opacity only. animate,
// settle, spark and ring are the plain helpers (animate also plays the
// reduced-motion fades); stageShake, stageFlash, burst, blast and
// traySparks each stop under reduced motion. No React: the island passes
// the host and target elements.
import type { Rarity } from "./card_types"
import { TRAY_SPARKS, burstPixels, scaled, shakeKeyframes, tierIndex } from "./booster"
import { motionReduced } from "./motion"

export const animate = (element: Element | null | undefined, keyframes: Keyframe[], options: KeyframeAnimationOptions) =>
  element && typeof element.animate === "function" ? element.animate(keyframes, options) : null

/** Cancels every animation the island left on an element (fills included). */
export const settle = (element: Element | null | undefined) => element?.getAnimations?.().forEach((animation) => animation.cancel())

/** The stage shaking by `amplitude` px. */
export const stageShake = (stage: HTMLElement | null, amplitude: number, duration: number) => {
  if (motionReduced()) return
  animate(stage, shakeKeyframes(amplitude), { duration, fill: "none" })
}

/** The stage's flash layer lighting up in `tone`, to `peak` opacity. */
export const stageFlash = (flash: HTMLElement | null, tone: "warm" | "gold", peak: number, duration: number) => {
  if (motionReduced() || !flash) return
  flash.dataset.tone = tone
  animate(flash, [{ opacity: 0 }, { opacity: peak, offset: 0.12 }, { opacity: 0 }], { duration, easing: "ease-out", fill: "none" })
}

/** A short-lived span in `host` at (x, y), animated, then removed. */
export const spark = (
  host: HTMLElement,
  className: string,
  x: number,
  y: number,
  keyframes: Keyframe[],
  options: KeyframeAnimationOptions,
  size?: number,
) => {
  const element = document.createElement("span")
  element.className = className
  element.style.left = `${Math.round(x)}px`
  element.style.top = `${Math.round(y)}px`
  if (size !== undefined) {
    element.style.width = `${size}px`
    element.style.height = `${size}px`
  }
  host.append(element)
  const animation = animate(element, keyframes, { fill: "forwards", ...options })
  const remove = () => element.remove()
  if (animation) animation.finished.then(remove, remove)
  else remove()
}

export const ring = (host: HTMLElement, className: string, x: number, y: number, size: number, delay = 0) =>
  spark(
    host,
    className,
    x - size / 2,
    y - size / 2,
    [{ transform: "scale(0.2)", opacity: 1 }, { transform: "scale(1)", opacity: 0 }],
    { duration: scaled(380), delay, easing: "cubic-bezier(.2,.8,.3,1)", fill: "both" },
    size,
  )

/** The pixels flying off a card as it shows, in its tier's colours, drawn in the card's effects layer. */
export const burst = (host: HTMLElement | null, tier: Rarity) => {
  if (!host || motionReduced()) return
  const { width, height } = host.getBoundingClientRect()
  burstPixels(tier, width, height).forEach(({ x, y, dx, dy }, position) =>
    spark(host, `booster-fx__pixel booster-fx__pixel--${position % 3}`, x, y, [
      { transform: "translate(0px, 0px)", opacity: 1 },
      { transform: `translate(${dx}px, ${dy}px)`, opacity: 0 },
    ], { duration: scaled(420 + 40 * tierIndex(tier)), easing: "steps(4)" }),
  )
}

/** The blast at the canister's `body`, drawn in the stage's effects layer: a ring, sparks and smoke puffs. */
export const blast = (host: HTMLElement | null, body: HTMLElement | null | undefined) => {
  if (!host || !body || motionReduced()) return
  const box = host.getBoundingClientRect()
  const rect = body.getBoundingClientRect()
  const x = rect.left + rect.width / 2 - box.left
  const y = rect.top + rect.height / 2 - box.top
  ring(host, "booster-fx__ring booster-fx__ring--blast", x, y, 220)
  for (let index = 0; index < 14; index++) {
    const angle = (index / 14) * Math.PI * 2 + 0.3
    const reach = 90 + (index % 3) * 50
    spark(host, `booster-fx__spark booster-fx__spark--${index % 4}`, x, y, [
      { transform: "translate(0px, 0px)", opacity: 1 },
      { transform: `translate(${Math.round(Math.cos(angle) * reach)}px, ${Math.round(Math.sin(angle) * reach)}px)`, opacity: 0 },
    ], { duration: scaled(480), easing: "cubic-bezier(.15,.8,.3,1)" })
  }
  for (let index = 0; index < 6; index++) {
    const side = index % 2 === 0 ? -1 : 1
    const top = index < 3 ? -1 : 1
    spark(host, "booster-fx__smoke", x + side * 70, y + top * 110, [
      { transform: "translate(0px, 0px) scale(0.6)", opacity: 0.5 },
      { transform: `translate(${side * 40}px, ${top * 50}px) scale(2.4)`, opacity: 0 },
    ], { duration: scaled(520 + index * 30), easing: "ease-out" })
  }
}

/** The sparks of an Épique or better landing in its tray `slot`, drawn in the stage's effects layer. */
export const traySparks = (host: HTMLElement | null, slot: HTMLElement | null | undefined, tier: Rarity) => {
  if (!host || !slot || motionReduced() || tierIndex(tier) < 3) return
  const box = host.getBoundingClientRect()
  const rect = slot.getBoundingClientRect()
  const x = rect.left + rect.width / 2 - box.left
  const y = rect.top + rect.height / 2 - box.top
  for (let count = 0; count < TRAY_SPARKS; count++) {
    const angle = (count / TRAY_SPARKS) * Math.PI * 2
    const reach = 26 + (count % 3) * 8
    spark(host, `booster-fx__pixel booster-fx__pixel--${count % 3} booster-fx--${tier}`, x - 2, y - 2, [
      { transform: "translate(0px, 0px)", opacity: 1 },
      { transform: `translate(${Math.round(Math.cos(angle) * reach / 2) * 2}px, ${Math.round(Math.sin(angle) * reach / 2) * 2}px)`, opacity: 0 },
    ], { duration: scaled(380), easing: "steps(4)" })
  }
}
