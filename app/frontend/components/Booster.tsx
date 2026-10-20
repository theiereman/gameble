// The booster screen's island (EXPERIENCE.md: Booster, Opening protocol,
// Motion, Focus after each step; DESIGN.md: Booster canister, Booster
// information panel, Result banner, Reveal caption plate, Tray, Card zoom;
// AD-16, AD-23, AD-27).
//
// One activation of the canister (or "Ouvrir le booster") sends the
// opening exchange (lib/opening.ts) while the canister charges; the answer
// either blows the caps and deals the pack's cards face down, or disarms
// the canister and says why. One activation of a face-down card reveals
// it; "Tout révéler" reveals the rest; "Ouvrir le suivant" sinks the cards
// and docks a new canister. A revealed card leads to its detail, which
// walks the pack: before leaving, the island names the pack in its own
// history entry (`?pack=`), so Back shows the screen again with that pack
// dealt and every card face up (`props.opened`; on the phone, every card
// in the tray). The faces are the server's HTML; the island draws the
// back, the turn and the choreography, with WAAPI and CSS keyframes on
// transform and opacity only. Every word comes in the props.
// The chrome follows through `gameble:*` events only: the counts as each
// card shows (tier-revealed), the reserve on each answer (bank-changed),
// and the navigation lock during an opening and each reveal.
// Once the hand is complete and no banner plays, the set tiers the opening
// reached are celebrated and announced once (BoosterCelebration); they stay
// until the next capsule opens. A pack shown again celebrates nothing,
// except back from an album its celebration opened: its results, still.
// The bank is read again from the server (lib/booster_bank.ts) after a
// refusal, and when the countdown reaches zero: the screen is refreshed
// with no hand at rest, else the bank is fetched once the hand is put
// away; a dealt hand is never refreshed away.
//
// Three layouts (story 8.12), read from two media queries and carried as
// `data-layout` (the stylesheet sizes the stage from it): the wide row of
// card-m faces from 900px, the narrow row of card-s faces from 720px, and
// under 720px the phone's pile of card-xl faces, one at a time, with its
// information strip, caption plate, tray and card zoom. On the phone a
// revealed top card is stored in the tray (a tap, a swipe or "Ranger")
// instead of opening its page. A width crossing a breakpoint draws the
// island again in place once it is idle: the same pack, what was revealed
// and the counts kept, no request, nothing replayed.
//
// Here are the island's state and its protocol (opening, reveal, store,
// layout, focus); BoosterView draws it. The keyframes are in
// lib/booster_keyframes.ts, the effects in lib/booster_effects.ts, the props
// in lib/booster_props.ts, the page's helpers in lib/booster_page.ts; the
// timers, the navigation lock, the live region and the countdown are hooks
// (useIslandTimers, useNavigationLock, useLiveRegion, useBoosterCountdown),
// the banner is BoosterBanner.
//
// Cards go by position, never by slug: a pack can hold the same card twice.
import { useCallback, useEffect, useMemo, useRef, useState, type MouseEvent } from "react"
import { flushSync } from "react-dom"
import type { Banner } from "./BoosterBanner"
import type { CanisterParts } from "./BoosterCanister"
import BoosterView from "./BoosterView"
import { useAtZero, useCountdown } from "./useBoosterCountdown"
import { useCardSwipe } from "./useCardSwipe"
import { useIslandTimers } from "./useIslandTimers"
import { useLiveRegion } from "./useLiveRegion"
import { useNavigationLock } from "./useNavigationLock"
import type { Rarity } from "../lib/card_types"
import { dispatchGameble } from "../lib/events"
import { t } from "../lib/i18n"
import { motionReduced } from "../lib/motion"
import { celebrationAnnouncement, celebrationResults, restoredCelebration, type CelebrationResult } from "../lib/celebration"
import { sendOpening, type OpeningAnswer, type OpeningResult, type OpeningSetTier } from "../lib/opening"
import { repostHref, sendRepost } from "../lib/repost"
import {
  ARM_MS,
  ART_POLL,
  ART_WAIT_MAX,
  BODY_MS,
  CAPS_MS,
  COMMON_LIFT_MS,
  COMMON_LIFT_PX,
  DEAL_LAND_AT,
  DEAL_MS,
  DEAL_STAGGER,
  DOCK,
  DROP,
  EPIC_SHAKE_MS,
  FLASH_MS,
  FLIP_MS,
  HEAD_DELAY,
  IMPACT,
  IMPACT_AT,
  LAND_SHAKE_MS,
  LEGENDARY_FLASH_MS,
  LEGENDARY_JUMP,
  LEGENDARY_JUMP_PX,
  LEGENDARY_SHAKE_MS,
  LIFT_PX,
  MARK_AT,
  MARK_IN_SPIN,
  NARROW_QUERY,
  PHONE_DEAL_STAGGER,
  PHONE_QUERY,
  RAYS_FADE_MS,
  REVEAL_ALL_GAP,
  REVEAL_GUARD,
  RINGS,
  RM_CANISTER_FADE,
  RM_CARD_FADE,
  RM_FADE_STAGGER,
  RM_LEGENDARY_STILL,
  RM_REVEAL_FADE,
  SETTLE_MS,
  SHAKE_MS,
  SINK,
  SINK_STAGGER,
  SLOT_POP_MS,
  SPIN,
  SPRING_BACK_MS,
  STORE_MS,
  TREMBLE_MS,
  countsAfterReveal,
  dealKeyframes,
  dealOrder,
  dealRotation,
  keyAfter,
  layoutFor,
  phoneAllHold,
  phoneJump,
  phoneSwell,
  pileDepth,
  pileOrder,
  pilePose,
  pileTransform,
  planRevealAll,
  pose,
  revealSummary,
  revealingOpening,
  scaled,
  storedAfterRebuild,
  swipeStores,
  tierIndex,
  topOfPile,
  zoomNeighbour,
  type Layout,
  type TierCounts,
} from "../lib/booster"
import { atZero, fetchBank, handPutAway, owedBankDue, phaseForBank, type IslandMoment } from "../lib/booster_bank"
import { animate, blast, burst, ring, settle, stageFlash, stageShake, traySparks } from "../lib/booster_effects"
import {
  armKeyframes,
  bodyKeyframes,
  capBottomKeyframes,
  capTopKeyframes,
  dockKeyframes,
  fadeKeyframes,
  flipKeyframes,
  legendaryDropKeyframes,
  legendaryImpactKeyframes,
  legendaryJumpKeyframes,
  legendarySpinKeyframes,
  liftKeyframes,
  settleKeyframes,
  sinkKeyframes,
  slotPopKeyframes,
  springBackKeyframes,
  storeKeyframes,
  trembleKeyframes,
} from "../lib/booster_keyframes"
import { cardHref, celebrationRemembered, csrfToken, newKey, readLayout, refreshPage, rememberPack, visit } from "../lib/booster_page"
import type { BoosterBank, BoosterPhase as Phase, BoosterProps, BoosterStatus as Status } from "../lib/booster_props"

export type { BoosterBank, BoosterProps, BoosterStrings } from "../lib/booster_props"

/** A click this soon after a drag ends belongs to the drag: it never stores the card. */
const CLICK_AFTER_DRAG = 300

export default function Booster(props: BoosterProps) {
  const { openUrl, bankUrl, cardUrl, repostUrl, delimiter, rarityNames, strings } = props
  // The pack shown again: dealt, every card revealed past its guard (it
  // leads to its detail at once), on the phone every card in the tray.
  const [restored] = useState(() => {
    const opened = props.opened
    if (!opened) return null
    const revealedAll = opened.cards.map(() => true)
    const pastGuard = opened.cards.map(() => performance.now() - REVEAL_GUARD)
    return {
      answer: opened,
      revealed: revealedAll,
      revealedAt: pastGuard,
      stored: storedAfterRebuild(revealedAll, [], readLayout()),
      celebration: restoredCelebration(opened.setTiers, celebrationRemembered()),
    }
  })

  // ---- State, mirrored in refs for the choreography's async steps ----

  const [bank, setBank] = useState<BoosterBank>(props.bank)
  const bankRef = useRef(bank)
  const bankOwed = useRef(false)
  const bankGeneration = useRef(0)
  const [phase, setPhaseState] = useState<Phase>(restored ? "dealt" : props.bank.available > 0 ? "sealed" : "empty")
  const phaseRef = useRef(phase)
  const [status, setStatus] = useState<Status>(restored ? "complete" : props.bank.available > 0 ? "sealed" : "waiting")
  const [answer, setAnswer] = useState<OpeningAnswer | null>(restored?.answer ?? null)
  const answerRef = useRef<OpeningAnswer | null>(answer)
  const [revealed, setRevealedState] = useState<boolean[]>(restored?.revealed ?? [])
  const revealedRef = useRef<boolean[]>(revealed)
  const [revealedAt, setRevealedAt] = useState<(number | undefined)[]>(restored?.revealedAt ?? [])
  const revealedAtRef = useRef<(number | undefined)[]>(revealedAt)
  const [dealt, setDealt] = useState(restored !== null)
  const [armed, setArmed] = useState(false)
  const [headShown, setHeadShown] = useState(restored !== null)
  const [canisterAway, setCanisterAway] = useState(restored !== null)
  const [dock, setDock] = useState(0)
  const [reason, setReason] = useState<string | null>(null)
  const [legendary, setLegendary] = useState<number | null>(null)
  const [banner, setBanner] = useState<Banner | null>(null)
  const [revealingAll, setRevealingAllState] = useState(false)
  const revealingAllRef = useRef(false)
  // Cards whose reveal is running; a legendary sequence holds every other activation.
  const revealing = useRef(new Set<number>())
  const legendaryRunning = useRef(false)
  const opening = useRef(false)
  const counts = useRef<TierCounts | null>(null)
  // The idempotency key kept for the next activation (keyAfter), or null.
  const pendingKey = useRef<string | null>(null)

  // The layout the island is drawn in, and the one the width asks for once
  // the island is idle (applyLayout).
  const [layout, setLayoutState] = useState<Layout>(readLayout)
  const layoutRef = useRef(layout)
  const pendingLayout = useRef<Layout | null>(null)
  // Bumped by a rebuild: the cards are drawn again, fresh, at rest.
  const [stageKey, setStageKey] = useState(0)
  // The phone's tray: the cards stored, by position; a store running.
  const [stored, setStoredState] = useState<boolean[]>(restored?.stored ?? [])
  const storedRef = useRef<boolean[]>(stored)
  const [storing, setStoringState] = useState(false)
  const storingRef = useRef(false)
  // The tray slot whose card the zoom shows, or null.
  const [zoom, setZoom] = useState<number | null>(null)
  // The set celebration: the tiers this island's opening reached, waiting
  // for the hand to complete; then its results, shown once no banner plays
  // and announced once, until the next capsule opens.
  const celebrationPending = useRef<OpeningSetTier[] | null>(null)
  const [celebration, setCelebration] = useState<CelebrationResult[] | null>(restored?.celebration ?? null)
  const [celebrationStill, setCelebrationStill] = useState(celebration !== null)
  const celebrationAnnounced = useRef(celebration !== null)

  const revealingNow = revealingOpening(status)
  useEffect(() => dispatchGameble("gameble:opening-revealing", { revealing: revealingNow }), [revealingNow])
  useEffect(() => () => dispatchGameble("gameble:opening-revealing", { revealing: false }), [])

  const setPhase = (next: Phase) => {
    phaseRef.current = next
    setPhaseState(next)
  }
  const setBankBoth = (next: BoosterBank) => {
    bankRef.current = next
    setBank(next)
  }
  const setRevealingAll = (on: boolean) => {
    revealingAllRef.current = on
    setRevealingAllState(on)
  }
  const setStored = (next: boolean[]) => {
    storedRef.current = next
    setStoredState(next)
  }
  const setStoring = (on: boolean) => {
    storingRef.current = on
    setStoringState(on)
  }
  const phoneLayout = () => layoutRef.current === "phone"

  // ---- Elements ----

  const section = useRef<HTMLElement>(null)
  const canister = useRef<CanisterParts>(null)
  const shake = useRef<HTMLDivElement>(null)
  const flash = useRef<HTMLDivElement>(null)
  const fx = useRef<HTMLDivElement>(null)
  const openButton = useRef<HTMLButtonElement>(null)
  const backLink = useRef<HTMLAnchorElement>(null)
  const slots = useRef<(HTMLLIElement | null)[]>([])
  const slotRefs = useMemo(
    () =>
      Array.from({ length: 8 }, (_, index) => (element: HTMLLIElement | null) => {
        slots.current[index] = element
      }),
    [],
  )
  const traySlots = useRef<(HTMLElement | null)[]>([])
  const traySlotRef = useCallback((index: number, element: HTMLElement | null) => {
    traySlots.current[index] = element
  }, [])
  const part = (index: number, name: string) => slots.current[index]?.querySelector<HTMLElement>(`.booster-card__${name}`) ?? null

  // ---- Timers, the navigation lock (top bar back, tab bar, the island's own way back), the live region ----

  const { disposed, wait, later } = useIslandTimers()
  const { locked, depth: lockDepth, lock, unlock: releaseLock } = useNavigationLock()
  const unlock = () => releaseLock(whenIdle)
  const { announcements, announce } = useLiveRegion()

  // ---- Focus (EXPERIENCE.md, Focus after each step): asked for by a step,
  // given once the render that enables its target is committed ----

  // "card": the card to act on next (the pile's top card on the phone, the
  // first face-down card in a row), else "after"; "after": "Ouvrir le
  // suivant" (or the way back with an empty reserve); a tray slot.
  type FocusTarget = "open" | "back" | "card" | "after" | { slot: number }
  const focusNext = useRef<FocusTarget | null>(document.documentElement.hasAttribute("data-turbo-preview") ? null : props.bank.available > 0 ? "open" : "back")
  const requestFocus = (target: FocusTarget) => {
    focusNext.current = target
  }
  const cardToFocus = (): number | null => {
    if (phaseRef.current !== "dealt" || !answerRef.current) return null
    if (phoneLayout()) return topOfPile(revealedRef.current, storedRef.current)
    const index = revealedRef.current.findIndex((shown) => !shown)
    return index === -1 ? null : index
  }
  const focusElement = (target: FocusTarget): HTMLElement | null => {
    if (typeof target === "object") return traySlots.current[target.slot] ?? null
    if (target === "open") return openButton.current
    if (target === "back") return backLink.current
    if (target === "card") {
      const index = cardToFocus()
      if (index !== null) return part(index, "hit")
    }
    return bankRef.current.available > 0 ? openButton.current : backLink.current
  }
  useEffect(() => {
    const target = focusNext.current
    if (target === null) return
    const element = focusElement(target)
    if (!element || (element instanceof HTMLButtonElement && element.disabled)) return
    focusNext.current = null
    element.focus({ preventScroll: true })
  })

  // ---- The banner (Épique small, Légendaire large), decorative (BoosterBanner.tsx) ----

  const bannerKey = useRef(0)
  const showBanner = (tier: Rarity, large: boolean, line: string | null) => {
    bannerKey.current += 1
    setBanner({ key: bannerKey.current, tier, large, line, reduced: motionReduced() })
  }
  const endBanner = useCallback((key: number) => setBanner((current) => (current?.key === key ? null : current)), [])

  // ---- The set celebration (BoosterCelebration.tsx, lib/celebration.ts) ----

  /** The hand is complete: the tiers its opening reached, if any, are celebrated. */
  const celebrate = () => {
    const reached = celebrationPending.current
    celebrationPending.current = null
    if (!reached) return
    const results = celebrationResults(reached)
    if (results.length === 0) return
    celebrationAnnounced.current = false
    setCelebrationStill(false)
    setCelebration(results)
  }

  const leaveForAlbum = (event: MouseEvent<HTMLAnchorElement>) => {
    if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return
    const current = answerRef.current
    if (current) rememberPack(current.pack.token, true)
  }

  const celebrationShown = celebration !== null && banner === null
  useEffect(() => {
    if (!celebrationShown || celebration === null || celebrationAnnounced.current) return
    celebrationAnnounced.current = true
    announce(celebrationAnnouncement(celebration, strings.celebration, delimiter))
  }, [celebrationShown, celebration, announce, strings, delimiter])

  // ---- Bank ----

  const changeBank = (next: BoosterBank) => {
    bankGeneration.current += 1
    setBankBoth(next)
    const { available, reserveFull, nextAvailableAt, serverTime } = next
    dispatchGameble("gameble:bank-changed", { available, reserveFull, nextAvailableAt, serverTime })
  }

  const refreshBank = async () => {
    const generation = bankGeneration.current
    const fresh = await fetchBank({ url: bankUrl })
    if (!fresh || disposed.current || generation !== bankGeneration.current) return
    changeBank(fresh)
    const current = phaseRef.current
    const next = phaseForBank(current, fresh.available)
    if (next === current) return
    setPhase(next)
    setStatus(next === "sealed" ? "sealed" : "waiting")
    setReason(null)
  }

  // ---- Opening ----

  const refuse = (result: Exclude<OpeningResult, { kind: "opened" }>) => {
    const refused = result.kind === "refused"
    const message = refused ? result.message : strings.failed
    if (refused) bankOwed.current = false
    if (refused && result.code === "no_pack_available") changeBank({ ...bankRef.current, available: 0, reserveFull: false, nextPackSize: null })
    const empty = bankRef.current.available <= 0
    // The canister disarms without blowing: its squash is undone.
    settle(canister.current?.move)
    setArmed(false)
    setStatus(empty ? "waiting" : "sealed")
    setPhase(empty ? "empty" : "sealed")
    setReason(message)
    announce(message)
    dispatchGameble("gameble:toast", { title: strings.refusedTitle, message, tone: "alert" })
    opening.current = false
    unlock()
    // The canister leaves with an empty reserve: the focus goes to the way back.
    if (empty) requestFocus("back")
    if (refused) void refreshBank()
  }

  /** The cards sink and fade, then a new canister docks in (Ouvrir le suivant). */
  const retract = async () => {
    const count = answerRef.current?.cards.length ?? 0
    setHeadShown(false)
    if (!motionReduced()) {
      for (let index = 0; index < count; index++) {
        // Stored cards are in the tray already; a pile card sinks from its pose.
        const travel = part(index, "travel")
        const from = phoneLayout() ? pileTransform(pileDepth(index, storedRef.current)) : pose()
        settle(travel)
        animate(travel, sinkKeyframes(from), {
          duration: SINK,
          delay: index * SINK_STAGGER,
          easing: "cubic-bezier(.5,0,.8,.4)",
          fill: "forwards",
        })
      }
      await wait(SINK + (count - 1) * SINK_STAGGER)
    }
    answerRef.current = null
    revealedRef.current = []
    revealedAtRef.current = []
    flushSync(() => {
      setAnswer(null)
      setRevealedState([])
      setRevealedAt([])
      setStored([])
      setDealt(false)
      setArmed(false)
      setCelebration(null)
      setCanisterAway(false)
      setStatus("sealed")
      setDock((value) => value + 1)
    })
    if (!motionReduced()) {
      animate(canister.current?.wrap, dockKeyframes(), { duration: DOCK, easing: "cubic-bezier(.2,.9,.3,1)", fill: "none" })
      await wait(DOCK)
    }
  }

  /** The motion's opening: armed, the caps blow, the cards fly out (openA, arcadeDeal). */
  const blowAndDeal = async (count: number) => {
    const parts = canister.current
    setArmed(true)
    setStatus("ejecting")
    animate(parts?.capTop, capTopKeyframes(), { duration: CAPS_MS, easing: "cubic-bezier(.12,.8,.3,1)", fill: "forwards" })
    animate(parts?.capBottom, capBottomKeyframes(), { duration: CAPS_MS, easing: "cubic-bezier(.12,.8,.3,1)", fill: "forwards" })
    animate(parts?.body, bodyKeyframes(), { duration: BODY_MS, easing: "cubic-bezier(.5,0,1,.6)", fill: "forwards" })
    animate(parts?.rays, fadeKeyframes(1, 0), { duration: RAYS_FADE_MS, fill: "forwards" })
    blast(fx.current, canister.current?.button)
    stageFlash(flash.current, "warm", 0.35, FLASH_MS)
    stageShake(shake.current, 5, SHAKE_MS)
    await wait(HEAD_DELAY)
    setHeadShown(true)

    // Each card from the canister's centre to its slot, centre out; on the
    // phone to its place in the pile, the bottom card first.
    const origin = parts?.button?.getBoundingClientRect()
    const phone = phoneLayout()
    const stagger = phone ? PHONE_DEAL_STAGGER : DEAL_STAGGER
    flushSync(() => setDealt(true))
    let end = 0
    ;(phone ? pileOrder(count) : dealOrder(count)).forEach((index, position) => {
      const slot = slots.current[index]
      const travel = part(index, "travel")
      if (!slot || !travel || !origin) return
      const rect = slot.querySelector(".booster-card__frame")?.getBoundingClientRect() ?? slot.getBoundingClientRect()
      const dx = origin.left + origin.width / 2 - (rect.left + rect.width / 2)
      const dy = origin.top + origin.height / 2 - (rect.top + rect.height / 2)
      const delay = position * stagger
      const rest = phone ? pilePose(pileDepth(index, storedRef.current)) : undefined
      animate(travel, dealKeyframes(dx, dy, dealRotation(index, count), rest), { duration: DEAL_MS, delay, fill: "backwards", easing: "linear" })
      later(delay + DEAL_MS * DEAL_LAND_AT, () => stageShake(shake.current, 1.5, LAND_SHAKE_MS))
      end = Math.max(end, delay + DEAL_MS)
    })
    await wait(end)
  }

  /** Reduced motion: the canister fades out, the cards fade in (openRM). */
  const fadeAndDeal = async (count: number) => {
    animate(canister.current?.wrap, fadeKeyframes(1, 0), { duration: RM_CANISTER_FADE, fill: "forwards" })
    setHeadShown(true)
    flushSync(() => setDealt(true))
    for (let index = 0; index < count; index++) {
      animate(part(index, "travel"), fadeKeyframes(0, 1), { duration: RM_CARD_FADE, delay: index * RM_FADE_STAGGER, fill: "backwards" })
    }
    await wait(Math.max(RM_CANISTER_FADE, RM_CARD_FADE + (count - 1) * RM_FADE_STAGGER))
  }

  const open = async () => {
    if (opening.current || revealing.current.size > 0 || revealingAllRef.current || storingRef.current) return
    if (bankRef.current.available <= 0) return
    const current = phaseRef.current
    if (current === "dealt" && revealedRef.current.some((shown) => !shown)) return
    if (current !== "sealed" && current !== "dealt") return

    opening.current = true
    setReason(null)
    celebrationPending.current = null
    setCelebration(null)
    lock()
    if (current === "dealt") await retract()
    // A pack shown again is left behind: a reload shows the screen afresh.
    rememberPack(null)

    setPhase("opening")
    setStatus("arming")
    const key = pendingKey.current ?? newKey()
    pendingKey.current = key
    const reduced = motionReduced()
    if (!reduced) animate(canister.current?.move, armKeyframes(), { duration: ARM_MS, fill: "forwards" })
    const [result] = await Promise.all([sendOpening({ url: openUrl, key, csrfToken: csrfToken() }), wait(reduced ? 0 : ARM_MS)])
    if (disposed.current) return
    pendingKey.current = keyAfter(result.kind === "refused" ? { kind: "refused", code: result.code } : { kind: result.kind }, key)
    if (result.kind !== "opened") {
      refuse(result)
      return
    }

    const next = result.answer
    changeBank({
      available: next.bank.available,
      reserveFull: next.bank.reserveFull,
      nextAvailableAt: next.bank.nextAvailableAt,
      serverTime: next.serverTime,
      nextPackSize: next.bank.nextPackSize ?? null,
    })
    counts.current = { ...next.tierCountsBefore }
    celebrationPending.current = next.setTiers
    answerRef.current = next
    revealedRef.current = next.cards.map(() => false)
    revealedAtRef.current = next.cards.map(() => undefined)
    // The faces go in now, hidden, so their art starts loading at once.
    flushSync(() => {
      setAnswer(next)
      setRevealedState(revealedRef.current)
      setRevealedAt(revealedAtRef.current)
      setStored(next.cards.map(() => false))
    })

    if (motionReduced()) await fadeAndDeal(next.cards.length)
    else await blowAndDeal(next.cards.length)

    setCanisterAway(true)
    setStatus("inventory")
    setPhase("dealt")
    opening.current = false
    unlock()
    requestFocus("card")
  }

  // ---- Reveal: one path for a card and for Tout révéler ----

  const artReady = async (index: number) => {
    const started = performance.now()
    while (!slots.current[index]?.querySelector(".booster-card__front .card__art[data-art]") && performance.now() - started < ART_WAIT_MAX) {
      await wait(ART_POLL)
    }
  }

  /** The card shows what it is: its label and name, the live region, the top bar's count. */
  const mark = (index: number, quiet: boolean) => {
    const card = answerRef.current?.cards[index]
    if (!card) return
    revealedRef.current = revealedRef.current.map((shown, position) => shown || position === index)
    revealedAtRef.current = revealedAtRef.current.map((at, position) => (position === index ? performance.now() : at))
    setRevealedState(revealedRef.current)
    setRevealedAt(revealedAtRef.current)
    const before = counts.current ?? { common: 0, uncommon: 0, rare: 0, epic: 0, legendary: 0 }
    counts.current = countsAfterReveal(before, card.tier)
    dispatchGameble("gameble:tier-revealed", { tier: card.tier, counts: counts.current })
    if (!quiet) announce(t(strings.announceCard, { position: index + 1, card: card.label, rarity: rarityNames[card.tier] }))
  }

  /**
   * How far a card may rise: as the mock on wider screens; on the phone,
   * inside the stage (60 % of the room above the card, 50px at most).
   */
  const riseLimit = (index: number): number => {
    if (!phoneLayout()) return LEGENDARY_JUMP_PX
    const frame = slots.current[index]?.querySelector(".booster-card__frame")
    const stage = shake.current
    if (!frame || !stage) return 0
    return phoneJump(frame.getBoundingClientRect().top - stage.getBoundingClientRect().top)
  }

  /** A swell of the reveal (a scale): the mock's on wider screens, damped on the phone (phoneSwell). */
  const swell = (scale: number) => (phoneLayout() ? phoneSwell(scale) : scale)

  /** A common to epic card: tremble, flip, burst, settle (revealV3). */
  const revealTier = async (index: number, tier: Rarity, quiet: boolean) => {
    const level = tierIndex(tier)
    const lift = part(index, "lift")
    const flip = part(index, "flip")
    const height = Math.min(LIFT_PX[level] || COMMON_LIFT_PX, riseLimit(index))
    settle(lift)
    if (TREMBLE_MS[level] > 0) {
      animate(lift, trembleKeyframes(level, height, swell), { duration: TREMBLE_MS[level], fill: "forwards" })
      await wait(TREMBLE_MS[level])
    } else {
      animate(lift, liftKeyframes(height, swell), { duration: COMMON_LIFT_MS, easing: "ease-out", fill: "forwards" })
      await wait(COMMON_LIFT_MS)
    }

    animate(flip, flipKeyframes(), { duration: FLIP_MS[level], easing: "cubic-bezier(.3,.1,.3,1)", fill: "none" })
    await wait(FLIP_MS[level] * MARK_AT)
    mark(index, quiet)
    if (level >= 3) stageShake(shake.current, 5, EPIC_SHAKE_MS)
    const host = part(index, "fx")
    burst(host, tier)
    if (host) {
      const { width, height: boxHeight } = host.getBoundingClientRect()
      for (let count = 0; count < RINGS[level]; count++) {
        ring(host, `booster-fx__ring booster-fx__ring--${count % 2 === 0 ? "tier" : "white"}`, width / 2, boxHeight / 2 - height, 110 + level * 30, scaled(count * 90))
      }
    }
    // On the phone the caption plate shows the tier: no banner over the card.
    if (level === 3 && !phoneLayout()) showBanner(tier, false, null)
    settle(lift)
    animate(lift, settleKeyframes(height, swell), { duration: SETTLE_MS[level], easing: "cubic-bezier(.2,.8,.3,1)", fill: "none" })
    await wait(SETTLE_MS[level])
  }

  /** The Légendaire sequence (legendV3): dim, jump and charge, spin, impact, banner, drop. */
  const revealLegendary = async (index: number, quiet: boolean) => {
    const card = answerRef.current?.cards[index]
    const lift = part(index, "lift")
    const flip = part(index, "flip")
    // The jump: 50px, or what the phone's stage leaves above the card.
    const rise = riseLimit(index)
    legendaryRunning.current = true
    setLegendary(index)
    setStatus("legendarySignal")
    announce(strings.states.legendarySignal)

    settle(lift)
    animate(lift, legendaryJumpKeyframes(rise, swell), { duration: LEGENDARY_JUMP, fill: "forwards" })
    await wait(LEGENDARY_JUMP)

    animate(flip, legendarySpinKeyframes(), { duration: SPIN, easing: "cubic-bezier(.2,.6,.3,1)", fill: "none" })
    later(MARK_IN_SPIN, () => mark(index, quiet))
    await wait(IMPACT_AT)

    settle(lift)
    animate(lift, legendaryImpactKeyframes(rise, swell), { duration: scaled(360), easing: "ease-out", fill: "forwards" })
    const host = part(index, "fx")
    burst(host, "legendary")
    if (host && !motionReduced()) {
      const { width, height } = host.getBoundingClientRect()
      ;[0, 100, 200].forEach((delay, count) =>
        ring(host, `booster-fx__ring booster-fx__ring--${count % 2 === 0 ? "tier" : "white"}`, width / 2, height / 2 - rise, 200 + count * 60, scaled(delay)),
      )
    }
    stageFlash(flash.current, "gold", 0.5, LEGENDARY_FLASH_MS)
    stageShake(shake.current, 8, LEGENDARY_SHAKE_MS)
    if (!phoneLayout()) showBanner("legendary", true, card ? t(strings.bannerLine, { title: card.title, year: card.year ?? "" }) : null)
    await wait(IMPACT)

    setLegendary(null)
    legendaryRunning.current = false
    setStatus("inventory")
    settle(lift)
    animate(lift, legendaryDropKeyframes(rise, swell), { duration: DROP, easing: "cubic-bezier(.3,1.5,.5,1)", fill: "none" })
    later(scaled(300), () => stageShake(shake.current, 2, scaled(120)))
    await wait(DROP)
  }

  /** Reduced motion: the face crossfades in; a Légendaire holds a still banner (revealRM). */
  const revealStill = async (index: number, tier: Rarity, quiet: boolean) => {
    const card = answerRef.current?.cards[index]
    if (tier === "legendary") {
      setStatus("legendarySignal")
      announce(strings.states.legendarySignal)
    }
    mark(index, quiet)
    animate(part(index, "lift"), fadeKeyframes(0.2, 1), { duration: RM_REVEAL_FADE, fill: "none" })
    if (tier === "legendary") {
      // On the phone the still "Légendaire !" is the caption plate's.
      if (!phoneLayout()) showBanner("legendary", true, card ? t(strings.bannerLine, { title: card.title, year: card.year ?? "" }) : null)
      await wait(RM_LEGENDARY_STILL)
      legendaryRunning.current = false
      setStatus("inventory")
    } else {
      await wait(RM_REVEAL_FADE)
    }
  }

  const allRevealed = () => revealedRef.current.length > 0 && revealedRef.current.every(Boolean)

  /** Every card shown: INVENTAIRE COMPLET, the focus on what comes next, the set celebration. */
  const complete = () => {
    setStatus("complete")
    requestFocus(bankRef.current.available > 0 ? "open" : "back")
    celebrate()
  }

  const reveal = async (index: number, fromAll: boolean): Promise<void> => {
    const card = answerRef.current?.cards[index]
    if (!card || phaseRef.current !== "dealt" || revealedRef.current[index] || revealing.current.has(index)) return
    if (!fromAll && (revealingAllRef.current || legendaryRunning.current)) return
    revealing.current.add(index)
    // Locked from the activation: the art wait is part of the reveal, and a
    // Légendaire holds every other activation from then on.
    lock()
    if (card.tier === "legendary") legendaryRunning.current = true
    await artReady(index)
    if (disposed.current) return
    if (motionReduced()) await revealStill(index, card.tier, fromAll)
    else if (card.tier === "legendary") await revealLegendary(index, fromAll)
    else await revealTier(index, card.tier, fromAll)
    revealing.current.delete(index)
    // On the phone the booster is complete once its last card is stored.
    if (!fromAll && !phoneLayout() && revealing.current.size === 0 && allRevealed()) complete()
    unlock()
  }

  const revealAll = async () => {
    const current = answerRef.current
    if (!current || phaseRef.current !== "dealt" || revealingAllRef.current || legendaryRunning.current || storingRef.current) return
    if (phoneLayout()) {
      await revealAndStoreAll(current)
      return
    }
    const plan = planRevealAll(
      current.cards.map((card) => card.tier),
      revealedRef.current.map((shown, index) => shown || revealing.current.has(index)),
    )
    if (plan.length === 0) return
    setRevealingAll(true)
    const running: Promise<void>[] = []
    for (const { index, wait: hold } of plan) {
      const done = reveal(index, true)
      running.push(done)
      if (hold === "full") await done
      else await wait(REVEAL_ALL_GAP)
    }
    await Promise.all(running)
    while (revealing.current.size > 0) await wait(ART_POLL)
    setRevealingAll(false)
    announce(
      revealSummary(
        plan.map(({ index }) => current.cards[index].tier),
        { summary: strings.summary, summaryTier: strings.summaryTier, rarityNames, delimiter },
      ),
    )
    if (allRevealed()) complete()
    whenIdle()
  }

  // ---- The phone: the pile, the tray, the zoom ----

  /**
   * Tout révéler on the phone: each card on top of the pile in turn is
   * revealed (a Légendaire in full), shown a moment, then stored; one
   * summary of the cards it revealed.
   */
  const revealAndStoreAll = async (current: OpeningAnswer) => {
    setRevealingAll(true)
    // A reveal already running on the top card ends first.
    while (revealing.current.size > 0) {
      await wait(ART_POLL)
    }
    const shown: Rarity[] = []
    for (let index = 0; index < current.cards.length; index++) {
      if (disposed.current || answerRef.current !== current) return
      if (storedRef.current[index]) continue
      if (!revealedRef.current[index]) {
        await reveal(index, true)
        shown.push(current.cards[index].tier)
      }
      await wait(phoneAllHold(current.cards[index].tier))
      await store(index, true)
    }
    setRevealingAll(false)
    if (shown.length > 0) {
      announce(revealSummary(shown, { summary: strings.summary, summaryTier: strings.summaryTier, rarityNames, delimiter }))
    }
    if (storedRef.current.every(Boolean)) complete()
    whenIdle()
  }

  /** Nothing runs: no opening, no reveal, no Tout révéler, no store. */
  const idle = () =>
    !opening.current && revealing.current.size === 0 && !revealingAllRef.current && !storingRef.current && lockDepth.current === 0 && phaseRef.current !== "opening"

  const islandMoment = (): IslandMoment => ({
    phase: phaseRef.current,
    idle: idle(),
    handPutAway: handPutAway(layoutRef.current, revealedRef.current, storedRef.current),
  })

  const whenIdle = () => {
    applyLayout()
    if (!bankOwed.current || !owedBankDue(islandMoment())) return
    bankOwed.current = false
    void refreshBank()
  }

  /**
   * The phone's revealed top card may be stored now: by a tap, a swipe or
   * "Ranger" once its guard is over and nothing runs; by Tout révéler at
   * once.
   */
  const canStore = (index: number, fromAll: boolean): boolean => {
    if (!phoneLayout() || phaseRef.current !== "dealt" || !answerRef.current?.cards[index]) return false
    if (!revealedRef.current[index] || storedRef.current[index] || storingRef.current) return false
    if (topOfPile(revealedRef.current, storedRef.current) !== index) return false
    if (fromAll) return true
    if (lockDepth.current > 0 || opening.current || revealingAllRef.current || revealing.current.size > 0) return false
    const at = revealedAtRef.current[index]
    return at !== undefined && performance.now() - at >= REVEAL_GUARD
  }

  /**
   * A revealed top card goes into its tray slot: it shrinks into the slot
   * (from where a swipe left it), leaves the pile, the slot pops, an
   * Épique or better adds sparks (lib/booster_effects.ts, traySparks); the
   * focus goes to the next top card, or after the last to "Ouvrir le
   * suivant" (the booster complete).
   */
  const store = async (index: number, fromAll: boolean): Promise<void> => {
    if (!canStore(index, fromAll)) return
    const card = answerRef.current?.cards[index]
    if (!card) return
    setStoring(true)
    const float = part(index, "float")
    const frame = slots.current[index]?.querySelector(".booster-card__frame")
    const target = traySlots.current[index]
    const start = float?.style.transform || "none"
    if (float) float.style.transform = ""
    if (!motionReduced() && float && frame && target) {
      settle(float)
      animate(float, storeKeyframes(start, frame.getBoundingClientRect(), target.getBoundingClientRect()), {
        duration: STORE_MS,
        easing: "cubic-bezier(.45,0,.6,1)",
        fill: "forwards",
      })
      await wait(STORE_MS)
    }
    if (disposed.current) return
    flushSync(() => setStored(storedRef.current.map((done, position) => done || position === index)))
    if (!motionReduced()) {
      animate(traySlots.current[index], slotPopKeyframes(), { duration: SLOT_POP_MS, easing: "cubic-bezier(.2,1.35,.35,1)" })
      traySparks(fx.current, traySlots.current[index], card.tier)
    }
    const everyStored = storedRef.current.every(Boolean)
    if (everyStored && !fromAll) complete()
    else if (!fromAll) requestFocus("card")
    setStoring(false)
    whenIdle()
  }

  /** A short drag let go: the card springs back to the top of the pile, still revealed. */
  const springBack = (index: number) => {
    const float = part(index, "float")
    if (!float) return
    const from = float.style.transform || "none"
    float.style.transform = ""
    if (!motionReduced()) animate(float, springBackKeyframes(from), { duration: SPRING_BACK_MS, easing: "cubic-bezier(.2,1.6,.4,1)" })
  }

  // The swipe on the revealed top card: stored after a long enough move,
  // else (or after a tilt, or a cancelled pointer) back on the pile.
  const swipe = useCardSwipe({
    canStart: (index) => canStore(index, false),
    slot: (index) => slots.current[index] ?? null,
    float: (index) => part(index, "float"),
    release: (index, dx, dy, abandoned) => {
      if (!abandoned && swipeStores(dx, dy) && canStore(index, false)) void store(index, false)
      else springBack(index)
    },
  })

  /** "Ranger" on the caption plate: the top card into the tray. */
  const storeTop = () => {
    const index = topOfPile(revealedRef.current, storedRef.current)
    if (index !== null) void store(index, false)
  }

  /** A filled tray slot opens the card zoom, while nothing runs. */
  const openZoom = useCallback((index: number) => {
    if (!idle() || !storedRef.current[index]) return
    setZoom(index)
  }, [])

  const closeZoom = () => {
    const index = zoom
    requestFocus(index === null ? "card" : { slot: index })
    setZoom(null)
  }

  /** The zoom's ◀ ▶ and swipe: the previous or next filled tray slot, in booster order. */
  const stepZoom = (step: -1 | 1) => {
    setZoom((index) => (index === null ? null : (zoomNeighbour(storedRef.current, index, step) ?? index)))
  }

  /** A card's detail, walking the pack, once the screen's history entry names the pack. */
  const leaveFor = (index: number) => {
    const current = answerRef.current
    const card = current?.cards[index]
    if (!current || !card) return
    rememberPack(current.pack.token)
    visit(cardHref(cardUrl, card.slug, current.pack.token, index))
  }

  const repost = useCallback(
    async (index: number) => {
      const card = answerRef.current?.cards[index]
      if (!card || repostUrl === null) return ""
      const result = await sendRepost({ url: repostHref(repostUrl, card.slug, card.season), csrfToken: csrfToken() })
      const message = result.kind === "reposted" ? strings.reposted : result.kind === "refused" ? result.message : strings.repostFailed
      dispatchGameble("gameble:toast", { message, tone: result.kind === "reposted" ? "notice" : "alert" })
      return message
    },
    [repostUrl, strings],
  )

  /** "Voir la fiche" in the zoom: the way out of a card; a new tab or window stays the browser's. */
  const seeZoomed = (event: MouseEvent<HTMLAnchorElement>) => {
    if (zoom === null || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return
    event.preventDefault()
    leaveFor(zoom)
  }

  // ---- The layout: a width crossing 720 or 900px draws the island again ----

  /**
   * Applies the layout the width asks for, once the island is idle: the
   * cards drawn again at rest in the new layout (stageKey), the revealed
   * ones stored when entering the phone, every one back in the row when
   * leaving it; no request, nothing replayed, the counts kept. A focus
   * inside the island lands on the same control in the new layout.
   */
  const applyLayout = () => {
    const next = pendingLayout.current
    if (next === null || !idle()) return
    pendingLayout.current = null
    if (next === layoutRef.current) return
    const focused = section.current?.contains(document.activeElement) ?? false
    swipe.forget()
    layoutRef.current = next
    if (focused) requestFocus("card")
    setStored(storedAfterRebuild(revealedRef.current, storedRef.current, next))
    // Every card shown (on the phone, a last one left on the pile): the hand is complete in either layout.
    if (phaseRef.current === "dealt" && allRevealed()) {
      setStatus("complete")
      celebrate()
    }
    setLayoutState(next)
    setStageKey((value) => value + 1)
    setZoom(null)
    setBanner(null)
  }

  useEffect(() => {
    if (typeof window.matchMedia !== "function") return
    const phone = window.matchMedia(PHONE_QUERY)
    const narrow = window.matchMedia(NARROW_QUERY)
    const onChange = () => {
      pendingLayout.current = layoutFor(phone.matches, narrow.matches)
      whenIdle()
    }
    phone.addEventListener("change", onChange)
    narrow.addEventListener("change", onChange)
    // The width may have changed between the first drawing and now.
    onChange()
    return () => {
      phone.removeEventListener("change", onChange)
      narrow.removeEventListener("change", onChange)
    }
    // whenIdle reads refs only.
  }, [])

  /** A face-down card reveals; a revealed one opens its card page once its guard is over. */
  const activateCard = useCallback(
    (index: number) => {
      const card = answerRef.current?.cards[index]
      if (!card) return
      if (revealedRef.current[index]) {
        // On the phone a tap stores it (a click that ends a drag does not).
        if (layoutRef.current === "phone") {
          if (performance.now() - swipe.lastDragEnd() >= CLICK_AFTER_DRAG) void store(index, false)
          return
        }
        // No leaving while the navigation is locked (a reveal, Tout révéler, an opening).
        if (lockDepth.current > 0 || opening.current || revealingAllRef.current) return
        const at = revealedAtRef.current[index]
        if (revealing.current.has(index) || at === undefined || performance.now() - at < REVEAL_GUARD) return
        leaveFor(index)
        return
      }
      void reveal(index, false)
    },
    // reveal and leaveFor read refs only; the card page's pattern is fixed.
    [cardUrl],
  )

  // ---- The countdown, the view (BoosterView.tsx) ----

  const left = useCountdown(bank.nextAvailableAt, bank.serverTime)

  useAtZero(left, () => {
    if (disposed.current) return
    const action = atZero(islandMoment())
    if (action === "page") refreshPage()
    else if (action === "bank") void refreshBank()
    else bankOwed.current = true
  })

  /** The way back does nothing while the navigation is locked. */
  const guardBack = (event: MouseEvent<HTMLAnchorElement>) => {
    if (lockDepth.current > 0) event.preventDefault()
  }

  return (
    <BoosterView
      props={props}
      state={{
        phase, status, bank, answer, revealed, revealedAt, stored, dealt, armed, headShown, canisterAway, dock, reason, legendary, banner,
        revealingAll, storing, locked, layout, stageKey, zoom, announcements,
        celebration: celebrationShown ? celebration : null,
        celebrationStill,
      }}
      left={left}
      elements={{ section, canister, shake, flash, fx, openButton, backLink, slotRefs, traySlotRef }}
      handlers={{ open, revealAll, activateCard, storeTop, openZoom, closeZoom, stepZoom, seeZoomed, repost, endBanner, guardBack, leaveForAlbum, gestures: swipe.gestures }}
    />
  )
}
