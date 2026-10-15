// The booster's information column in the rows (wide and narrow layouts):
// the hazard stripe, the kicker and
// the title, the bracketed panel (cards per booster, reserve, state with
// its steady light), the reserve's pips with "+1 dans …" or "Réserve
// pleine", the actions the island hands over, "Cartes révélées : n / N",
// and under it the set celebration once the hand is complete.
// The phone shows the same facts in BoosterStrip.
import type { ReactNode } from "react"

export type BoosterPanelProps = {
  kicker: string
  title: string
  cardsPerPack: { label: string; value: string }
  inReserve: { label: string; value: string }
  state: { label: string; word: string; tone: string }
  reserve: string
  /** "Réserve pleine" when the reserve is full, else null. */
  reserveFull: string | null
  /** "+1 dans" and its clock, with the time for assistive technology; null without a countdown. */
  next: { label: string; clock: string; spoken: string } | null
  lit: number
  pips: number
  actions: ReactNode
  counter: string
  /** The set celebration, or null. */
  celebration: ReactNode
}

export default function BoosterPanel(props: BoosterPanelProps) {
  const { kicker, title, cardsPerPack, inReserve, state, reserve, reserveFull, next, lit, pips, actions, counter, celebration } = props
  return (
    <aside className="booster__info">
      <div className="booster__hazard" aria-hidden="true" />
      <div className="booster__id">
        <p className="booster__kicker">{kicker}</p>
        <h2 id="booster-title" className="booster__title">
          {title}
        </h2>
      </div>

      <dl className="booster__panel panel panel--brackets">
        <div className="booster__row">
          <dt>{cardsPerPack.label}</dt>
          <dd className="booster__value">{cardsPerPack.value}</dd>
        </div>
        <div className="booster__row">
          <dt>{inReserve.label}</dt>
          <dd className="booster__value booster__value--reserve">{inReserve.value}</dd>
        </div>
        <div className="booster__row booster__row--state">
          <dt>{state.label}</dt>
          <dd className="booster__state" data-tone={state.tone}>
            <span className="booster__light" aria-hidden="true" />
            <span className="booster__state-word">{state.word}</span>
          </dd>
        </div>
      </dl>

      <div className="booster__reserve">
        <p className="booster__reserve-head">
          <span>{reserve}</span>
          {reserveFull !== null ? (
            <span className="booster__next booster__next--full">{reserveFull}</span>
          ) : (
            next && (
              <span className="booster__next">
                <span aria-hidden="true">
                  {next.label} <b className="booster__clock">{next.clock}</b>
                </span>
                <span className="visually-hidden">{next.spoken}</span>
              </span>
            )
          )}
        </p>
        <div className="booster__pips" aria-hidden="true">
          {Array.from({ length: pips }, (_, index) => (
            <span key={index} className="booster__pip" data-lit={index < lit ? "" : undefined} />
          ))}
        </div>
      </div>

      <div className="booster__actions">{actions}</div>

      <p className="booster__counter">{counter}</p>
      {celebration}
    </aside>
  )
}
