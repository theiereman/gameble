import { buttonKind, commitment, parse, type AnnonceState } from "./annonce"
import { t } from "./i18n"
import { picoins } from "./picoins"

export type AnnonceStrings = {
  buttonBid: string
  buttonIdle: string
  buttonName: string
  buttonRaise: string
  liveHold: string
  liveRaise: string
}

export type Forms = { locale: string; strings: AnnonceStrings }

export type FootView = {
  button: string
  name: string | null
  live: string
  sentencesHidden: boolean
  panelHidden: boolean
}

export function footViewOf(state: AnnonceState, { locale, strings }: Forms): FootView {
  const kind = buttonKind(state)
  const amount = parse(state.text)
  const shown = (value: number): string => picoins(value, { locale })
  const base = { sentencesHidden: state.answered, panelHidden: !state.answered }
  if (kind === "idle" || amount === null) return { ...base, button: strings.buttonIdle, name: null, live: "" }
  const name = t(strings.buttonName, { amount: shown(amount) })
  const held = shown(Math.max(commitment(state, amount), 0))
  if (kind === "raise")
    return {
      ...base,
      button: t(strings.buttonRaise, { amount: shown(amount) }),
      name,
      live: t(strings.liveRaise, { amount: held }),
    }
  return {
    ...base,
    button: t(strings.buttonBid, { amount: shown(amount) }),
    name,
    live: t(strings.liveHold, { amount: held }),
  }
}
