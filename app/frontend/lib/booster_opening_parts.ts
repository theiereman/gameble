import { ArtPrefetch, heldCapsulesOf } from "./art_prefetch"
import { idle } from "./booster_state"
import { BankRefresh } from "./booster_bank_refresh"
import { OpeningConfirmations } from "./booster_confirmations"
import type { BoosterFaces } from "./booster_faces"
import type { BoosterStageHost } from "./booster_host"
import { OpeningSequence } from "./booster_opening_sequence"
import type { BoosterStrings } from "./booster_render_host"
import type { BoosterState } from "./booster_types"
import type { OpeningAnswer } from "./opening"

export type OpeningPartsHost = Readonly<{
  stage: BoosterStageHost
  root: HTMLElement
  state: () => BoosterState | undefined
  openUrl: string
  bankUrl: string
  strings: BoosterStrings
  faces: BoosterFaces
}>

export type OpeningParts = Readonly<{
  bankRefresh: BankRefresh
  opening: OpeningSequence
  confirmations: OpeningConfirmations
  artPrefetch: ArtPrefetch
}>

export function openingPartsFor({
  stage,
  root,
  state,
  openUrl,
  bankUrl,
  strings,
  faces,
}: OpeningPartsHost): OpeningParts {
  const bankRefresh = new BankRefresh({
    state,
    current: stage.current,
    bankUrl,
    disposed: () => stage.timers().disposed,
    apply: stage.apply,
    announce: (reserve) => stage.announce(strings[reserve === "special" ? "specialArrived" : "standardReady"]),
  })
  const keepFaces = (answer: OpeningAnswer): void => faces.keepFaces(answer)
  const refreshBank = (): Promise<void> => bankRefresh.refresh()
  const confirmations = new OpeningConfirmations({
    openUrl,
    current: stage.current,
    timers: stage.timers,
    apply: stage.apply,
    announce: stage.announce,
    keepFaces,
    refreshBank,
  })
  const opening = new OpeningSequence({
    ...stage,
    root,
    openUrl,
    reserve: () => stage.current().reserve,
    failedMessage: strings.failed,
    refusedTitle: strings.refusedTitle,
    keepFaces,
    refreshBank,
    confirm: (entry) => confirmations.confirm(entry),
    awaitConfirmation: (reserve) => confirmations.awaitConfirmation(reserve),
  })
  const artPrefetch = new ArtPrefetch({
    capsules: () => {
      const current = state()
      return current ? heldCapsulesOf(current) : []
    },
    calm: () => {
      const current = state()
      return current !== undefined && idle(current)
    },
  })
  return { bankRefresh, opening, confirmations, artPrefetch }
}
