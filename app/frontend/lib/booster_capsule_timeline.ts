import { animate } from "./booster_effects"

// The capsule's opening as its design reference keyframes it: one run of
// CAPSULE_T, entered 13 % in so the fuse lights 60 ms after the touch. Every
// percentage below is the reference's; ms from the touch = % × 60 − 780.
export const CAPSULE_T = 6000
const ENTRY = CAPSULE_T * 0.13
export const BLAST_AT = 900
export const OPENED_AT = 2100

const THROW = "cubic-bezier(.15,.7,.3,1)"

const fromTouch: KeyframeAnimationOptions = { duration: CAPSULE_T, delay: -ENTRY, fill: "both", easing: "linear" }
const fromBlast: KeyframeAnimationOptions = { ...fromTouch, delay: -(ENTRY + BLAST_AT) }

const at = (percents: number[], frame: Keyframe): Keyframe[] =>
  percents.map((percent) => ({ ...frame, offset: percent / 100 }))

const move = (x: number, y: number) => `translate(${x}px, ${y}px)`
const STILL = "translate(0px, 0px) rotate(0deg)"

const SHAKE: ReadonlyArray<readonly [number, number]> = [
  [-1.5, 0.5],
  [1.1, -1.1],
  [-0.6, 1.2],
  [1.9, 0],
  [-2.0, 0.7],
  [1.4, -1.4],
  [-0.8, 1.5],
  [2.4, 0],
  [-2.6, 0.9],
  [1.8, -1.8],
  [-0.9, 1.9],
  [3.0, 0],
  [-3.1, 1.0],
  [2.2, -2.2],
  [-1.1, 2.3],
  [3.5, 0],
  [-3.7, 1.2],
  [2.5, -2.5],
  [-1.3, 2.6],
  [4.1, 0],
]

function shakeFrames(): Keyframe[] {
  return [
    ...at([0, 17.5], { transform: move(0, 0) }),
    ...SHAKE.map(([x, y], step) => ({ offset: (18 + step * 0.5) / 100, transform: move(x, y) })),
    ...at([28.2, 100], { transform: move(0, 0) }),
  ]
}

function ledFrames(rest: string): Keyframe[] {
  const blinks: Keyframe[] = []
  for (let percent = 14; percent < 28; percent++) {
    const lit = percent % 2 === 0
    blinks.push(
      ...at([percent, percent + 0.9], {
        backgroundColor: lit ? "#ff8a1f" : "#3a1a08",
        boxShadow: lit ? "0 0 6px #ff8a1f" : "0 0 0px #ff8a1f",
      }),
    )
  }
  return [
    ...at([0, 13.9], { backgroundColor: rest, boxShadow: `0 0 6px ${rest}` }),
    ...blinks,
    ...at([28, 92, 100], { backgroundColor: "#1b2d40", boxShadow: "none" }),
  ]
}

const sparkFrames = (from: number, to: number): Keyframe[] => [
  ...at([0, 13.9], { opacity: 0, transform: `translateX(${from}px)` }),
  ...at([14], { opacity: 1, transform: `translateX(${from}px)` }),
  ...at([27], { opacity: 1, transform: `translateX(${to}px)` }),
  ...at([28, 100], { opacity: 0, transform: `translateX(${to}px)` }),
]

const burnFrames = (): Keyframe[] => [
  ...at([0, 13.9], { transform: "scaleX(0)", opacity: 1 }),
  ...at([27], { transform: "scaleX(1)", opacity: 1 }),
  ...at([28, 100], { transform: "scaleX(1)", opacity: 0 }),
]

const sealUpFrames = (): Keyframe[] => [
  ...at([0, 20], { transform: "rotate(0deg) translate(0px, 0px)" }),
  ...at([26, 28, 100], { transform: "rotate(-10deg) translate(-2px, -3px)" }),
]

const thrownFrames = (until: number, away: string): Keyframe[] => [
  ...at([0, 28], { transform: STILL, opacity: 1, easing: THROW }),
  ...at([until, 100], { transform: away, opacity: 0 }),
]

const bodyFrames = (): Keyframe[] => [
  ...at([0, 25], { opacity: 1, filter: "brightness(1)", transform: "scale(1, 1)" }),
  ...at([28.4], { opacity: 1, filter: "brightness(1.3)", transform: "scale(1.07, 0.93)" }),
  ...at([29.8], { opacity: 1, filter: "brightness(2.6)", transform: "scale(1.04, 1.04)" }),
  ...at([30.4, 92, 100], { opacity: 0, filter: "brightness(2.6)", transform: "scale(1.04, 1.04)" }),
]

const flashFrames = (): Keyframe[] => [
  ...at([0, 27.9], { opacity: 0, transform: "scaleX(0.2)" }),
  ...at([29], { opacity: 1, transform: "scaleX(1)" }),
  ...at([36, 100], { opacity: 0, transform: "scaleX(1.7) scaleY(4)" }),
]

const FUSE: ReadonlyArray<readonly [string, () => Keyframe[]]> = [
  ["shake", shakeFrames],
  ["spark--top", () => sparkFrames(0, 272)],
  ["spark--bottom", () => sparkFrames(272, 0)],
  ["burn--top", burnFrames],
  ["burn--bottom", burnFrames],
  ["seal--up", sealUpFrames],
  ["seal--low", () => thrownFrames(46, "translate(60px, -120px) rotate(160deg)")],
  ["top", () => thrownFrames(40, "translate(0px, -320px) rotate(-16deg)")],
  ["bottom", () => thrownFrames(40, "translate(0px, 340px) rotate(12deg)")],
  ["body", bodyFrames],
  ["flash--top", flashFrames],
  ["flash--bottom", flashFrames],
]

// From the touch: the fuse burns, the capsule shakes harder and harder, then
// breaks at BLAST_AT. The caller holds these there until the answer lands.
export function lightFuse(wrap: HTMLElement | null | undefined): Animation[] {
  if (!wrap) return []
  const piece = (name: string) => wrap.querySelector<HTMLElement>(`.booster-canister__${name}`)
  const led = piece("led")
  const rest = led ? getComputedStyle(led).backgroundColor : "#66c0f4"
  const pieces: Array<[HTMLElement | null, Keyframe[]]> = [
    ...FUSE.map(([name, frames]): [HTMLElement | null, Keyframe[]] => [piece(name), frames()]),
    [led, ledFrames(rest)],
  ]
  return pieces.flatMap(([element, frames]) => animate(element, frames, fromTouch) ?? [])
}

export const holdAll = (animations: Animation[]) => animations.forEach((animation) => animation.pause())

export const releaseAll = (animations: Animation[]) =>
  animations.forEach((animation) => animation.playState === "paused" && animation.play())

type Piece = Readonly<{ left: number; top: number; width: number; height: number; look?: Partial<CSSStyleDeclaration> }>

function spawn(host: HTMLElement, className: string, piece: Piece, frames: Keyframe[]): void {
  const element = document.createElement("span")
  element.className = className
  Object.assign(element.style, {
    left: `${piece.left}px`,
    top: `${piece.top}px`,
    width: `${piece.width}px`,
    height: `${piece.height}px`,
    ...piece.look,
  })
  host.append(element)
  const animation = animate(element, frames, fromBlast)
  const remove = () => element.remove()
  if (animation) animation.finished.then(remove, remove)
  else remove()
}

const PAPER = "#efe6cf"
const YELLOW = "#ffc21a"
const SHELL = ["#26405a", "#355675", "#4f7393"]
const LABEL = "#c9d6e2"
const LIT_EDGE = "inset 0 2px 0 rgba(255,255,255,0.25)"

// [left, top, size, colour, dx, dy] in the capsule's own pixels.
const DEBRIS: ReadonlyArray<readonly [number, number, number, string, number, number]> = [
  [60, 80, 6, PAPER, -120, -140],
  [110, 80, 4, YELLOW, -60, -200],
  [160, 80, 6, SHELL[1], 40, -220],
  [210, 80, 4, PAPER, 110, -160],
  [250, 80, 6, YELLOW, 160, -90],
  [244, 70, 6, PAPER, 180, -180],
  [70, 356, 6, YELLOW, -140, 120],
  [140, 356, 4, PAPER, -40, 180],
  [200, 356, 6, SHELL[1], 60, 170],
  [270, 356, 4, YELLOW, 150, 110],
]

// [left, top, dx, dy], 24 px squares of smoke.
const PUFFS: ReadonlyArray<readonly [number, number, number, number]> = [
  [70, 72, -40, -50],
  [130, 72, -10, -70],
  [190, 72, 20, -70],
  [240, 72, 50, -50],
  [90, 350, -40, 40],
  [150, 350, 0, 60],
  [210, 350, 40, 40],
]

// The body's 4 × 3 grid of 72 × 86 pieces: [colour, outline, dx, dy, turn].
const SHARDS: ReadonlyArray<readonly [string, string, number, number, number]> = [
  [SHELL[0], "4px 8px, 40px 4px, 72px 8px, 68px 39px, 72px 86px, 44px 82px, 0px 86px, 0px 39px", -137, -93, -161],
  [LABEL, "4px 8px, 32px 8px, 64px 8px, 64px 35px, 64px 82px, 32px 86px, 0px 86px, 0px 47px", -71, -244, -135],
  [LABEL, "4px 0px, 28px 4px, 72px 4px, 72px 35px, 72px 86px, 32px 86px, 0px 78px, 0px 51px", 65, -193, 158],
  [SHELL[1], "0px 0px, 28px 0px, 68px 0px, 72px 47px, 72px 86px, 28px 86px, 0px 86px, 0px 35px", 154, -161, 90],
  [SHELL[0], "0px 0px, 28px 0px, 64px 4px, 72px 39px, 72px 82px, 40px 86px, 0px 82px, 4px 47px", -189, -6, -60],
  [LABEL, "0px 8px, 36px 0px, 68px 0px, 72px 51px, 72px 78px, 28px 82px, 0px 86px, 0px 35px", -257, 16, 158],
  [LABEL, "0px 0px, 28px 0px, 72px 0px, 64px 51px, 72px 86px, 44px 86px, 0px 86px, 4px 51px", 212, -11, -99],
  [SHELL[1], "0px 0px, 44px 0px, 68px 0px, 72px 39px, 72px 86px, 44px 78px, 4px 78px, 0px 35px", 176, -16, -160],
  [SHELL[0], "0px 4px, 44px 4px, 72px 8px, 68px 35px, 68px 82px, 40px 86px, 8px 86px, 0px 43px", -127, 150, -64],
  [SHELL[1], "0px 0px, 40px 4px, 68px 0px, 64px 39px, 72px 86px, 44px 86px, 0px 78px, 0px 39px", -98, 221, -68],
  [SHELL[2], "0px 4px, 36px 0px, 64px 0px, 72px 35px, 72px 78px, 36px 86px, 0px 78px, 0px 47px", 86, 237, -93],
  [SHELL[1], "0px 0px, 28px 4px, 64px 4px, 64px 47px, 72px 78px, 44px 86px, 4px 86px, 0px 51px", 116, 86, -125],
]

// Chips from the centre: [size, colour, dx, dy, turn].
const CHIPS: ReadonlyArray<readonly [number, string, number, number, number]> = [
  [10, SHELL[2], 234, 86, 207],
  [6, SHELL[2], 184, 192, 97],
  [6, LABEL, 49, 256, 148],
  [6, SHELL[2], -169, 202, 258],
  [10, YELLOW, -194, 52, 167],
  [8, SHELL[1], -266, -15, 282],
  [12, SHELL[1], -144, -220, 173],
  [10, PAPER, -34, -222, 295],
  [8, PAPER, 135, -183, 146],
  [10, SHELL[1], 209, -87, 124],
]

const CENTRE = { x: 160, y: 222 }

const shardFrames = (dx: number, dy: number, turn: number): Keyframe[] => [
  ...at([0, 30.3], { opacity: 0, transform: STILL }),
  ...at([30.4], { opacity: 1, transform: STILL, easing: THROW }),
  ...at([48, 100], { opacity: 0, transform: `${move(dx, dy)} rotate(${turn}deg)` }),
]

const debrisFrames = (dx: number, dy: number): Keyframe[] => [
  ...at([0, 28], { opacity: 0, transform: STILL }),
  ...at([28.5], { opacity: 1, transform: STILL, easing: THROW }),
  ...at([46, 100], { opacity: 0, transform: `${move(dx, dy)} rotate(220deg)` }),
]

const puffFrames = (dx: number, dy: number): Keyframe[] => [
  ...at([0, 28], { opacity: 0, transform: `${move(0, 0)} scale(0.3)` }),
  ...at([29], { opacity: 0.9, transform: `${move(0, 0)} scale(0.4)` }),
  ...at([54, 100], { opacity: 0, transform: `${move(dx, dy)} scale(2.6)` }),
]

const burstFrames = (): Keyframe[] => [
  ...at([0, 28.9], { opacity: 0, transform: "scale(0.2)" }),
  ...at([30.4], { opacity: 1, transform: "scale(2.4)" }),
  ...at([40, 100], { opacity: 0, transform: "scale(5)" }),
]

const waveFrames = (): Keyframe[] => [
  ...at([0, 29.9], { opacity: 0, transform: "scale(0.3)" }),
  ...at([30.4], { opacity: 1, transform: "scale(0.6)" }),
  ...at([40, 100], { opacity: 0, transform: "scale(6.5)" }),
]

// At the blast: debris, smoke, the white burst, the shock wave and the body
// breaking into pieces, all thrown from the capsule's own layer.
export function breakCapsule(fx: HTMLElement | null | undefined): void {
  if (!fx) return
  DEBRIS.forEach(([left, top, size, colour, dx, dy]) =>
    spawn(
      fx,
      "booster-canister__debris",
      { left, top, width: size, height: size, look: { background: colour } },
      debrisFrames(dx, dy),
    ),
  )
  PUFFS.forEach(([left, top, dx, dy]) =>
    spawn(fx, "booster-canister__puff", { left, top, width: 24, height: 24 }, puffFrames(dx, dy)),
  )
  spawn(fx, "booster-canister__burst", { left: 120, top: 182, width: 80, height: 80 }, burstFrames())
  spawn(fx, "booster-canister__shock", { left: 130, top: 192, width: 60, height: 60 }, waveFrames())
  SHARDS.forEach(([colour, outline, dx, dy, turn], index) => {
    const look = { background: colour, clipPath: `polygon(${outline})`, boxShadow: colour === LABEL ? "" : LIT_EDGE }
    const box = { left: 16 + (index % 4) * 72, top: 92 + Math.floor(index / 4) * 86, width: 72, height: 86, look }
    spawn(fx, "booster-canister__shard", box, shardFrames(dx, dy, turn))
  })
  CHIPS.forEach(([size, colour, dx, dy, turn]) => {
    const box = {
      left: CENTRE.x - size / 2,
      top: CENTRE.y - size / 2,
      width: size,
      height: size,
      look: { background: colour },
    }
    spawn(fx, "booster-canister__shard", box, shardFrames(dx, dy, turn))
  })
}

export function quakeFrames(): Keyframe[] {
  return [
    ...at([0, 29.9], { transform: move(0, 0) }),
    ...at([30.3], { transform: move(7, -5) }),
    ...at([30.9], { transform: move(-6, 4) }),
    ...at([31.5], { transform: move(5, 5) }),
    ...at([32.2], { transform: move(-4, -3) }),
    ...at([33], { transform: move(2, 2) }),
    ...at([34, 100], { transform: move(0, 0) }),
  ]
}

export const quakeTiming: KeyframeAnimationOptions = { ...fromBlast, fill: "none" }

export { fromBlast as blastTiming }
