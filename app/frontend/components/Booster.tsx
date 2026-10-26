import { useCallback, useEffect, useMemo, useRef, useState, type MouseEvent } from "react"
import { flushSync } from "react-dom"
import type { CanisterParts } from "./BoosterCanister"
import BoosterView from "./BoosterView"
import { useAtZero, useCountdown } from "./useBoosterCountdown"
import { useCardSwipe } from "./useCardSwipe"
import { useIslandTimers } from "./useIslandTimers"
import { useLiveRegion } from "./useLiveRegion"
import type { Rarity } from "../lib/card_types"
import { dispatchGameble } from "../lib/events"
import { t } from "../lib/i18n"
import { motionReduced } from "../lib/motion"
import { celebrationAnnouncement } from "../lib/celebration"
import { sendOpening, type OpeningAnswer } from "../lib/opening"
import { repostHref, sendRepost } from "../lib/repost"
import {
  NARROW_QUERY,
  PHONE_QUERY,
  activation,
  arming,
  bankDue,
  bankFetchOwed,
  bankFetched,
  bannerEnded,
  bannerShown,
  canRevealAll,
  canStore,
  cardStored,
  cardsDealt,
  celebrationSpoken,
  celebrationToAnnounce,
  countdownAtZero,
  ejecting,
  focusGiven,
  focusTarget,
  layoutApplied,
  layoutAsked,
  layoutFor,
  legendaryEnded,
  legendarySignalled,
  lock,
  lockReleased,
  openingAnswered,
  openingEnded,
  openingRefused,
  openingStarted,
  owedBankTaken,
  resultHeadShown,
  retracted,
  retracting,
  revealAllEnded,
  revealAllPlan,
  revealAllStarted,
  revealEnded,
  revealMarked,
  revealStarted,
  revealingOpening,
  start,
  storeEnded,
  storeStarted,
  topOfPile,
  unlock,
  zoomClosed,
  zoomOpened,
  zoomStepped,
  type BoosterState,
  type FocusTarget,
  type OpeningRefusal,
} from "../lib/booster"
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
  PHONE_DEAL_STAGGER,
  RAYS_FADE_MS,
  REVEAL_ALL_GAP,
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
  dealKeyframes,
  dealOrder,
  dealRotation,
  phoneAllHold,
  phoneJump,
  phoneSwell,
  pileDepth,
  pileOrder,
  pilePose,
  pileTransform,
  pose,
  revealSummary,
  scaled,
  swipeStores,
  tierIndex,
} from "../lib/booster_motion"
import { fetchBank } from "../lib/booster_bank"
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
import type { BoosterProps } from "../lib/booster_props"

export type { BoosterBank, BoosterProps, BoosterStrings } from "../lib/booster_props"

type Transition = (state: BoosterState) => BoosterState

export default function Booster(props: BoosterProps) {
  const { openUrl, bankUrl, cardUrl, repostUrl, delimiter, rarityNames, strings } = props

  const [state, setState] = useState(() =>
    start({
      bank: props.bank,
      opened: props.opened,
      layout: readLayout(),
      now: performance.now(),
      celebrationRemembered: celebrationRemembered(),
      preview: document.documentElement.hasAttribute("data-turbo-preview"),
    }),
  )
  const current = useRef(state)

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

  const { disposed, wait, later } = useIslandTimers()
  const { announcements, announce } = useLiveRegion()

  const settleState = (transition: Transition, render: (after: BoosterState) => void): BoosterState => {
    const before = current.current
    const after = transition(before)
    if (after === before) return before
    current.current = after
    render(after)
    reflect(before, after)
    return after
  }
  const apply = (transition: Transition): BoosterState => settleState(transition, setState)
  const commit = (transition: Transition): BoosterState => settleState(transition, (after) => flushSync(() => setState(after)))

  const reflect = (before: BoosterState, after: BoosterState) => {
    if (after.bank !== before.bank) {
      const { available, reserveFull, nextAvailableAt, serverTime } = after.bank
      dispatchGameble("gameble:bank-changed", { available, reserveFull, nextAvailableAt, serverTime })
    }
    if (before.lockDepth === 0 && after.lockDepth > 0) dispatchGameble("gameble:navigation-locked", { locked: true })
    if (before.lockDepth > 0 && after.lockDepth === 0) {
      dispatchGameble("gameble:navigation-locked", { locked: false })
      if (!disposed.current) whenIdle()
    }
  }

  useEffect(
    () => () => {
      const before = current.current
      current.current = lockReleased(before)
      if (before.lockDepth > 0) dispatchGameble("gameble:navigation-locked", { locked: false })
    },
    [],
  )

  const revealingNow = revealingOpening(state.status)
  useEffect(() => dispatchGameble("gameble:opening-revealing", { revealing: revealingNow }), [revealingNow])
  useEffect(() => () => dispatchGameble("gameble:opening-revealing", { revealing: false }), [])

  const phoneLayout = () => current.current.layout === "phone"

  const focusElement = (target: FocusTarget): HTMLElement | null => {
    if (target === "open") return openButton.current
    if (target === "back") return backLink.current
    if ("slot" in target) return traySlots.current[target.slot] ?? null
    return part(target.card, "hit")
  }
  useEffect(() => {
    const target = focusTarget(current.current)
    if (target === null) return
    const element = focusElement(target)
    if (!element || (element instanceof HTMLButtonElement && element.disabled)) return
    apply(focusGiven)
    element.focus({ preventScroll: true })
  })

  const showBanner = (tier: Rarity, large: boolean, line: string | null) => apply((s) => bannerShown(s, { tier, large, line, reduced: motionReduced() }))
  const endBanner = useCallback((key: number) => void apply((s) => bannerEnded(s, key)), [])
  const bannerLine = (index: number) => {
    const card = current.current.answer?.cards[index]
    return card ? t(strings.bannerLine, { title: card.title, year: card.year ?? "" }) : null
  }

  const leaveForAlbum = (event: MouseEvent<HTMLAnchorElement>) => {
    if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return
    const answer = current.current.answer
    if (answer) rememberPack(answer.pack.token, true)
  }

  const toAnnounce = celebrationToAnnounce(state)
  useEffect(() => {
    if (toAnnounce === null || current.current.celebrationAnnounced) return
    apply(celebrationSpoken)
    announce(celebrationAnnouncement(toAnnounce, strings.celebration, delimiter))
  }, [toAnnounce, announce, strings, delimiter])

  const refreshBank = async () => {
    const generation = current.current.bankGeneration
    const fresh = await fetchBank({ url: bankUrl })
    if (!fresh || disposed.current) return
    apply((s) => bankFetched(s, fresh, generation))
  }

  const whenIdle = () => {
    const before = current.current
    const focusedInside = section.current?.contains(document.activeElement) ?? false
    const after = apply((s) => layoutApplied(s, focusedInside))
    if (after.layout !== before.layout) swipe.forget()
    if (!bankDue(current.current)) return
    apply(owedBankTaken)
    void refreshBank()
  }

  const refuse = (result: OpeningRefusal) => {
    settle(canister.current?.move)
    const message = apply((s) => openingRefused(s, result, strings.failed)).reason ?? strings.failed
    announce(message)
    dispatchGameble("gameble:toast", { title: strings.refusedTitle, message, tone: "alert" })
    apply(unlock)
    if (result.kind === "refused") void refreshBank()
  }

  const retract = async () => {
    const count = current.current.answer?.cards.length ?? 0
    apply(retracting)
    if (!motionReduced()) {
      for (let index = 0; index < count; index++) {
        const travel = part(index, "travel")
        const from = phoneLayout() ? pileTransform(pileDepth(index, current.current.stored)) : pose()
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
    commit(retracted)
    if (!motionReduced()) {
      animate(canister.current?.wrap, dockKeyframes(), { duration: DOCK, easing: "cubic-bezier(.2,.9,.3,1)", fill: "none" })
      await wait(DOCK)
    }
  }

  const blowAndDeal = async (count: number) => {
    const parts = canister.current
    apply(ejecting)
    animate(parts?.capTop, capTopKeyframes(), { duration: CAPS_MS, easing: "cubic-bezier(.12,.8,.3,1)", fill: "forwards" })
    animate(parts?.capBottom, capBottomKeyframes(), { duration: CAPS_MS, easing: "cubic-bezier(.12,.8,.3,1)", fill: "forwards" })
    animate(parts?.body, bodyKeyframes(), { duration: BODY_MS, easing: "cubic-bezier(.5,0,1,.6)", fill: "forwards" })
    animate(parts?.rays, fadeKeyframes(1, 0), { duration: RAYS_FADE_MS, fill: "forwards" })
    blast(fx.current, canister.current?.button)
    stageFlash(flash.current, "warm", 0.35, FLASH_MS)
    stageShake(shake.current, 5, SHAKE_MS)
    await wait(HEAD_DELAY)
    apply(resultHeadShown)

    const origin = parts?.button?.getBoundingClientRect()
    const phone = phoneLayout()
    const stagger = phone ? PHONE_DEAL_STAGGER : DEAL_STAGGER
    commit(cardsDealt)
    let end = 0
    ;(phone ? pileOrder(count) : dealOrder(count)).forEach((index, position) => {
      const slot = slots.current[index]
      const travel = part(index, "travel")
      if (!slot || !travel || !origin) return
      const rect = slot.querySelector(".booster-card__frame")?.getBoundingClientRect() ?? slot.getBoundingClientRect()
      const dx = origin.left + origin.width / 2 - (rect.left + rect.width / 2)
      const dy = origin.top + origin.height / 2 - (rect.top + rect.height / 2)
      const delay = position * stagger
      const rest = phone ? pilePose(pileDepth(index, current.current.stored)) : undefined
      animate(travel, dealKeyframes(dx, dy, dealRotation(index, count), rest), { duration: DEAL_MS, delay, fill: "backwards", easing: "linear" })
      later(delay + DEAL_MS * DEAL_LAND_AT, () => stageShake(shake.current, 1.5, LAND_SHAKE_MS))
      end = Math.max(end, delay + DEAL_MS)
    })
    await wait(end)
  }

  const fadeAndDeal = async (count: number) => {
    animate(canister.current?.wrap, fadeKeyframes(1, 0), { duration: RM_CANISTER_FADE, fill: "forwards" })
    apply(resultHeadShown)
    commit(cardsDealt)
    for (let index = 0; index < count; index++) {
      animate(part(index, "travel"), fadeKeyframes(0, 1), { duration: RM_CARD_FADE, delay: index * RM_FADE_STAGGER, fill: "backwards" })
    }
    await wait(Math.max(RM_CANISTER_FADE, RM_CARD_FADE + (count - 1) * RM_FADE_STAGGER))
  }

  const open = async () => {
    const before = current.current
    if (apply(openingStarted) === before) return
    apply(lock)
    if (before.phase === "dealt") await retract()
    rememberPack(null)

    const key = current.current.pendingKey ?? newKey()
    apply((s) => arming(s, key))
    const reduced = motionReduced()
    if (!reduced) animate(canister.current?.move, armKeyframes(), { duration: ARM_MS, fill: "forwards" })
    const [result] = await Promise.all([sendOpening({ url: openUrl, key, csrfToken: csrfToken() }), wait(reduced ? 0 : ARM_MS)])
    if (disposed.current) return
    if (result.kind !== "opened") {
      refuse(result)
      return
    }

    const answer = result.answer
    commit((s) => openingAnswered(s, answer))

    if (motionReduced()) await fadeAndDeal(answer.cards.length)
    else await blowAndDeal(answer.cards.length)

    apply(openingEnded)
    apply(unlock)
  }

  const artReady = async (index: number) => {
    const started = performance.now()
    while (!slots.current[index]?.querySelector(".booster-card__front .card__art[data-art]") && performance.now() - started < ART_WAIT_MAX) {
      await wait(ART_POLL)
    }
  }

  const mark = (index: number, quiet: boolean) => {
    const before = current.current
    const after = apply((s) => revealMarked(s, index, performance.now()))
    const card = after.answer?.cards[index]
    if (after === before || !card || !after.counts) return
    dispatchGameble("gameble:tier-revealed", { tier: card.tier, counts: after.counts })
    if (!quiet) announce(t(strings.announceCard, { position: index + 1, card: card.label, rarity: rarityNames[card.tier] }))
  }

  const riseLimit = (index: number): number => {
    if (!phoneLayout()) return LEGENDARY_JUMP_PX
    const frame = slots.current[index]?.querySelector(".booster-card__frame")
    const stage = shake.current
    if (!frame || !stage) return 0
    return phoneJump(frame.getBoundingClientRect().top - stage.getBoundingClientRect().top)
  }

  const swell = (scale: number) => (phoneLayout() ? phoneSwell(scale) : scale)

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
    if (level === 3) showBanner(tier, false, null)
    settle(lift)
    animate(lift, settleKeyframes(height, swell), { duration: SETTLE_MS[level], easing: "cubic-bezier(.2,.8,.3,1)", fill: "none" })
    await wait(SETTLE_MS[level])
  }

  const revealLegendary = async (index: number, quiet: boolean) => {
    const lift = part(index, "lift")
    const flip = part(index, "flip")
    const rise = riseLimit(index)
    apply((s) => legendarySignalled(s, index))
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
    showBanner("legendary", true, bannerLine(index))
    await wait(IMPACT)

    apply(legendaryEnded)
    settle(lift)
    animate(lift, legendaryDropKeyframes(rise, swell), { duration: DROP, easing: "cubic-bezier(.3,1.5,.5,1)", fill: "none" })
    later(scaled(300), () => stageShake(shake.current, 2, scaled(120)))
    await wait(DROP)
  }

  const revealStill = async (index: number, tier: Rarity, quiet: boolean) => {
    const legendary = tier === "legendary"
    if (legendary) {
      apply((s) => legendarySignalled(s, null))
      announce(strings.states.legendarySignal)
    }
    mark(index, quiet)
    animate(part(index, "lift"), fadeKeyframes(0.2, 1), { duration: RM_REVEAL_FADE, fill: "none" })
    if (legendary) {
      showBanner("legendary", true, bannerLine(index))
      await wait(RM_LEGENDARY_STILL)
      apply(legendaryEnded)
    } else {
      await wait(RM_REVEAL_FADE)
    }
  }

  const reveal = async (index: number, fromAll: boolean, { awaitArt = true } = {}): Promise<void> => {
    const before = current.current
    const card = before.answer?.cards[index]
    if (!card || apply((s) => revealStarted(s, index, fromAll)) === before) return
    apply(lock)
    if (awaitArt) await artReady(index)
    if (disposed.current) return
    if (motionReduced()) await revealStill(index, card.tier, fromAll)
    else if (card.tier === "legendary") await revealLegendary(index, fromAll)
    else await revealTier(index, card.tier, fromAll)
    apply((s) => revealEnded(s, index, fromAll))
    apply(unlock)
  }

  const summary = (tiers: Rarity[]) => revealSummary(tiers, { summary: strings.summary, summaryTier: strings.summaryTier, rarityNames, delimiter })

  const revealAll = async () => {
    const before = current.current
    const answer = before.answer
    if (!answer || !canRevealAll(before)) return
    if (before.layout === "phone") {
      await revealAndStoreAll(answer)
      return
    }
    const plan = revealAllPlan(before)
    if (plan.length === 0) return
    apply(revealAllStarted)
    const running: Promise<void>[] = []
    for (const { index, wait: hold } of plan) {
      const done = reveal(index, true, { awaitArt: false })
      running.push(done)
      if (hold === "full") await done
      else await wait(REVEAL_ALL_GAP)
    }
    await Promise.all(running)
    while (current.current.revealing.length > 0) await wait(ART_POLL)
    apply(revealAllEnded)
    announce(summary(plan.map(({ index }) => answer.cards[index].tier)))
    whenIdle()
  }

  const revealAndStoreAll = async (answer: OpeningAnswer) => {
    apply(revealAllStarted)
    while (current.current.revealing.length > 0) {
      await wait(ART_POLL)
    }
    const shown: Rarity[] = []
    for (let index = 0; index < answer.cards.length; index++) {
      if (disposed.current || current.current.answer !== answer) return
      if (current.current.stored[index]) continue
      if (!current.current.revealed[index]) {
        await reveal(index, true)
        shown.push(answer.cards[index].tier)
      }
      await wait(phoneAllHold(answer.cards[index].tier))
      await store(index, true)
    }
    apply(revealAllEnded)
    if (shown.length > 0) announce(summary(shown))
    whenIdle()
  }

  const store = async (index: number, fromAll: boolean): Promise<void> => {
    const before = current.current
    const card = before.answer?.cards[index]
    if (!card || apply((s) => storeStarted(s, index, fromAll, performance.now())) === before) return
    const float = part(index, "float")
    const frame = slots.current[index]?.querySelector(".booster-card__frame")
    const target = traySlots.current[index]
    const from = float?.style.transform || "none"
    if (float) float.style.transform = ""
    if (!motionReduced() && float && frame && target) {
      settle(float)
      animate(float, storeKeyframes(from, frame.getBoundingClientRect(), target.getBoundingClientRect()), {
        duration: STORE_MS,
        easing: "cubic-bezier(.45,0,.6,1)",
        fill: "forwards",
      })
      await wait(STORE_MS)
    }
    if (disposed.current) return
    commit((s) => cardStored(s, index))
    if (!motionReduced()) {
      animate(traySlots.current[index], slotPopKeyframes(), { duration: SLOT_POP_MS, easing: "cubic-bezier(.2,1.35,.35,1)" })
      traySparks(fx.current, traySlots.current[index], card.tier)
    }
    apply((s) => storeEnded(s, fromAll))
    whenIdle()
  }

  const springBack = (index: number) => {
    const float = part(index, "float")
    if (!float) return
    const from = float.style.transform || "none"
    float.style.transform = ""
    if (!motionReduced()) animate(float, springBackKeyframes(from), { duration: SPRING_BACK_MS, easing: "cubic-bezier(.2,1.6,.4,1)" })
  }

  const swipe = useCardSwipe({
    canStart: (index) => canStore(current.current, index, false, performance.now()),
    slot: (index) => slots.current[index] ?? null,
    float: (index) => part(index, "float"),
    release: (index, dx, dy, abandoned) => {
      if (!abandoned && swipeStores(dx, dy) && canStore(current.current, index, false, performance.now())) void store(index, false)
      else springBack(index)
    },
  })

  const storeTop = () => {
    const index = topOfPile(current.current.revealed, current.current.stored)
    if (index !== null) void store(index, false)
  }

  const openZoom = useCallback((index: number) => void apply((s) => zoomOpened(s, index)), [])
  const closeZoom = () => void apply(zoomClosed)
  const stepZoom = (step: -1 | 1) => void apply((s) => zoomStepped(s, step))

  const leaveFor = (index: number) => {
    const answer = current.current.answer
    const card = answer?.cards[index]
    if (!answer || !card) return
    rememberPack(answer.pack.token)
    visit(cardHref(cardUrl, card.slug, answer.pack.token, index))
  }

  const repost = useCallback(
    async (index: number) => {
      const card = current.current.answer?.cards[index]
      if (!card || repostUrl === null) return ""
      const result = await sendRepost({ url: repostHref(repostUrl, card.slug, card.season), csrfToken: csrfToken() })
      const message = result.kind === "reposted" ? strings.reposted : result.kind === "refused" ? result.message : strings.repostFailed
      dispatchGameble("gameble:toast", { message, tone: result.kind === "reposted" ? "notice" : "alert" })
      return message
    },
    [repostUrl, strings],
  )

  const seeZoomed = (event: MouseEvent<HTMLAnchorElement>) => {
    const { zoom } = current.current
    if (zoom === null || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return
    event.preventDefault()
    leaveFor(zoom)
  }

  useEffect(() => {
    if (typeof window.matchMedia !== "function") return
    const phone = window.matchMedia(PHONE_QUERY)
    const narrow = window.matchMedia(NARROW_QUERY)
    const onChange = () => {
      apply((s) => layoutAsked(s, layoutFor(phone.matches, narrow.matches)))
      whenIdle()
    }
    phone.addEventListener("change", onChange)
    narrow.addEventListener("change", onChange)
    onChange()
    return () => {
      phone.removeEventListener("change", onChange)
      narrow.removeEventListener("change", onChange)
    }
  }, [])

  const activateCard = useCallback(
    (index: number) => {
      const action = activation(current.current, index, performance.now(), swipe.lastDragEnd())
      if (action === "reveal") void reveal(index, false)
      else if (action === "store") void store(index, false)
      else if (action === "leave") leaveFor(index)
    },
    [cardUrl],
  )

  const left = useCountdown(state.bank.nextAvailableAt, state.bank.serverTime)

  useAtZero(left, () => {
    if (disposed.current) return
    const action = countdownAtZero(current.current)
    if (action === "page") refreshPage()
    else if (action === "bank") void refreshBank()
    else apply(bankFetchOwed)
  })

  const guardBack = (event: MouseEvent<HTMLAnchorElement>) => {
    if (current.current.lockDepth > 0) event.preventDefault()
  }

  return (
    <BoosterView
      props={props}
      state={state}
      announcements={announcements}
      left={left}
      elements={{ section, canister, shake, flash, fx, openButton, backLink, slotRefs, traySlotRef }}
      handlers={{ open, revealAll, activateCard, storeTop, openZoom, closeZoom, stepZoom, seeZoomed, repost, endBanner, guardBack, leaveForAlbum, gestures: swipe.gestures }}
    />
  )
}
