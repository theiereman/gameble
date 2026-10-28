// The canister of each special origin: the standard body with its label band
// in the origin's colour and an emblem in the window instead of the gold G.
// An emblem is a 17 × 17 character grid, one art pixel per cell, "." being
// transparent; its palette maps each character to a colour.

export const EMBLEM_SIZE = 17

const SUN = [
  "........b........",
  ".b......b......b.",
  "..b...........b..",
  ".......ooo.......",
  ".....oohhhoo.....",
  "....ohhhhbhho....",
  "....ohwbbbblo....",
  "...ohhbbbbbblo...",
  "bb.ohbbbbbbllo.ll",
  "...ohbbbbllllo...",
  "....obbbllllo....",
  "....olllllllo....",
  ".....oollloo.....",
  ".......ooo.......",
  "..b...........l..",
  ".b......l......l.",
  "........l........",
]

const CUP = [
  "....ooooooooo....",
  ".ooohhhhhhhhhooo.",
  "ohhhbbbbbbbbbhhho",
  "ohoohwbbbbbbloolo",
  "ohoohbbbbbbbloolo",
  "ohoohbbbbbbbloolo",
  "olllbbbbbbbbblllo",
  ".oooohbbbbbloooo.",
  ".....ohbbblo.....",
  "......ohblo......",
  "......ohblo......",
  "......ohblo......",
  "....oohbbbloo....",
  "...ohhhhhhhhho...",
  "...ohbbbbbbblo...",
  "...olllllllllo...",
  "....ooooooooo....",
]

// The band ramp: [lit top line, second line, body, stripe, dark line, edge].
export const ORIGIN_LOOKS = [
  {
    key: "daily",
    title: "Daily capsule",
    emblemName: "sun",
    band: { top: "#fdf3d9", second: "#fae2a1", body: "#f4c542", stripe: "#e6b93e", dark: "#886e25", edge: "#6e591e" },
    emblem: SUN,
    palette: { o: "#06090d", w: "#ffffff", h: "#fff3c4", b: "#f4c542", l: "#8f5e0a" },
  },
  {
    key: "goal",
    title: "Goal reward",
    emblemName: "cup",
    band: { top: "#f7d9d8", second: "#eba19e", body: "#d6403a", stripe: "#c93c37", dark: "#772420", edge: "#601d1a" },
    emblem: CUP,
    palette: { o: "#06090d", w: "#fff0ec", h: "#ffb3a8", b: "#d6403a", l: "#7a1c1f" },
  },
]

export const originBodyFile = ({ key }) => `canister-body-${key}.png`

export function drawEmblem(g, x0, y0, { emblem, palette }) {
  emblem.forEach((row, y) => [...row].forEach((cell, x) => {
    if (cell === ".") return
    g.fillStyle = palette[cell]
    g.fillRect(x0 + x, y0 + y, 1, 1)
  }))
}
