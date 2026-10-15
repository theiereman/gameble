// The set celebration once the hand is complete: each set's highest tier
// the opening reached, in the tier colour with its notches, or SET COMPLET
// in lime with its small COMPLET frame. On wider screens the results stack
// under the information panel; on the phone the plate band shows one at a
// time, "▸" moving to the next. More than three fold into one line. Nothing
// changes on a timer and nothing takes focus.
import { useState } from "react"
import { t } from "../lib/i18n"
import {
  folded,
  foldedTitle,
  nextResult,
  notchCount,
  resultCount,
  resultTitle,
  type CelebrationResult,
  type CelebrationStrings,
} from "../lib/celebration"
import type { SetTierName } from "../lib/opening"

export type BoosterCelebrationProps = {
  results: CelebrationResult[]
  strings: CelebrationStrings
  delimiter: string
  phone: boolean
}

export default function BoosterCelebration({ results, strings, delimiter, phone }: BoosterCelebrationProps) {
  const [index, setIndex] = useState(0)
  if (results.length === 0) return null

  const lines: Line[] = folded(results)
    ? [{ key: "folded", tier: results[0].tier, title: foldedTitle(results, strings), name: null, count: null }]
    : results.map((result) => ({
        key: result.key,
        tier: result.tier,
        title: resultTitle(result, strings),
        name: result.name,
        count: result.tier === "complete" ? null : resultCount(result, strings, delimiter),
      }))

  if (!phone) {
    return (
      <ul className="booster-celebration">
        {lines.map((line) => (
          <li key={line.key}>
            <Result line={line} />
          </li>
        ))}
      </ul>
    )
  }

  const shown = Math.min(index, lines.length - 1)
  return (
    <div className="booster-celebration booster-celebration--phone">
      <Result key={lines[shown].key} line={lines[shown]} />
      {lines.length > 1 && (
        <div className="booster-celebration__step">
          <span className="booster-celebration__position">{t(strings.position, { index: shown + 1, count: lines.length })}</span>
          <button
            type="button"
            className="button button--secondary booster-celebration__next"
            aria-label={strings.next}
            onClick={() => setIndex(nextResult(shown, lines.length))}
          >
            <span aria-hidden="true">▸</span>
          </button>
        </div>
      )}
    </div>
  )
}

type Line = { key: string; tier: SetTierName; title: string; name: string | null; count: string | null }

function Result({ line: { tier, title, name, count } }: { line: Line }) {
  return (
    <div className="booster-celebration__result" data-tier={tier}>
      <span className="booster-celebration__mark" aria-hidden="true">
        {tier === "complete" ? (
          <span className="booster-celebration__stamp" />
        ) : (
          <span className="booster-celebration__notches">
            {Array.from({ length: notchCount(tier) }, (_, notch) => (
              <i key={notch} />
            ))}
          </span>
        )}
      </span>
      <span className="booster-celebration__text">
        <span className="booster-celebration__title">
          <i className="booster-celebration__tick" aria-hidden="true" />
          {title}
          <i className="booster-celebration__tick" aria-hidden="true" />
        </span>
        {name !== null && (
          <span className="booster-celebration__set">
            {name}
            {count !== null && <span className="booster-celebration__count"> {count}</span>}
          </span>
        )}
      </span>
    </div>
  )
}
