// The base backs: every player holds them from sign-up. They share the
// standard back's drawing and differ only in its colours. The standard back
// keeps its hand-picked slate blue; the others derive every tone from one
// accent of the gameble palette, so they read as the same card in another dye.
const STANDARD_TONES = {
  accent: "#66c0f4", frame: "#2a475e", light: "#3d6c8c", shadow: "#142636", inner: "#1f3346",
  weave: ["#152131", "#0d141d"], weaveAlt: ["#1a2738", "#111a25"], disc: "#183048"
}

const tonesOf = (accent, mixc) => ({
  accent,
  frame: mixc(accent, "#0e141b", 0.62),
  light: mixc(accent, "#0e141b", 0.45),
  shadow: mixc(accent, "#06090d", 0.8),
  inner: mixc(accent, "#0e141b", 0.8),
  weave: [mixc(accent, "#0e141b", 0.9), mixc(accent, "#0b1119", 0.95)],
  weaveAlt: [mixc(accent, "#0e141b", 0.86), mixc(accent, "#0b1119", 0.92)],
  disc: mixc(accent, "#0b1119", 0.78)
})

const BASE_BACKS = [
  { name: "standard", title: "Standard", accent: null, look: "slate frame, diagonal weave, blue ring with gold ticks, the gold G monogram, GAMEBLE" },
  { name: "emeraude", title: "Émeraude", accent: "#3fcf8e", look: "the standard back dyed green" },
  { name: "amethyste", title: "Améthyste", accent: "#b47cff", look: "the standard back dyed violet" },
  { name: "rubis", title: "Rubis", accent: "#ff6b5a", look: "the standard back dyed red" },
  { name: "argent", title: "Argent", accent: "#bcc8d4", look: "the standard back dyed silver" }
]

export const baseBackDesigns = (mixc) =>
  BASE_BACKS.map((design) => ({ ...design, tones: design.accent ? tonesOf(design.accent, mixc) : STANDARD_TONES }))
