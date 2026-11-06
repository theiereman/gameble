import type { Layout } from "./booster_types"

export type OpeningMarks = Readonly<{ touchedAt: number | null; blastAt: number | null }>

export const NO_MARKS: OpeningMarks = { touchedAt: null, blastAt: null }

export type OpeningTimings = Readonly<{ touch_to_blast?: number; touch_to_first_face?: number; layout?: Layout }>

export const NO_TIMINGS: OpeningTimings = {}

function elapsed(from: number, to: number | null): number | undefined {
  if (to === null || to < from) return undefined
  return Math.round(to - from)
}

function firstFaceAt(revealedAt: readonly (number | undefined)[]): number | null {
  const faces = revealedAt.filter((at): at is number => at !== undefined)
  return faces.length > 0 ? Math.min(...faces) : null
}

export function openingTimings(
  { touchedAt, blastAt }: OpeningMarks,
  revealedAt: readonly (number | undefined)[],
  layout: Layout,
): OpeningTimings {
  if (touchedAt === null) return NO_TIMINGS
  const toBlast = elapsed(touchedAt, blastAt)
  const toFirstFace = elapsed(touchedAt, firstFaceAt(revealedAt))
  return {
    ...(toBlast === undefined ? {} : { touch_to_blast: toBlast }),
    ...(toFirstFace === undefined ? {} : { touch_to_first_face: toFirstFace }),
    layout,
  }
}
