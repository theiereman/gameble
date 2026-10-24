// The booster island's view: everything Booster draws, from the island's
// state, its props and the countdown, with nothing of its own. The panel
// (or on the phone the strip) with the three actions, the stage (the
// canister's zone, the result head, the row of cards or the phone's pile,
// caption plate and tray, the banner, the flash), the phone's actions, the
// card zoom and the live region. The island hands it the elements it
// animates and the handlers its controls call.
import type { MouseEvent, Ref } from "react"
import BoosterBanner, { type Banner } from "./BoosterBanner"
import BoosterCanister, { type CanisterParts } from "./BoosterCanister"
import BoosterCard, { type CardGestures } from "./BoosterCard"
import BoosterCelebration from "./BoosterCelebration"
import BoosterPanel from "./BoosterPanel"
import BoosterPlate, { type PlateCard } from "./BoosterPlate"
import BoosterStrip from "./BoosterStrip"
import BoosterTray from "./BoosterTray"
import BoosterZoom from "./BoosterZoom"
import type { Announcement } from "./useLiveRegion"
import type { Rarity } from "../lib/card_types"
import type { CelebrationResult } from "../lib/celebration"
import { formatNumber, t } from "../lib/i18n"
import type { OpeningAnswer, OpeningCard } from "../lib/opening"
import { faceSize, formatClock, pileDepth, topOfPile, zoomNeighbour, type Layout } from "../lib/booster"
import { formatLocalTime } from "../lib/local_time"
import { cardHref } from "../lib/booster_page"
import type { BoosterBank, BoosterPhase, BoosterProps, BoosterStatus } from "../lib/booster_props"

const RESERVE_PIPS = 10

const localTime = (iso: string): string => formatLocalTime(iso, "datetime", { locale: document.documentElement.lang }) ?? iso

/** The island's state, as the view draws it. */
export type BoosterViewState = {
  phase: BoosterPhase
  status: BoosterStatus
  bank: BoosterBank
  answer: OpeningAnswer | null
  revealed: boolean[]
  revealedAt: (number | undefined)[]
  stored: boolean[]
  dealt: boolean
  armed: boolean
  headShown: boolean
  canisterAway: boolean
  /** Bumped by each new canister: it is drawn again, docked. */
  dock: number
  reason: string | null
  legendary: number | null
  banner: Banner | null
  revealingAll: boolean
  storing: boolean
  locked: boolean
  layout: Layout
  /** Bumped by a rebuild: the cards are drawn again, fresh, at rest. */
  stageKey: number
  zoom: number | null
  announcements: Announcement[]
  /** The set celebration's results once the hand is complete and no banner plays, else null. */
  celebration: CelebrationResult[] | null
  celebrationStill: boolean
}

/** The elements the island animates, measures or focuses. */
export type BoosterViewElements = {
  section: Ref<HTMLElement>
  canister: Ref<CanisterParts>
  shake: Ref<HTMLDivElement>
  flash: Ref<HTMLDivElement>
  fx: Ref<HTMLDivElement>
  openButton: Ref<HTMLButtonElement>
  backLink: Ref<HTMLAnchorElement>
  slotRefs: Ref<HTMLLIElement>[]
  traySlotRef: (index: number, element: HTMLElement | null) => void
}

/** What the view's controls ask of the island. */
export type BoosterViewHandlers = {
  open: () => Promise<void>
  revealAll: () => Promise<void>
  activateCard: (index: number) => void
  storeTop: () => void
  openZoom: (index: number) => void
  closeZoom: () => void
  /** The zoom's previous (-1) or next (1) filled tray slot. */
  stepZoom: (step: -1 | 1) => void
  /** "Voir la fiche" in the zoom. */
  seeZoomed: (event: MouseEvent<HTMLAnchorElement>) => void
  repost: (index: number) => Promise<string>
  endBanner: (key: number) => void
  /** The way back does nothing while the navigation is locked. */
  guardBack: (event: MouseEvent<HTMLAnchorElement>) => void
  leaveForAlbum: (event: MouseEvent<HTMLAnchorElement>) => void
  /** The swipe on the phone's revealed top card. */
  gestures: CardGestures
}

export type BoosterViewProps = {
  props: BoosterProps
  state: BoosterViewState
  /** Whole seconds to the next booster, or null. */
  left: number | null
  elements: BoosterViewElements
  handlers: BoosterViewHandlers
}

export default function BoosterView({ props, state, left, elements, handlers }: BoosterViewProps) {
  const { hubUrl, cardUrl, repostUrl, delimiter, season, packSize, rarityNames, rarityIcons, artPalette, arrowIcons, inProgressUrl, celebrationIcons, strings } = props
  const { phase, status, bank, answer, revealed, revealedAt, stored, dealt, armed, headShown, canisterAway, dock, reason, legendary, banner } = state
  const { revealingAll, storing, locked, layout, stageKey, zoom, announcements, celebration, celebrationStill } = state
  const { section, canister, shake, flash, fx, openButton, backLink, slotRefs, traySlotRef } = elements
  const { open, revealAll, activateCard, storeTop, openZoom, closeZoom, stepZoom, seeZoomed, repost, endBanner, guardBack, leaveForAlbum, gestures } = handlers
  const number = (value: number) => formatNumber(value, delimiter)
  const tierLabel = (tier: Rarity) => (tier === "legendary" ? t(strings.legendaryBanner, { rarity: rarityNames[tier] }) : rarityNames[tier])

  const cards = answer?.cards ?? []
  const total = cards.length
  const phone = layout === "phone"
  const revealedCount = revealed.filter(Boolean).length
  const storedCount = stored.filter(Boolean).length
  const everyRevealed = total > 0 && revealedCount === total
  const handOnTable = phase === "dealt" && total > 0
  const remaining = total - revealedCount
  const busy = phase === "opening" || revealingAll || locked || storing
  const empty = phase === "empty"
  // Before the answer, the size of the pack the next opening opens; after it, the answer's.
  const nextSize = bank.nextPackSize ?? packSize
  const shownSize = total || nextSize
  const seasonLine = season === null ? null : t(strings.canisterSeason, { number: season })
  const canisterLabel =
    season === null
      ? t(strings.canisterLabelPlain, { count: nextSize })
      : t(strings.canisterLabel, { season, count: nextSize })

  const openLabel = bank.available <= 0 && phase !== "opening" ? strings.reserveEmpty : phase === "dealt" ? strings.openNext : strings.open
  const openDisabled = (bank.available <= 0 && phase !== "opening") || (phase === "dealt" && !everyRevealed)
  const revealAllDisabled = !handOnTable || everyRevealed || revealingAll || storing || legendary !== null

  const statusTone = status === "arming" || status === "ejecting" ? "alert" : status === "legendarySignal" ? "gold" : status === "complete" ? "done" : "rest"
  const clock = left === null ? null : formatClock(left)
  const nextLine = !bank.reserveFull && clock !== null && bank.nextAvailableAt ? { clock, spoken: t(strings.nextAt, { time: localTime(bank.nextAvailableAt) }) } : null

  // The phone's pile: the cards not stored, the first on top.
  const top = handOnTable ? topOfPile(revealed, stored) : null
  const face = faceSize(layout)
  const cardBack = answer?.pack.cardBack ?? "standard"

  const hint =
    handOnTable
      ? phone
        ? top === null
          ? t(strings.hintDone, { count: total, n: number(total) })
          : revealed[top]
            ? strings.hintSwipe
            : strings.hintTap
        : remaining > 0
          ? t(strings.hintRemaining, { count: remaining, n: number(remaining) })
          : t(strings.hintDone, { count: total, n: number(total) })
      : null

  const topCard = top !== null && revealed[top] ? cards[top] : null
  const plate: PlateCard | null =
    phone && top !== null && topCard
      ? {
          key: `${answer?.pack.token}-${top}`,
          tier: topCard.tier,
          icon: rarityIcons[topCard.tier],
          tierText: tierLabel(topCard.tier),
          line: t(strings.bannerLine, { title: topCard.title, year: topCard.year ?? "" }),
        }
      : null

  const cardName = (card: OpeningCard, index: number) =>
    revealed[index]
      ? t(phone ? strings.faceUpStore : strings.faceUp, { card: card.label, rarity: rarityNames[card.tier] })
      : t(strings.faceDown, { position: index + 1, total })

  const dealtCards = cards.map((card, index) =>
    phone && stored[index] ? null : (
      <BoosterCard
        key={`${answer?.pack.token}-${index}`}
        index={index}
        tier={card.tier}
        face={card.faces[face]}
        cardBack={cardBack}
        dealt={dealt}
        revealed={revealed[index] ?? false}
        revealedAt={revealedAt[index]}
        legendary={legendary === index}
        name={cardName(card, index)}
        tierIcon={rarityIcons[card.tier]}
        tierLabel={tierLabel(card.tier)}
        slotRef={slotRefs[index]}
        onActivate={activateCard}
        repostLabel={strings.repost}
        repostName={t(strings.repostCard, { card: card.title })}
        onRepost={repostUrl === null ? null : repost}
        depth={phone ? pileDepth(index, stored) : null}
        gestures={phone && index === top && revealed[index] ? gestures : null}
      />
    ),
  )

  const openButtonElement = (
    <button
      type="button"
      ref={openButton}
      className="button button--primary booster__open"
      disabled={openDisabled}
      aria-disabled={!openDisabled && busy ? "true" : undefined}
      onClick={() => {
        if (!busy) void open()
      }}
    >
      {openLabel}
    </button>
  )
  const revealAllButton = (
    <button type="button" className="button button--secondary booster__reveal-all" disabled={revealAllDisabled} onClick={() => void revealAll()}>
      {strings.revealAll}
    </button>
  )
  const backButton = (
    <a
      ref={backLink}
      className="button button--secondary booster__back"
      href={hubUrl}
      aria-disabled={locked ? "true" : undefined}
      onClick={guardBack}
    >
      {strings.back}
    </a>
  )
  const reasonLine = reason && <p className="booster__reason">{reason}</p>

  const zoomed = zoom !== null && phone ? cards[zoom] : null

  const celebrationResults = celebration && (
    <BoosterCelebration
      key={answer?.pack.token}
      results={celebration}
      strings={strings.celebration}
      delimiter={delimiter}
      phone={phone}
      still={celebrationStill}
      inProgressUrl={inProgressUrl}
      icons={celebrationIcons}
      onLeave={leaveForAlbum}
    />
  )

  return (
    <section ref={section} className="booster" aria-labelledby="booster-title" data-phase={phase} data-layout={layout}>
      {phone ? (
        <BoosterStrip
          title={season === null ? strings.stripTitlePlain : t(strings.stripTitle, { number: season })}
          lit={Math.min(bank.available, RESERVE_PIPS)}
          pips={RESERVE_PIPS}
          reserveFull={bank.reserveFull ? strings.reserveFull : null}
          next={nextLine && { label: strings.nextIn, ...nextLine }}
          state={strings.states[status]}
          tone={statusTone}
        />
      ) : (
        <BoosterPanel
          kicker={season === null ? strings.kickerPlain : t(strings.kicker, { number: season })}
          title={strings.title}
          cardsPerPack={{ label: strings.cardsPerPack, value: number(shownSize) }}
          inReserve={{ label: strings.inReserve, value: t(strings.reserveCount, { count: bank.available, n: number(bank.available) }) }}
          state={{ label: strings.state, word: strings.states[status], tone: statusTone }}
          reserve={strings.reserve}
          reserveFull={bank.reserveFull ? strings.reserveFull : null}
          next={nextLine && { label: strings.nextIn, ...nextLine }}
          lit={Math.min(bank.available, RESERVE_PIPS)}
          pips={RESERVE_PIPS}
          actions={
            <>
              {openButtonElement}
              <div className="booster__actions-row">
                {revealAllButton}
                {backButton}
              </div>
              {reasonLine}
            </>
          }
          counter={t(strings.revealedCount, { revealed: phase === "dealt" ? number(revealedCount) : "—", total: number(shownSize) })}
          celebration={celebrationResults}
        />
      )}

      <div className="booster__stage" data-legendary={legendary !== null ? "" : undefined}>
        <div className="booster__shake" ref={shake}>
          <div className="booster__dim" aria-hidden="true" />
          <div className="booster__fx" ref={fx} aria-hidden="true" />

          {!canisterAway && (
            <div className="booster__zone">
              {empty ? (
                <p className="booster__empty">
                  <span className="booster__empty-title">{strings.reserveEmpty}</span>
                  {clock !== null && bank.nextAvailableAt && (
                    <span className="booster__empty-next">
                      <span aria-hidden="true">{t(strings.emptyNext, { time: clock })}</span>
                      <span className="visually-hidden">{t(strings.nextAt, { time: localTime(bank.nextAvailableAt) })}</span>
                    </span>
                  )}
                </p>
              ) : (
                <>
                  <BoosterCanister
                    key={dock}
                    ref={canister}
                    label={canisterLabel}
                    seasonLine={seasonLine}
                    titleLine={strings.title}
                    busy={phase !== "sealed" && phase !== "dealt"}
                    armed={armed}
                    onActivate={() => void open()}
                  />
                  <p className="booster__canister-hint" aria-hidden="true" data-hidden={phase !== "sealed" ? "" : undefined}>
                    {phone ? strings.canisterHintTouch : strings.canisterHint}
                  </p>
                  {phone && (
                    <p className="booster__canister-facts" aria-hidden="true" data-hidden={phase !== "sealed" ? "" : undefined}>
                      {t(strings.canisterFacts, { count: nextSize, n: number(nextSize) })}
                    </p>
                  )}
                </>
              )}
            </div>
          )}

          {!phone && (
            <div className="booster__result" data-shown={headShown ? "" : undefined} aria-hidden={headShown ? undefined : "true"}>
              <span className="booster__result-stripe" aria-hidden="true" />
              <span className="booster__result-title">{strings.result}</span>
              <span className="booster__result-stripe" aria-hidden="true" />
            </div>
          )}

          {total > 0 &&
            (phone ? (
              <>
                <div className="booster__pile-area">
                  <ol key={stageKey} className="booster__pile" aria-label={strings.result}>
                    {dealtCards}
                  </ol>
                </div>
                {dealt && (
                  <>
                    <BoosterPlate plate={plate} hint={hint} storeLabel={strings.store} storeBusy={busy} onStore={storeTop} celebration={celebrationResults} />
                    <BoosterTray
                      key={stageKey}
                      label={strings.tray}
                      countLabel={strings.trayLabel}
                      count={t(strings.trayCount, { n: number(storedCount), total: number(total) })}
                      slots={cards.map((card) => ({
                        tier: card.tier,
                        coverUrl: card.coverUrl,
                        name: t(strings.traySlot, { card: card.label, rarity: rarityNames[card.tier] }),
                      }))}
                      stored={stored}
                      rarityIcons={rarityIcons}
                      artPalette={artPalette}
                      busy={busy}
                      slotRef={traySlotRef}
                      onOpen={openZoom}
                    />
                  </>
                )}
              </>
            ) : (
              <div className="booster__deal-area">
                <ol key={stageKey} className="booster__deal" aria-label={strings.result}>
                  {dealtCards}
                </ol>
                {hint && <p className="booster__hint">{hint}</p>}
              </div>
            ))}
        </div>

        {banner && !phone && (
          <BoosterBanner
            key={banner.key}
            banner={banner}
            icon={rarityIcons[banner.tier]}
            name={banner.large ? t(strings.legendaryBanner, { rarity: rarityNames[banner.tier] }) : rarityNames[banner.tier]}
            onEnd={endBanner}
          />
        )}
        <div className="booster__flash" ref={flash} aria-hidden="true" />
      </div>

      {phone && (
        <div className="booster__phone-actions">
          <div className="booster__actions-row">
            {openButtonElement}
            {revealAllButton}
          </div>
          {backButton}
          {reasonLine}
        </div>
      )}

      {zoomed && zoom !== null && answer && (
        <BoosterZoom
          tier={zoomed.tier}
          title={zoomed.title}
          face={zoomed.faces.xl}
          icon={rarityIcons[zoomed.tier]}
          line={t(strings.zoomLine, { rarity: rarityNames[zoomed.tier], year: zoomed.year ?? "" })}
          href={cardHref(cardUrl, zoomed.slug, answer.pack.token, zoom)}
          seeCard={strings.seeCard}
          close={strings.close}
          tip={strings.zoomTip}
          previous={{ label: strings.zoomPrevious, icon: arrowIcons.previous, enabled: zoomNeighbour(stored, zoom, -1) !== null }}
          next={{ label: strings.zoomNext, icon: arrowIcons.next, enabled: zoomNeighbour(stored, zoom, 1) !== null }}
          onStep={stepZoom}
          onSee={seeZoomed}
          repost={repostUrl === null ? null : { label: strings.repost, name: t(strings.repostCard, { card: zoomed.title }), onRepost: () => repost(zoom) }}
          onClose={closeZoom}
        />
      )}

      <div className="visually-hidden" role="status" aria-live="polite">
        {announcements.map(({ key, text }) => (
          <span key={key}>{text}</span>
        ))}
      </div>
    </section>
  )
}
