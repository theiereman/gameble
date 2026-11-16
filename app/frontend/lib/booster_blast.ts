import { animate } from "./booster_effects"

const STEP = "steps(1, end)"

const stepped = (frames: Keyframe[]): Keyframe[] => frames.map((frame) => ({ ...frame, easing: STEP }))

export function flashBlast(flash: HTMLElement | null): void {
  if (!flash) return
  flash.dataset.tone = "blast"
  animate(
    flash,
    stepped([
      { opacity: 0.6 },
      { opacity: 0.45, offset: 0.2 },
      { opacity: 0.28, offset: 0.45 },
      { opacity: 0.1, offset: 0.7 },
      { opacity: 0 },
    ]),
    { duration: 300, fill: "none" },
  )
}

// [x, y] of each beat, as a share of the amplitude, before the decay.
const SHAKE_BEATS: ReadonlyArray<readonly [number, number]> = [
  [0.9, -0.5],
  [-1, 0.6],
  [0.8, 0.7],
  [-0.9, -0.6],
  [0.7, -0.8],
  [-0.8, 0.5],
  [0.9, 0.3],
  [-0.7, -0.7],
  [0.8, 0.6],
  [-0.9, -0.2],
  [0.7, 0.4],
]

export function screenShakeKeyframes(amplitude: number): Keyframe[] {
  const still = { transform: "translate(0px, 0px) rotate(0deg)" }
  const beats = SHAKE_BEATS.map(([x, y], index) => {
    const step = index + 1
    const decay = (1 - step / (SHAKE_BEATS.length + 1)) ** 1.6
    const turn = (step % 2 === 1 ? -1 : 1) * 0.7 * decay
    return {
      transform: `translate(${Math.round(x * amplitude * decay)}px, ${Math.round(y * amplitude * decay)}px) rotate(${turn.toFixed(2)}deg)`,
    }
  })
  return [still, ...beats, still]
}

// On top of the capsule's own quake: the whole stage takes the blast.
export function shakeScreen(shake: HTMLElement | null, phone: boolean): void {
  animate(shake, screenShakeKeyframes(phone ? 10 : 14), { duration: 460, composite: "add", fill: "none" })
}

// The console takes a surge: it flashes, its scan lines flare and two bands tear sideways.
export function glitchScreen(shake: HTMLElement | null, scanlines: HTMLElement | null): void {
  animate(
    shake,
    stepped([
      { filter: "brightness(1.5)" },
      { filter: "brightness(1.2)", offset: 0.2 },
      { filter: "contrast(1.4)", offset: 0.4 },
      { filter: "none", offset: 0.65 },
      { filter: "none" },
    ]),
    { duration: 420, fill: "none" },
  )
  animate(
    scanlines,
    stepped([
      { opacity: 0.9 },
      { opacity: 0.4, offset: 0.25 },
      { opacity: 0.75, offset: 0.45 },
      { opacity: 0.2, offset: 0.7 },
      { opacity: 0 },
    ]),
    { duration: 520, fill: "none" },
  )
  const tears = Array.from(scanlines?.children ?? []) as HTMLElement[]
  tears.forEach((tear, index) => {
    const side = index % 2 === 0 ? 1 : -1
    animate(
      tear,
      stepped([
        { opacity: 0, transform: "translateX(0px)" },
        { opacity: 1, transform: `translateX(${18 * side}px)`, offset: 0.1 },
        { opacity: 0.6, transform: `translateX(${-9 * side}px)`, offset: 0.4 },
        { opacity: 0, offset: 0.6 },
        { opacity: 0 },
      ]),
      { duration: 380, delay: index * 70, fill: "none" },
    )
  })
}

// A card set down knocks the stage.
export function slamCard(shake: HTMLElement | null, phone: boolean): void {
  animate(
    shake,
    [
      { transform: "translateY(0px)" },
      { transform: `translateY(${phone ? 3 : 4}px)`, offset: 0.25 },
      { transform: "translateY(0px)" },
    ],
    { duration: 140, composite: "add", fill: "none" },
  )
}
