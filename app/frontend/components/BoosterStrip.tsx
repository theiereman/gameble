// The booster's information strip on the phone (DESIGN.md, Booster
// information panel: "the same facts in a 44px strip"; story 8.12): the
// kicker "Saison 1 · Grand catalogue", the mini pips with "+1 dans …" or
// "Réserve pleine", and the status chip (an 8px steady light and the state
// word). The island's title on the phone, so the section stays named.
export type BoosterStripProps = {
  /** "Saison 1 · Grand catalogue", or "Grand catalogue" without a season. */
  title: string
  /** Pips lit, out of `pips`. */
  lit: number
  pips: number
  /** "Réserve pleine" when the reserve is full, else null. */
  reserveFull: string | null
  /** "+1 dans" and its clock, with the time for assistive technology; null without a countdown. */
  next: { label: string; clock: string; spoken: string } | null
  state: string
  tone: string
}

export default function BoosterStrip({ title, lit, pips, reserveFull, next, state, tone }: BoosterStripProps) {
  return (
    <div className="booster-strip">
      <div className="booster-strip__id">
        <h2 id="booster-title" className="booster-strip__title">
          {title}
        </h2>
        <p className="booster-strip__reserve">
          <span className="booster-strip__pips" aria-hidden="true">
            {Array.from({ length: pips }, (_, index) => (
              <span key={index} className="booster__pip" data-lit={index < lit ? "" : undefined} />
            ))}
          </span>
          {reserveFull !== null ? (
            <span className="booster-strip__next booster__next--full">{reserveFull}</span>
          ) : (
            next && (
              <span className="booster-strip__next">
                <span aria-hidden="true">
                  {next.label} <b className="booster__clock">{next.clock}</b>
                </span>
                <span className="visually-hidden">{next.spoken}</span>
              </span>
            )
          )}
        </p>
      </div>
      <p className="booster__state booster-strip__state" data-tone={tone}>
        <span className="booster__light" aria-hidden="true" />
        <span className="booster__state-word">{state}</span>
      </p>
    </div>
  )
}
