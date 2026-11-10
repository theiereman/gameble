// The PiCoin mark, a round gold coin with a pi: 8 × 8 beside a figure of text,
// 11 × 11 beside a larger one. Exported as picoin-mark.svg and picoin-mark-large.svg.
const LEGEND = { h: "#ffe58f", b: "#f4c542", l: "#b5851a", p: "#120d05" }

export const PICOIN_MARKS = {
  "picoin-mark": {
    look: "a round gold coin with a pi",
    size: 8,
    legend: LEGEND,
    grid: [
      "..hhhh..",
      ".hbbbbh.",
      "hpppppph",
      "hbpbpbbl",
      "hbpbpbbl",
      "hbpbppbl",
      ".hbbbbl.",
      "..hlll..",
    ],
  },
  "picoin-mark-large": {
    look: "a round gold coin with a pi",
    size: 11,
    legend: LEGEND,
    grid: [
      "...hhhhh...",
      "..hbbbbbh..",
      ".hbbbbbbbh.",
      "hbpppppppbh",
      "hbbpbbpbbbl",
      "hbbpbbpbbbl",
      "hbbpbbpbbbl",
      "hbbpbbppbbl",
      ".hbbbbbbbl.",
      "..hbbbbbl..",
      "...hllll...",
    ],
  },
}
