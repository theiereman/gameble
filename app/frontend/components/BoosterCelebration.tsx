import { useState, type CSSProperties, type MouseEvent, type ReactNode } from "react"
import { t } from "../lib/i18n"
import {
  countParts,
  folded,
  foldedLinkName,
  foldedMarks,
  foldedSubline,
  foldedTitle,
  gaugeFractions,
  gaugeTicks,
  juice,
  nextResult,
  notchCount,
  resultLinkName,
  resultTitle,
  sparkOffsets,
  type CelebrationIcons,
  type CelebrationResult,
  type CelebrationStrings,
} from "../lib/celebration"
import type { SetTierName } from "../lib/opening"

export type BoosterCelebrationProps = {
  results: CelebrationResult[]
  strings: CelebrationStrings
  delimiter: string
  phone: boolean
  still: boolean
  inProgressUrl: string
  icons: CelebrationIcons
  onLeave: (event: MouseEvent<HTMLAnchorElement>) => void
}

const TICK_SPARK_RADIUS = 22
const END_SPARK_RADIUS = 34
const RIBBON_SPARK_RADIUS = 30

const cssVars = (values: Record<string, string | number>): CSSProperties => values as CSSProperties
const ms = (value: number): string => `${value}ms`

export default function BoosterCelebration({ results, strings, delimiter, phone, still, inProgressUrl, icons, onLeave }: BoosterCelebrationProps) {
  const [index, setIndex] = useState(0)
  const [steps, setSteps] = useState(0)
  if (results.length === 0) return null

  const isFolded = folded(results)
  const banner = (result: CelebrationResult, position: number, key?: string) => (
    <ResultBanner key={key} result={result} position={position} strings={strings} delimiter={delimiter} phone={phone} icons={icons} onLeave={onLeave} />
  )
  const foldedBanner = (
    <FoldedBanner results={results} strings={strings} phone={phone} url={inProgressUrl} icons={icons} onLeave={onLeave} />
  )

  if (!phone) {
    return (
      <ul className="booster-celebration" data-still={still ? "" : undefined}>
        {isFolded ? <li>{foldedBanner}</li> : results.map((result, position) => <li key={result.key}>{banner(result, position)}</li>)}
      </ul>
    )
  }

  const shown = Math.min(index, results.length - 1)
  const stepping = !isFolded && results.length > 1
  return (
    <div className="booster-celebration booster-celebration--phone" data-still={still && steps === 0 ? "" : undefined}>
      {isFolded ? foldedBanner : banner(results[shown], 0, `${results[shown].key}:${steps}`)}
      {stepping && (
        <div className="booster-celebration__step">
          <span className="booster-celebration__position">{t(strings.position, { index: shown + 1, count: results.length })}</span>
          <button
            type="button"
            className="button button--secondary booster-celebration__next"
            aria-label={strings.next}
            onClick={() => {
              setIndex(nextResult(shown, results.length))
              setSteps((count) => count + 1)
            }}
          >
            <Icon html={icons.next} />
          </button>
        </div>
      )}
    </div>
  )
}

type ResultBannerProps = {
  result: CelebrationResult
  position: number
  strings: CelebrationStrings
  delimiter: string
  phone: boolean
  icons: CelebrationIcons
  onLeave: (event: MouseEvent<HTMLAnchorElement>) => void
}

function ResultBanner({ result, position, strings, delimiter, phone, icons, onLeave }: ResultBannerProps) {
  const { from, to } = gaugeFractions(result)
  const { tickSparks, endSparks, ribbonSparks, glosses, glints } = juice(result.tier)
  const count = countParts(result, strings, delimiter)
  const complete = result.tier === "complete"
  return (
    <a
      className="booster-celebration__banner"
      href={result.url}
      data-tier={result.tier}
      data-turbo-prefetch="false"
      aria-label={resultLinkName(result, strings, delimiter)}
      onClick={onLeave}
      style={cssVars({ "--i": position, "--from": from, "--to": to })}
    >
      <Ribbon
        title={resultTitle(result, strings)}
        lead={complete ? <Icon html={icons.check} className="booster-celebration__check" /> : <Notches count={notchCount(result.tier)} />}
        glosses={glosses}
        glints={glints}
        sparks={ribbonSparks}
      />
      <span className="booster-celebration__row" aria-hidden="true">
        <span className="booster-celebration__name">
          <span>{result.name}</span>
          {complete && <span className="booster-celebration__stamp" />}
        </span>
        <span className="booster-celebration__count">
          <span className="booster-celebration__roll">
            <span>
              <span>{count.before}</span>
              <span>{count.owned}</span>
            </span>
          </span>
          <span className="booster-celebration__total">{count.rest}</span>
        </span>
      </span>
      <span className="booster-celebration__gauge" aria-hidden="true">
        <i className="booster-celebration__fill booster-celebration__fill--new" />
        <i className="booster-celebration__fill booster-celebration__fill--before" />
        {complete && (
          <>
            <i className="booster-celebration__lime" />
            <i className="booster-celebration__glow" />
            <span className="booster-celebration__end">
              <Sparks count={endSparks} radius={END_SPARK_RADIUS} />
            </span>
          </>
        )}
        {gaugeTicks(result).map((tick) => (
          <i
            key={tick.tier}
            className="booster-celebration__tick"
            data-tier={tick.tier}
            data-state={tick.state}
            style={tick.lightAt === null ? undefined : cssVars({ "--light": ms(tick.lightAt) })}
          >
            {!phone && <Notches count={notchCount(tick.tier)} />}
            {tick.tier === result.tier && <Sparks count={tickSparks} radius={TICK_SPARK_RADIUS} />}
          </i>
        ))}
      </span>
      <Hint phone={phone} text={strings.setHint} icons={icons} />
    </a>
  )
}

type FoldedBannerProps = {
  results: CelebrationResult[]
  strings: CelebrationStrings
  phone: boolean
  url: string
  icons: CelebrationIcons
  onLeave: (event: MouseEvent<HTMLAnchorElement>) => void
}

function FoldedBanner({ results, strings, phone, url, icons, onLeave }: FoldedBannerProps) {
  const subline = foldedSubline(results, strings)
  return (
    <a
      className="booster-celebration__banner"
      href={url}
      data-tier="folded"
      data-turbo-prefetch="false"
      aria-label={foldedLinkName(results, strings)}
      onClick={onLeave}
      style={cssVars({ "--i": 0 })}
    >
      <Ribbon title={foldedTitle(results, strings)} lead={null} glosses={0} glints={false} sparks={0} />
      <span className="booster-celebration__marks" aria-hidden="true">
        {foldedMarks(results).map(({ tier, lightAt }) => (
          <span key={tier} className="booster-celebration__mark" data-tier={tier}>
            <MarkShape tier={tier} />
            {lightAt !== null && (
              <span className="booster-celebration__mark-lit" style={cssVars({ "--light": ms(lightAt) })}>
                <MarkShape tier={tier} />
              </span>
            )}
          </span>
        ))}
      </span>
      <span className="booster-celebration__sub" aria-hidden="true">
        {subline.lead} <b>{subline.set}</b> {subline.tier}
      </span>
      <Hint phone={phone} text={strings.foldedHint} icons={icons} />
    </a>
  )
}

type RibbonProps = { title: string; lead: ReactNode; glosses: number; glints: boolean; sparks: number }

function Ribbon({ title, lead, glosses, glints, sparks }: RibbonProps) {
  return (
    <span className="booster-celebration__head" aria-hidden="true">
      <span className="booster-celebration__wipe">
        <span className="booster-celebration__ribbon">
          {lead}
          <span>{title}</span>
          {Array.from({ length: glosses }, (_, gloss) => (
            <i key={gloss} className="booster-celebration__gloss" />
          ))}
        </span>
      </span>
      <i className="booster-celebration__fold" />
      <Sparks count={sparks} radius={RIBBON_SPARK_RADIUS} />
      {glints && (
        <span className="booster-celebration__glints">
          <i />
          <i />
          <i />
        </span>
      )}
    </span>
  )
}

function Hint({ phone, text, icons }: { phone: boolean; text: string; icons: CelebrationIcons }) {
  if (phone) return <Icon html={icons.album} className="booster-celebration__album" />
  return (
    <span className="booster-celebration__hint" aria-hidden="true">
      {text}
      <Icon html={icons.next} />
    </span>
  )
}

function MarkShape({ tier }: { tier: SetTierName }) {
  return tier === "complete" ? <span className="booster-celebration__stamp" /> : <Notches count={notchCount(tier)} />
}

function Notches({ count }: { count: number }) {
  return (
    <span className="booster-celebration__notches">
      {Array.from({ length: count }, (_, notch) => (
        <i key={notch} />
      ))}
    </span>
  )
}

function Sparks({ count, radius }: { count: number; radius: number }) {
  if (count === 0) return null
  return (
    <span className="booster-celebration__sparks">
      {sparkOffsets(count, radius).map(({ dx, dy, k }, spark) => (
        <i key={spark} style={cssVars({ "--dx": `${dx}px`, "--dy": `${dy}px`, "--k": k })} />
      ))}
    </span>
  )
}

function Icon({ html, className }: { html: string; className?: string }) {
  return <span className={className ? `booster-celebration__icon-wrap ${className}` : "booster-celebration__icon-wrap"} aria-hidden="true" dangerouslySetInnerHTML={{ __html: html }} />
}
