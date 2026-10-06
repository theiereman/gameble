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
// and docks a new canister. The faces are the server's HTML; the island
// draws the back, the turn and the choreography, with WAAPI and CSS
// keyframes on transform and opacity only. Every word comes in the props.
// The chrome follows through `gameble:*` events only: the counts as each
// card shows (tier-revealed), the reserve on each answer (bank-changed),
// and the navigation lock during an opening and each reveal.
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
// Cards go by position, never by slug: a pack can hold the same card twice.
import { useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState } from "react"
import { flushSync } from "react-dom"
import BoosterCanister, { type CanisterParts } from "./BoosterCanister"
import BoosterCard from "./BoosterCard"
import BoosterPanel from "./BoosterPanel"
import BoosterPlate, { type PlateCard } from "./BoosterPlate"
import BoosterStrip from "./BoosterStrip"
import BoosterTray from "./BoosterTray"
import BoosterZoom from "./BoosterZoom"
import { useCardSwipe } from "./useCardSwipe"
import type { Rarity } from "../lib/card_types"
import { dispatchGameble } from "../lib/events"
import { formatNumber, t, type Template } from "../lib/i18n"
import { motionReduced } from "../lib/motion"
import { sendOpening, type OpeningAnswer, type OpeningCard, type OpeningResult } from "../lib/opening"
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
  DOCK_PX,
  DROP,
  EPIC_BANNER_MS,
  EPIC_SHAKE_MS,
  FLASH_MS,
  FLIP_MS,
  HEAD_DELAY,
  IMPACT,
  IMPACT_AT,
  LAND_SHAKE_MS,
  LEGENDARY_BANNER_MS,
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
  SINK_PX,
  SINK_STAGGER,
  SLOT_POP_MS,
  SPIN,
  SPRING_BACK_MS,
  STORE_MS,
  TRAY_SPARKS,
  TREMBLE_MS,
  burstPixels,
  countsAfterReveal,
  dealKeyframes,
  dealOrder,
  dealRotation,
  faceSize,
  formatClock,
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
  scaled,
  secondsUntil,
  shakeKeyframes,
  storedAfterRebuild,
  swipeStores,
  tierIndex,
  topOfPile,
  utcTime,
  type Layout,
  type TierCounts,
} from "../lib/booster"

type Status = "sealed" | "arming" | "ejecting" | "inventory" | "legendarySignal" | "complete" | "waiting"

/** Every word of the island (`boosters.island`, BoostersHelper#booster_props). */
export type BoosterStrings = {
  kicker: string
  kickerPlain: string
  title: string
  cardsPerPack: string
  inReserve: string
  reserveCount: Template
  state: string
  states: Record<Status, string>
  reserve: string
  nextIn: string
  nextAt: string
  reserveFull: string
  open: string
  openNext: string
  reserveEmpty: string
  emptyNext: string
  revealAll: string
  back: string
  revealedCount: string
  canisterLabel: string
  canisterLabelPlain: string
  canisterHint: string
  canisterSeason: string
  result: string
  hintRemaining: Template
  hintDone: Template
  faceDown: string
  faceUp: string
  announceCard: string
  summary: Template
  summaryTier: Template
  legendaryBanner: string
  bannerLine: string
  refusedTitle: string
  failed: string
  islandFailed: string
  reload: string
  // The phone (story 8.12).
  stripTitle: string
  stripTitlePlain: string
  canisterHintTouch: string
  canisterFacts: Template
  hintTap: string
  hintSwipe: string
  store: string
  faceUpStore: string
  tray: string
  trayLabel: string
  trayCount: string
  traySlot: string
  zoomLine: string
  seeCard: string
  close: string
  zoomTip: string
}

export type BoosterBank = {
  available: number
  reserveFull: boolean
  nextAvailableAt: string | null
  serverTime: string
  /** The card count of the pack the next opening opens (3 for a daily bonus pack first in line), null when none is available. */
  nextPackSize: number | null
}

export type BoosterProps = {
  /** The opening exchange's URL (packs#create). */
  openUrl: string
  hubUrl: string
  /** A card's page, its slug in place of SLUG. */
  cardUrl: string
  /** The locale's digit delimiter. */
  delimiter: string
  /** The published season's number, null without one. */
  season: number | null
  /** The cards of a regular pack: the size shown when the next pack's is not known. */
  packSize: number
  bank: BoosterBank
  rarityNames: Record<Rarity, string>
  /** Each tier's pixel icon, as HTML. */
  rarityIcons: Record<Rarity, string>
  strings: BoosterStrings
}

/** Where the island is: the canister sealed, the reserve empty, an opening running, cards dealt. */
type Phase = "sealed" | "empty" | "opening" | "dealt"

type Banner = { key: number; tier: Rarity; large: boolean; line: string | null; reduced: boolean }

/** The live region keeps the latest few announcements; older ones are spoken already. */
const ANNOUNCEMENTS_KEPT = 5
const RESERVE_PIPS = 10

/** The layout the viewport's width asks for (lib/booster.ts, layoutFor). */
function readLayout(): Layout {
  if (typeof window === "undefined" || typeof window.matchMedia !== "function") return "wide"
  return layoutFor(window.matchMedia(PHONE_QUERY).matches, window.matchMedia(NARROW_QUERY).matches)
}

/** A click this soon after a drag ends belongs to the drag: it never stores the card. */
const CLICK_AFTER_DRAG = 300

/** A UUID for the idempotency key (crypto.randomUUID needs a secure context). */
function newKey(): string {
  if (typeof crypto.randomUUID === "function") return crypto.randomUUID()
  const bytes = crypto.getRandomValues(new Uint8Array(16))
  bytes[6] = (bytes[6] & 0x0f) | 0x40
  bytes[8] = (bytes[8] & 0x3f) | 0x80
  const hex = Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("")
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`
}

function csrfToken(): string | null {
  return document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content || null
}

type TurboVisit = { visit(location: string, options?: { action?: "advance" | "replace" }): void }

function visit(url: string): void {
  const turbo = (window as unknown as { Turbo?: TurboVisit }).Turbo
  if (turbo) turbo.visit(url)
  else window.location.assign(url)
}

/** The screen again from the server, in place (as countdown_controller.ts refreshes the hub). */
function refreshPage(): void {
  const turbo = (window as unknown as { Turbo?: TurboVisit }).Turbo
  if (turbo) turbo.visit(location.href, { action: "replace" })
  else location.reload()
}

/** A second after the countdown's zero: the new booster has had time to arrive. */
const REFRESH_AFTER_ZERO = 1000

const easeOut = (progress: number) => 1 - (1 - progress) ** 3

/** Whole seconds to the next booster, counting down, paused while the page is hidden. */
function useCountdown(nextAvailableAt: string | null, serverTime: string): number | null {
  const [left, setLeft] = useState(() => secondsUntil(nextAvailableAt, serverTime))
  useEffect(() => {
    const total = secondsUntil(nextAvailableAt, serverTime)
    setLeft(total)
    if (total === null) return
    const deadline = performance.now() + total * 1000
    let timer: number | undefined
    const tick = () => {
      timer = undefined
      const ms = deadline - performance.now()
      const seconds = Math.max(0, Math.ceil(ms / 1000))
      setLeft(seconds)
      if (seconds > 0 && !document.hidden) timer = window.setTimeout(tick, Math.max(16, ms - (seconds - 1) * 1000))
    }
    const onVisibility = () => {
      if (document.hidden) {
        window.clearTimeout(timer)
        timer = undefined
      } else if (timer === undefined) {
        tick()
      }
    }
    tick()
    document.addEventListener("visibilitychange", onVisibility)
    return () => {
      window.clearTimeout(timer)
      document.removeEventListener("visibilitychange", onVisibility)
    }
  }, [nextAvailableAt, serverTime])
  return left
}

export default function Booster(props: BoosterProps) {
  const { openUrl, hubUrl, cardUrl, delimiter, season, packSize, rarityNames, rarityIcons, strings } = props
  const number = useCallback((value: number) => formatNumber(value, delimiter), [delimiter])

  // ---- State, mirrored in refs for the choreography's async steps ----

  const [bank, setBank] = useState<BoosterBank>(props.bank)
  const bankRef = useRef(bank)
  const [phase, setPhaseState] = useState<Phase>(props.bank.available > 0 ? "sealed" : "empty")
  const phaseRef = useRef(phase)
  const [status, setStatus] = useState<Status>(props.bank.available > 0 ? "sealed" : "waiting")
  const [answer, setAnswer] = useState<OpeningAnswer | null>(null)
  const answerRef = useRef<OpeningAnswer | null>(null)
  const [revealed, setRevealedState] = useState<boolean[]>([])
  const revealedRef = useRef<boolean[]>([])
  const [revealedAt, setRevealedAt] = useState<(number | undefined)[]>([])
  const revealedAtRef = useRef<(number | undefined)[]>([])
  const [dealt, setDealt] = useState(false)
  const [armed, setArmed] = useState(false)
  const [headShown, setHeadShown] = useState(false)
  const [canisterAway, setCanisterAway] = useState(false)
  const [dock, setDock] = useState(0)
  const [reason, setReason] = useState<string | null>(null)
  const [legendary, setLegendary] = useState<number | null>(null)
  const [banner, setBanner] = useState<Banner | null>(null)
  const [locked, setLocked] = useState(false)
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
  const [stored, setStoredState] = useState<boolean[]>([])
  const storedRef = useRef<boolean[]>([])
  const [storing, setStoringState] = useState(false)
  const storingRef = useRef(false)
  // The tray slot whose card the zoom shows, or null.
  const [zoom, setZoom] = useState<number | null>(null)

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
  const bannerElement = useRef<HTMLDivElement>(null)
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

  // ---- Timers and listeners go with the island ----

  const disposed = useRef(false)
  const timers = useRef(new Set<number>())
  const lockDepth = useRef(0)

  const wait = useCallback(
    (ms: number) =>
      new Promise<void>((resolve) => {
        const timer = window.setTimeout(() => {
          timers.current.delete(timer)
          // Unmounted: the sequence stops here, its promise left pending.
          if (!disposed.current) resolve()
        }, Math.max(0, ms))
        timers.current.add(timer)
      }),
    [],
  )
  const later = useCallback(
    (ms: number, action: () => void) => {
      void wait(ms).then(action)
    },
    [wait],
  )

  useEffect(() => {
    disposed.current = false
    const pending = timers.current
    return () => {
      disposed.current = true
      pending.forEach((timer) => window.clearTimeout(timer))
      pending.clear()
      if (lockDepth.current > 0) {
        lockDepth.current = 0
        dispatchGameble("gameble:navigation-locked", { locked: false })
      }
    }
  }, [])

  // ---- Navigation lock (top bar back, tab bar, the island's own way back) ----

  const lock = () => {
    if (lockDepth.current++ === 0) {
      setLocked(true)
      dispatchGameble("gameble:navigation-locked", { locked: true })
    }
  }
  const unlock = () => {
    if (lockDepth.current === 0) return
    if (--lockDepth.current === 0) {
      setLocked(false)
      dispatchGameble("gameble:navigation-locked", { locked: false })
      applyLayout()
    }
  }

  // ---- The live region: a new node per message, so each is spoken ----

  const [announcements, setAnnouncements] = useState<{ key: number; text: string }[]>([])
  const announce = useCallback(
    (text: string) =>
      setAnnouncements((previous) => [...previous.slice(-(ANNOUNCEMENTS_KEPT - 1)), { key: (previous.at(-1)?.key ?? 0) + 1, text }]),
    [],
  )

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

  // ---- Effects drawn as plain spans, transform and opacity only ----

  const animate = (element: Element | null | undefined, keyframes: Keyframe[], options: KeyframeAnimationOptions) =>
    element && typeof element.animate === "function" ? element.animate(keyframes, options) : null

  /** Cancels every animation the island left on an element (fills included). */
  const settle = (element: Element | null | undefined) => element?.getAnimations?.().forEach((animation) => animation.cancel())

  const stageShake = (amplitude: number, duration: number) => {
    if (motionReduced()) return
    animate(shake.current, shakeKeyframes(amplitude), { duration, fill: "none" })
  }

  const stageFlash = (tone: "warm" | "gold", peak: number, duration: number) => {
    if (motionReduced() || !flash.current) return
    flash.current.dataset.tone = tone
    animate(flash.current, [{ opacity: 0 }, { opacity: peak, offset: 0.12 }, { opacity: 0 }], { duration, easing: "ease-out", fill: "none" })
  }

  /** A short-lived span in `host` at (x, y), animated, then removed. */
  const spark = (
    host: HTMLElement,
    className: string,
    x: number,
    y: number,
    keyframes: Keyframe[],
    options: KeyframeAnimationOptions,
    size?: number,
  ) => {
    const element = document.createElement("span")
    element.className = className
    element.style.left = `${Math.round(x)}px`
    element.style.top = `${Math.round(y)}px`
    if (size !== undefined) {
      element.style.width = `${size}px`
      element.style.height = `${size}px`
    }
    host.append(element)
    const animation = animate(element, keyframes, { fill: "forwards", ...options })
    const remove = () => element.remove()
    if (animation) animation.finished.then(remove, remove)
    else remove()
  }

  const ring = (host: HTMLElement, className: string, x: number, y: number, size: number, delay = 0) =>
    spark(
      host,
      className,
      x - size / 2,
      y - size / 2,
      [{ transform: "scale(0.2)", opacity: 1 }, { transform: "scale(1)", opacity: 0 }],
      { duration: scaled(380), delay, easing: "cubic-bezier(.2,.8,.3,1)", fill: "both" },
      size,
    )

  /** The pixels flying off a card as it shows, in its tier's colours. */
  const burst = (index: number, tier: Rarity) => {
    const host = part(index, "fx")
    if (!host || motionReduced()) return
    const { width, height } = host.getBoundingClientRect()
    burstPixels(tier, width, height).forEach(({ x, y, dx, dy }, position) =>
      spark(host, `booster-fx__pixel booster-fx__pixel--${position % 3}`, x, y, [
        { transform: "translate(0px, 0px)", opacity: 1 },
        { transform: `translate(${dx}px, ${dy}px)`, opacity: 0 },
      ], { duration: scaled(420 + 40 * tierIndex(tier)), easing: "steps(4)" }),
    )
  }

  /** The blast at the canister: a ring, sparks and smoke puffs. */
  const blast = () => {
    const host = fx.current
    const body = canister.current?.button
    if (!host || !body || motionReduced()) return
    const box = host.getBoundingClientRect()
    const rect = body.getBoundingClientRect()
    const x = rect.left + rect.width / 2 - box.left
    const y = rect.top + rect.height / 2 - box.top
    ring(host, "booster-fx__ring booster-fx__ring--blast", x, y, 220)
    for (let index = 0; index < 14; index++) {
      const angle = (index / 14) * Math.PI * 2 + 0.3
      const reach = 90 + (index % 3) * 50
      spark(host, `booster-fx__spark booster-fx__spark--${index % 4}`, x, y, [
        { transform: "translate(0px, 0px)", opacity: 1 },
        { transform: `translate(${Math.round(Math.cos(angle) * reach)}px, ${Math.round(Math.sin(angle) * reach)}px)`, opacity: 0 },
      ], { duration: scaled(480), easing: "cubic-bezier(.15,.8,.3,1)" })
    }
    for (let index = 0; index < 6; index++) {
      const side = index % 2 === 0 ? -1 : 1
      const top = index < 3 ? -1 : 1
      spark(host, "booster-fx__smoke", x + side * 70, y + top * 110, [
        { transform: "translate(0px, 0px) scale(0.6)", opacity: 0.5 },
        { transform: `translate(${side * 40}px, ${top * 50}px) scale(2.4)`, opacity: 0 },
      ], { duration: scaled(520 + index * 30), easing: "ease-out" })
    }
  }

  // ---- The banner (Épique small, Légendaire large), decorative ----

  const bannerKey = useRef(0)
  const showBanner = (tier: Rarity, large: boolean, line: string | null) => {
    bannerKey.current += 1
    setBanner({ key: bannerKey.current, tier, large, line, reduced: motionReduced() })
  }
  useLayoutEffect(() => {
    if (!banner) return
    const element = bannerElement.current
    const duration = banner.reduced ? RM_LEGENDARY_STILL : banner.large ? LEGENDARY_BANNER_MS : EPIC_BANNER_MS
    const keyframes: Keyframe[] = banner.reduced
      ? [{ opacity: 0 }, { opacity: 1, offset: 0.15 }, { opacity: 1, offset: 0.85 }, { opacity: 0 }]
      : [
          { opacity: 0, transform: "translateY(0px) scale(2.2, 0.2)" },
          { opacity: 1, transform: "translateY(0px) scale(0.86, 1.24)", offset: 0.1 },
          { opacity: 1, transform: "translateY(0px) scale(1.06, 0.95)", offset: 0.18 },
          { opacity: 1, transform: "translateY(0px) scale(1, 1)", offset: 0.26 },
          { opacity: 1, transform: "translateY(0px) scale(1, 1)", offset: 0.8 },
          { opacity: 0, transform: "translateY(-16px) scale(1, 1)" },
        ]
    animate(element, keyframes, { duration, fill: "none" })
    const key = banner.key
    const timer = window.setTimeout(() => setBanner((current) => (current?.key === key ? null : current)), duration)
    return () => window.clearTimeout(timer)
  }, [banner])

  // ---- Bank ----

  const changeBank = (next: BoosterBank) => {
    setBankBoth(next)
    const { available, reserveFull, nextAvailableAt, serverTime } = next
    dispatchGameble("gameble:bank-changed", { available, reserveFull, nextAvailableAt, serverTime })
  }

  // ---- Opening ----

  const refuse = (result: Exclude<OpeningResult, { kind: "opened" }>) => {
    const message = result.kind === "refused" ? result.message : strings.failed
    if (result.kind === "refused" && result.code === "no_pack_available") changeBank({ ...bankRef.current, available: 0, reserveFull: false, nextPackSize: null })
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
        animate(travel, [{ transform: from, opacity: 1 }, { transform: pose(0, SINK_PX, 0, 0.92), opacity: 0 }], {
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
      setCanisterAway(false)
      setStatus("sealed")
      setDock((value) => value + 1)
    })
    if (!motionReduced()) {
      animate(canister.current?.wrap, [
        { transform: `translateY(${DOCK_PX}px)`, opacity: 0 },
        { transform: "translateY(-8px)", opacity: 1, offset: 0.75 },
        { transform: "none", opacity: 1 },
      ], { duration: DOCK, easing: "cubic-bezier(.2,.9,.3,1)", fill: "none" })
      await wait(DOCK)
    }
  }

  /** The motion's opening: armed, the caps blow, the cards fly out (openA, arcadeDeal). */
  const blowAndDeal = async (count: number) => {
    const parts = canister.current
    setArmed(true)
    setStatus("ejecting")
    animate(parts?.capTop, [
      { transform: pose(), opacity: 1 },
      { transform: pose(-60, -300, -230), opacity: 1, offset: 0.72 },
      { transform: pose(-76, -360, -290), opacity: 0 },
    ], { duration: CAPS_MS, easing: "cubic-bezier(.12,.8,.3,1)", fill: "forwards" })
    animate(parts?.capBottom, [
      { transform: pose(), opacity: 1 },
      { transform: pose(70, 270, 210), opacity: 1, offset: 0.72 },
      { transform: pose(88, 330, 260), opacity: 0 },
    ], { duration: CAPS_MS, easing: "cubic-bezier(.12,.8,.3,1)", fill: "forwards" })
    animate(parts?.body, [
      { transform: pose(), opacity: 1 },
      { transform: pose(0, 0, 0, 1.16, 0.9), opacity: 1, offset: 0.35 },
      { transform: pose(0, 0, 0, 1.3, 1.3), opacity: 0 },
    ], { duration: BODY_MS, easing: "cubic-bezier(.5,0,1,.6)", fill: "forwards" })
    animate(parts?.rays, [{ opacity: 1 }, { opacity: 0 }], { duration: RAYS_FADE_MS, fill: "forwards" })
    blast()
    stageFlash("warm", 0.35, FLASH_MS)
    stageShake(5, SHAKE_MS)
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
      later(delay + DEAL_MS * DEAL_LAND_AT, () => stageShake(1.5, LAND_SHAKE_MS))
      end = Math.max(end, delay + DEAL_MS)
    })
    await wait(end)
  }

  /** Reduced motion: the canister fades out, the cards fade in (openRM). */
  const fadeAndDeal = async (count: number) => {
    animate(canister.current?.wrap, [{ opacity: 1 }, { opacity: 0 }], { duration: RM_CANISTER_FADE, fill: "forwards" })
    setHeadShown(true)
    flushSync(() => setDealt(true))
    for (let index = 0; index < count; index++) {
      animate(part(index, "travel"), [{ opacity: 0 }, { opacity: 1 }], { duration: RM_CARD_FADE, delay: index * RM_FADE_STAGGER, fill: "backwards" })
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
    lock()
    if (current === "dealt") await retract()

    setPhase("opening")
    setStatus("arming")
    const key = pendingKey.current ?? newKey()
    pendingKey.current = key
    const reduced = motionReduced()
    if (!reduced) {
      animate(canister.current?.move, [
        { transform: pose(), easing: "cubic-bezier(.4,0,.6,1)" },
        { transform: pose(0, 8, 0, 1.1, 0.9), offset: 0.4, easing: "cubic-bezier(.3,.9,.4,1)" },
        { transform: pose(-1.5, -2, -1, 0.96, 1.06), offset: 0.62 },
        { transform: pose(1.5, -3, 1, 0.97, 1.07), offset: 0.76 },
        { transform: pose(-1, -4, -1, 0.96, 1.09), offset: 0.9 },
        { transform: pose(0, -4, 0, 0.95, 1.1) },
      ], { duration: ARM_MS, fill: "forwards" })
    }
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

  const tierLabel = (tier: Rarity) => (tier === "legendary" ? t(strings.legendaryBanner, { rarity: rarityNames[tier] }) : rarityNames[tier])

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
      const steps = Math.max(4, Math.round(TREMBLE_MS[level] / scaled(40)))
      const amplitude = level * 0.9
      const keyframes: Keyframe[] = [{ transform: pose() }]
      for (let step = 1; step < steps; step++) {
        const progress = step / steps
        const side = step % 2 === 1 ? 1 : -1
        keyframes.push({ transform: pose(side * amplitude * progress * 0.8, -height * easeOut(progress), side * amplitude * progress * 0.6, swell(1 + 0.06 * easeOut(progress))) })
      }
      keyframes.push({ transform: pose(0, -height, 0, swell(1.06)) })
      animate(lift, keyframes, { duration: TREMBLE_MS[level], fill: "forwards" })
      await wait(TREMBLE_MS[level])
    } else {
      animate(lift, [{ transform: pose() }, { transform: pose(0, -height, 0, swell(1.03)) }], { duration: COMMON_LIFT_MS, easing: "ease-out", fill: "forwards" })
      await wait(COMMON_LIFT_MS)
    }

    animate(flip, [
      { transform: "rotateY(0deg)" },
      { transform: "rotateY(200deg)", offset: 0.72 },
      { transform: "rotateY(172deg)", offset: 0.88 },
      { transform: "rotateY(180deg)" },
    ], { duration: FLIP_MS[level], easing: "cubic-bezier(.3,.1,.3,1)", fill: "none" })
    await wait(FLIP_MS[level] * MARK_AT)
    mark(index, quiet)
    if (level >= 3) stageShake(5, EPIC_SHAKE_MS)
    burst(index, tier)
    const host = part(index, "fx")
    if (host) {
      const { width, height: boxHeight } = host.getBoundingClientRect()
      for (let count = 0; count < RINGS[level]; count++) {
        ring(host, `booster-fx__ring booster-fx__ring--${count % 2 === 0 ? "tier" : "white"}`, width / 2, boxHeight / 2 - height, 110 + level * 30, scaled(count * 90))
      }
    }
    // On the phone the caption plate shows the tier: no banner over the card.
    if (level === 3 && !phoneLayout()) showBanner(tier, false, null)
    settle(lift)
    animate(lift, [
      { transform: pose(0, -height, 0, swell(1.06)) },
      { transform: pose(0, -height * 0.4, 0, swell(1.14), swell(0.9)), offset: 0.25 },
      { transform: pose(0, 4, 0, swell(0.95), swell(1.06)), offset: 0.6 },
      { transform: pose() },
    ], { duration: SETTLE_MS[level], easing: "cubic-bezier(.2,.8,.3,1)", fill: "none" })
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

    const jump: Keyframe[] = [{ transform: pose() }]
    for (let step = 1; step <= 14; step++) {
      const progress = step / 14
      const side = step % 2 === 1 ? 1 : -1
      jump.push({
        transform: pose(side * progress * 3, -rise * easeOut(Math.min(1, progress * 1.6)), side * (1 + progress * 4), swell(1 + 0.15 * easeOut(progress))),
      })
    }
    jump.push({ transform: pose(0, -rise, 0, swell(1.15)) })
    settle(lift)
    animate(lift, jump, { duration: LEGENDARY_JUMP, fill: "forwards" })
    await wait(LEGENDARY_JUMP)

    animate(flip, [{ transform: "rotateY(0deg)" }, { transform: "rotateY(560deg)", offset: 0.8 }, { transform: "rotateY(540deg)" }], {
      duration: SPIN,
      easing: "cubic-bezier(.2,.6,.3,1)",
      fill: "none",
    })
    later(MARK_IN_SPIN, () => mark(index, quiet))
    await wait(IMPACT_AT)

    settle(lift)
    animate(lift, [
      { transform: pose(0, -rise, 0, swell(1.15)) },
      { transform: pose(0, -rise + 4, 0, swell(1.28), swell(1.02)), offset: 0.22 },
      { transform: pose(0, -rise - 2, 0, swell(1.08), swell(1.22)), offset: 0.5 },
      { transform: pose(0, -rise, 0, swell(1.15)) },
    ], { duration: scaled(360), easing: "ease-out", fill: "forwards" })
    burst(index, "legendary")
    const host = part(index, "fx")
    if (host && !motionReduced()) {
      const { width, height } = host.getBoundingClientRect()
      ;[0, 100, 200].forEach((delay, count) =>
        ring(host, `booster-fx__ring booster-fx__ring--${count % 2 === 0 ? "tier" : "white"}`, width / 2, height / 2 - rise, 200 + count * 60, scaled(delay)),
      )
    }
    stageFlash("gold", 0.5, LEGENDARY_FLASH_MS)
    stageShake(8, LEGENDARY_SHAKE_MS)
    if (!phoneLayout()) showBanner("legendary", true, card ? t(strings.bannerLine, { title: card.title, year: card.year ?? "" }) : null)
    await wait(IMPACT)

    setLegendary(null)
    legendaryRunning.current = false
    setStatus("inventory")
    settle(lift)
    animate(lift, [{ transform: pose(0, -rise, 0, swell(1.15)) }, { transform: pose() }], {
      duration: DROP,
      easing: "cubic-bezier(.3,1.5,.5,1)",
      fill: "none",
    })
    later(scaled(300), () => stageShake(2, scaled(120)))
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
    animate(part(index, "lift"), [{ opacity: 0.2 }, { opacity: 1 }], { duration: RM_REVEAL_FADE, fill: "none" })
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

  /** Every card shown: INVENTAIRE COMPLET, the focus on what comes next. */
  const complete = () => {
    setStatus("complete")
    requestFocus(bankRef.current.available > 0 ? "open" : "back")
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
    applyLayout()
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
    applyLayout()
  }

  /** Nothing runs: no opening, no reveal, no Tout révéler, no store. */
  const idle = () =>
    !opening.current && revealing.current.size === 0 && !revealingAllRef.current && !storingRef.current && lockDepth.current === 0 && phaseRef.current !== "opening"

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

  /** The sparks of an Épique or better landing in its tray slot. */
  const traySparks = (index: number, tier: Rarity) => {
    const host = fx.current
    const slot = traySlots.current[index]
    if (!host || !slot || motionReduced() || tierIndex(tier) < 3) return
    const box = host.getBoundingClientRect()
    const rect = slot.getBoundingClientRect()
    const x = rect.left + rect.width / 2 - box.left
    const y = rect.top + rect.height / 2 - box.top
    for (let count = 0; count < TRAY_SPARKS; count++) {
      const angle = (count / TRAY_SPARKS) * Math.PI * 2
      const reach = 26 + (count % 3) * 8
      spark(host, `booster-fx__pixel booster-fx__pixel--${count % 3} booster-fx--${tier}`, x - 2, y - 2, [
        { transform: "translate(0px, 0px)", opacity: 1 },
        { transform: `translate(${Math.round(Math.cos(angle) * reach / 2) * 2}px, ${Math.round(Math.sin(angle) * reach / 2) * 2}px)`, opacity: 0 },
      ], { duration: scaled(380), easing: "steps(4)" })
    }
  }

  /**
   * A revealed top card goes into its tray slot: it shrinks into the slot
   * (from where a swipe left it), leaves the pile, the slot pops, an
   * Épique or better adds sparks; the focus goes to the next top card, or
   * after the last to "Ouvrir le suivant" (the booster complete).
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
      const from = frame.getBoundingClientRect()
      const to = target.getBoundingClientRect()
      const dx = to.left + to.width / 2 - (from.left + from.width / 2)
      const dy = to.top + to.height / 2 - (from.top + from.height / 2)
      const end = `translate(${Math.round(dx)}px, ${Math.round(dy)}px) scale(${(to.width / Math.max(1, from.width)).toFixed(3)})`
      settle(float)
      animate(float, [
        { transform: start, opacity: 1 },
        { transform: end, opacity: 1, offset: 0.82 },
        { transform: end, opacity: 0 },
      ], { duration: STORE_MS, easing: "cubic-bezier(.45,0,.6,1)", fill: "forwards" })
      await wait(STORE_MS)
    }
    if (disposed.current) return
    flushSync(() => setStored(storedRef.current.map((done, position) => done || position === index)))
    if (!motionReduced()) {
      animate(traySlots.current[index], [
        { transform: "scale(1)" },
        { transform: "scale(1.22)", offset: 0.4 },
        { transform: "scale(1)" },
      ], { duration: SLOT_POP_MS, easing: "cubic-bezier(.2,1.35,.35,1)" })
      traySparks(index, card.tier)
    }
    const everyStored = storedRef.current.every(Boolean)
    if (everyStored && !fromAll) complete()
    else if (!fromAll) requestFocus("card")
    setStoring(false)
    applyLayout()
  }

  /** A short drag let go: the card springs back to the top of the pile, still revealed. */
  const springBack = (index: number) => {
    const float = part(index, "float")
    if (!float) return
    const from = float.style.transform || "none"
    float.style.transform = ""
    if (!motionReduced()) animate(float, [{ transform: from }, { transform: "none" }], { duration: SPRING_BACK_MS, easing: "cubic-bezier(.2,1.6,.4,1)" })
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
    if (phaseRef.current === "dealt" && allRevealed()) setStatus("complete")
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
      applyLayout()
    }
    phone.addEventListener("change", onChange)
    narrow.addEventListener("change", onChange)
    // The width may have changed between the first drawing and now.
    onChange()
    return () => {
      phone.removeEventListener("change", onChange)
      narrow.removeEventListener("change", onChange)
    }
    // applyLayout reads refs only.
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
        visit(cardUrl.replace("SLUG", encodeURIComponent(card.slug)))
        return
      }
      void reveal(index, false)
    },
    // reveal reads refs only; the card page's pattern is fixed.
    [cardUrl],
  )

  // ---- Rendering ----

  const left = useCountdown(bank.nextAvailableAt, bank.serverTime)

  // The countdown reaching zero while the page is shown: a second later the
  // screen refreshes, so the new booster can be opened, but only while the
  // island is idle (canister at rest or reserve empty, nothing running).
  // A clock already at zero when the page drew never refreshes it.
  const previousLeft = useRef(left)
  useEffect(() => {
    const before = previousLeft.current
    previousLeft.current = left
    if (!(before !== null && before > 0 && left === 0)) return
    const timer = window.setTimeout(() => {
      const idle =
        (phaseRef.current === "sealed" || phaseRef.current === "empty") &&
        lockDepth.current === 0 &&
        !opening.current &&
        revealing.current.size === 0
      if (idle && !disposed.current) refreshPage()
    }, REFRESH_AFTER_ZERO)
    return () => window.clearTimeout(timer)
  }, [left])

  const cards = answer?.cards ?? []
  const total = cards.length
  const phone = layout === "phone"
  const revealedCount = revealed.filter(Boolean).length
  const storedCount = stored.filter(Boolean).length
  const everyRevealed = total > 0 && revealedCount === total
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
  const revealAllDisabled = phase !== "dealt" || everyRevealed || revealingAll || storing || legendary !== null

  const statusTone = status === "arming" || status === "ejecting" ? "alert" : status === "legendarySignal" ? "gold" : status === "complete" ? "done" : "rest"
  const clock = left === null ? null : formatClock(left)
  const nextLine = !bank.reserveFull && clock !== null && bank.nextAvailableAt ? { clock, spoken: t(strings.nextAt, { time: utcTime(bank.nextAvailableAt) }) } : null

  // The phone's pile: the cards not stored, the first on top.
  const top = phase === "dealt" && total > 0 ? topOfPile(revealed, stored) : null
  const face = faceSize(layout)
  const cardBack = answer?.pack.cardBack ?? "standard"

  const hint =
    phase === "dealt" && total > 0
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
        depth={phone ? pileDepth(index, stored) : null}
        gestures={phone && index === top && revealed[index] ? swipe.gestures : null}
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
      onClick={(event) => {
        if (lockDepth.current > 0) event.preventDefault()
      }}
    >
      {strings.back}
    </a>
  )
  const reasonLine = reason && <p className="booster__reason">{reason}</p>

  const zoomed = zoom !== null && phone ? cards[zoom] : null

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
                      <span className="visually-hidden">{t(strings.nextAt, { time: utcTime(bank.nextAvailableAt) })}</span>
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
                    <BoosterPlate plate={plate} hint={hint} storeLabel={strings.store} storeBusy={busy} onStore={storeTop} />
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
          <div
            key={banner.key}
            ref={bannerElement}
            className={banner.large ? "booster__banner booster__banner--large" : "booster__banner"}
            data-tier={banner.tier}
            aria-hidden="true"
          >
            <div className="booster__banner-row">
              <span className="booster__banner-stripe" />
              <span className="booster__banner-icon" dangerouslySetInnerHTML={{ __html: rarityIcons[banner.tier] }} />
              <span className="booster__banner-name">
                {banner.large ? t(strings.legendaryBanner, { rarity: rarityNames[banner.tier] }) : rarityNames[banner.tier]}
              </span>
              <span className="booster__banner-icon" dangerouslySetInnerHTML={{ __html: rarityIcons[banner.tier] }} />
              <span className="booster__banner-stripe" />
            </div>
            {banner.line && <p className="booster__banner-line">{banner.line}</p>}
          </div>
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

      {zoomed && zoom !== null && (
        <BoosterZoom
          key={zoom}
          tier={zoomed.tier}
          title={zoomed.title}
          face={zoomed.faces.xl}
          icon={rarityIcons[zoomed.tier]}
          line={t(strings.zoomLine, { rarity: rarityNames[zoomed.tier], year: zoomed.year ?? "" })}
          href={cardUrl.replace("SLUG", encodeURIComponent(zoomed.slug))}
          seeCard={strings.seeCard}
          close={strings.close}
          tip={strings.zoomTip}
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
