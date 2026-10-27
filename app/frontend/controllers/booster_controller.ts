import { Controller } from "@hotwired/stimulus"
import { fetchBank } from "../lib/booster_bank"
import { formatClock } from "../lib/booster_clock"
import { BoosterCountdown } from "../lib/booster_countdown"
import { animate, blast, burst, ring, settle, stageFlash, stageShake, traySparks } from "../lib/booster_effects"
import {
  armKeyframes,
  bannerKeyframes,
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
import { bankFrom, openedFrom } from "../lib/booster_markup"
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
  bannerDuration,
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
import { cardHref, celebrationRemembered, csrfToken, newKey, readLayout, refreshPage, rememberPack, visit } from "../lib/booster_page"
import type { SwipeRelease } from "../lib/booster_swipe"
import { RARITIES, type Rarity } from "../lib/card_types"
import {
  celebrationAnnouncement,
  countParts,
  folded,
  foldedLinkName,
  foldedMarks,
  foldedSubline,
  foldedTitle,
  gaugeFractions,
  gaugeTicks,
  juice,
  resultLinkName,
  resultTitle,
  type CelebrationResult,
  type CelebrationStrings,
} from "../lib/celebration"
import { dispatchGameble } from "../lib/events"
import { formatNumber, t, type Template } from "../lib/i18n"
import { formatLocalTime } from "../lib/local_time"
import { motionReduced } from "../lib/motion"
import { sendOpening, type OpeningAnswer, type OpeningCard } from "../lib/opening"
import { repostHref, sendRepost } from "../lib/repost"
import { serverTemplate } from "../lib/server_html"
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
  celebrationStepped,
  celebrationToAnnounce,
  controls,
  countdownAtZero,
  ejecting,
  faceSize,
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
  shownCelebration,
  shownResult,
  start,
  storeEnded,
  storeStarted,
  topOfPile,
  unlock,
  zoomClosed,
  zoomOpened,
  zoomStepped,
  type BoosterState,
  type Controls,
  type FocusTarget,
  type Hint,
  type OpeningRefusal,
} from "../lib/booster"
import { screenTimers, type ScreenTimers } from "../lib/screen_timers"
import { cloneContent, cloneFirstElement } from "../lib/templates"
import type { Intent } from "../lib/screen"
import type BoosterActionsController from "./booster_actions_controller"
import type BoosterCanisterController from "./booster_canister_controller"
import type BoosterCelebrationController from "./booster_celebration_controller"
import type { CelebrationView, ResultView } from "./booster_celebration_controller"
import type BoosterInfoController from "./booster_info_controller"
import type BoosterPlateController from "./booster_plate_controller"
import type BoosterStageController from "./booster_stage_controller"
import type { CardIntent, CardView, HandView } from "./booster_stage_controller"
import type BoosterTrayController from "./booster_tray_controller"
import type BoosterZoomController from "./booster_zoom_controller"

type BoosterStrings = {
  announceCard: string
  bannerLine: string
  canisterFacts: Template
  canisterLabel: string
  canisterLabelPlain: string
  celebration: CelebrationStrings
  emptyNext: string
  faceDown: string
  faceUp: string
  faceUpStore: string
  failed: string
  hintDone: Template
  hintRemaining: Template
  legendarySignal: string
  nextAt: string
  refusedTitle: string
  repostCard: string
  repostFailed: string
  reposted: string
  reserveCount: Template
  summary: Template
  summaryTier: string
  trayCount: string
  traySlot: string
  zoomLine: string
}

type Transition = (state: BoosterState) => BoosterState

type Clock = Readonly<{ clock: string; spoken: string }>

const ANNOUNCEMENTS_KEPT = 5

const localTime = (iso: string): string => formatLocalTime(iso, "datetime", { locale: document.documentElement.lang }) ?? iso

export class BoosterController extends Controller<HTMLElement> {
  static targets = ["panelActions", "phoneActions", "live", "announcement", "rarity", "pack", "card", "face", "setTier"]
  static values = {
    openUrl: String,
    cardUrl: String,
    repostUrl: String,
    bankUrl: String,
    delimiter: String,
    packSize: Number,
    season: Number,
    available: Number,
    reserveFull: Boolean,
    nextAvailableAt: String,
    serverTime: String,
    nextPackSize: Number,
    strings: Object,
  }
  static outlets = [
    "booster-info",
    "booster-actions",
    "booster-canister",
    "booster-stage",
    "booster-plate",
    "booster-tray",
    "booster-zoom",
    "booster-celebration",
  ]

  declare readonly panelActionsTarget: HTMLElement
  declare readonly phoneActionsTarget: HTMLElement
  declare readonly liveTarget: HTMLElement
  declare readonly announcementTarget: HTMLTemplateElement
  declare readonly rarityTargets: HTMLTemplateElement[]
  declare readonly hasPackTarget: boolean
  declare readonly packTarget: HTMLTemplateElement
  declare readonly cardTargets: HTMLTemplateElement[]
  declare readonly faceTargets: HTMLTemplateElement[]
  declare readonly setTierTargets: HTMLTemplateElement[]
  declare readonly openUrlValue: string
  declare readonly cardUrlValue: string
  declare readonly repostUrlValue: string
  declare readonly bankUrlValue: string
  declare readonly delimiterValue: string
  declare readonly packSizeValue: number
  declare readonly seasonValue: number
  declare readonly availableValue: number
  declare readonly reserveFullValue: boolean
  declare readonly nextAvailableAtValue: string
  declare readonly serverTimeValue: string
  declare readonly nextPackSizeValue: number
  declare readonly stringsValue: BoosterStrings
  declare readonly boosterInfoOutlets: BoosterInfoController[]
  declare readonly hasBoosterActionsOutlet: boolean
  declare readonly boosterActionsOutlet: BoosterActionsController
  declare readonly hasBoosterCanisterOutlet: boolean
  declare readonly boosterCanisterOutlet: BoosterCanisterController
  declare readonly hasBoosterStageOutlet: boolean
  declare readonly boosterStageOutlet: BoosterStageController
  declare readonly hasBoosterPlateOutlet: boolean
  declare readonly boosterPlateOutlet: BoosterPlateController
  declare readonly hasBoosterTrayOutlet: boolean
  declare readonly boosterTrayOutlet: BoosterTrayController
  declare readonly hasBoosterZoomOutlet: boolean
  declare readonly boosterZoomOutlet: BoosterZoomController
  declare readonly boosterCelebrationOutlets: BoosterCelebrationController[]

  private state?: BoosterState
  private timers: ScreenTimers = screenTimers()
  private countdown?: BoosterCountdown
  private left: number | null = null
  private faces = new Map<number, Map<string, HTMLTemplateElement>>()
  private icons = new Map<Rarity, HTMLTemplateElement>()
  private rarityNames = {} as Record<Rarity, string>
  private rarityLabels = {} as Record<Rarity, string>
  private bannerKey: number | null = null
  private afterRenderQueued = false
  private media: { phone: MediaQueryList; narrow: MediaQueryList } | null = null

  private readonly visibilityChanged = (): void => this.countdown?.visibilityChanged()

  private readonly layoutChanged = (): void => {
    const media = this.media
    if (!media) return
    this.apply((s) => layoutAsked(s, layoutFor(media.phone.matches, media.narrow.matches)))
    this.whenIdle()
  }

  private readonly face = (index: number): DocumentFragment | null => {
    const size = this.state ? faceSize(this.state.layout) : "m"
    return this.faceFragment(index, size)
  }

  private readonly icon = (tier: Rarity): DocumentFragment | null => {
    const template = this.icons.get(tier)
    return template ? cloneContent(template) : null
  }

  connect(): void {
    this.timers = screenTimers()
    this.readRarities()
    this.readFaces()
    const bank = bankFrom({
      available: this.availableValue,
      reserveFull: this.reserveFullValue,
      nextAvailableAt: this.nextAvailableAtValue,
      serverTime: this.serverTimeValue,
      nextPackSize: this.nextPackSizeValue,
    })
    const opened = openedFrom({
      pack: this.hasPackTarget ? this.packTarget.dataset : null,
      cards: this.cardTargets.map((card) => card.dataset),
      setTiers: this.setTierTargets.map((row) => row.dataset),
      bank,
    })
    this.state = start({
      bank,
      opened,
      layout: readLayout(),
      now: performance.now(),
      celebrationRemembered: celebrationRemembered(),
      preview: document.documentElement.hasAttribute("data-turbo-preview"),
    })
    this.countdown = new BoosterCountdown(
      {
        now: () => performance.now(),
        hidden: () => document.hidden,
        setTimeout: (action, ms) => setTimeout(action, ms),
        clearTimeout: (timer) => clearTimeout(timer),
      },
      { left: (seconds) => this.countdownLeft(seconds), zero: () => this.atZero() },
    )
    document.addEventListener("visibilitychange", this.visibilityChanged)
    this.countdown.set(bank.nextAvailableAt, bank.serverTime)
    this.render()
    dispatchGameble("gameble:opening-revealing", { revealing: revealingOpening(this.state.status) })
    this.watchLayout()
    this.queueAfterRender()
  }

  disconnect(): void {
    this.timers.dispose()
    this.countdown?.dispose()
    this.countdown = undefined
    document.removeEventListener("visibilitychange", this.visibilityChanged)
    this.media?.phone.removeEventListener("change", this.layoutChanged)
    this.media?.narrow.removeEventListener("change", this.layoutChanged)
    this.media = null
    const before = this.state
    if (before && before.lockDepth > 0) dispatchGameble("gameble:navigation-locked", { locked: false })
    if (before) this.state = lockReleased(before)
    dispatchGameble("gameble:opening-revealing", { revealing: false })
  }

  boosterInfoOutletConnected(): void {
    this.render()
  }

  boosterActionsOutletConnected(): void {
    this.render()
  }

  boosterCanisterOutletConnected(): void {
    this.render()
  }

  boosterStageOutletConnected(): void {
    this.render()
  }

  boosterPlateOutletConnected(): void {
    this.render()
  }

  boosterTrayOutletConnected(): void {
    this.render()
  }

  boosterZoomOutletConnected(): void {
    this.render()
  }

  boosterCelebrationOutletConnected(): void {
    this.render()
  }

  open(): void {
    void this.openBooster()
  }

  revealAll(): void {
    void this.revealEveryCard()
  }

  guardBack(event: Event): void {
    if ((this.state?.lockDepth ?? 0) > 0) event.preventDefault()
  }

  activateCard({ detail: { index } }: Intent<CardIntent>): void {
    if (!this.state) return
    const action = activation(this.state, index, performance.now(), this.hasBoosterStageOutlet ? this.boosterStageOutlet.lastDragEnd : -Infinity)
    if (action === "reveal") void this.reveal(index, false)
    else if (action === "store") void this.store(index, false)
    else if (action === "leave") this.leaveFor(index)
  }

  repostCard({ detail: { index } }: Intent<CardIntent>): void {
    void this.repost(index)
  }

  pressCard(event: Intent<CardIntent>): void {
    if (this.state && canStore(this.state, event.detail.index, false, performance.now())) event.preventDefault()
  }

  releaseCard({ detail: { index, dx, dy, abandoned } }: Intent<SwipeRelease>): void {
    if (this.state && !abandoned && swipeStores(dx, dy) && canStore(this.state, index, false, performance.now())) void this.store(index, false)
    else this.springBack(index)
  }

  storeTop(): void {
    if (!this.state) return
    const index = topOfPile(this.state.revealed, this.state.stored)
    if (index !== null) void this.store(index, false)
  }

  openZoom({ detail: { index } }: Intent<{ index: number }>): void {
    this.apply((s) => zoomOpened(s, index))
  }

  stepZoom({ detail: { step } }: Intent<{ step: -1 | 1 }>): void {
    this.apply((s) => zoomStepped(s, step))
  }

  seeZoomed(event: Event): void {
    const zoom = this.state?.zoom ?? null
    if (zoom === null) return
    event.preventDefault()
    this.leaveFor(zoom)
  }

  repostZoomed(): void {
    const zoom = this.state?.zoom ?? null
    if (zoom === null) return
    const showing = this.hasBoosterZoomOutlet ? this.boosterZoomOutlet.showing : null
    void this.repost(zoom).then((message) => {
      if (this.hasBoosterZoomOutlet) this.boosterZoomOutlet.showStatus(message, showing)
    })
  }

  closeZoom(): void {
    this.apply(zoomClosed)
  }

  leaveForAlbum(): void {
    const answer = this.state?.answer
    if (answer) rememberPack(answer.pack.token, true)
  }

  stepCelebration(): void {
    this.apply(celebrationStepped)
  }

  private get current(): BoosterState {
    return this.state!
  }

  private get strings(): BoosterStrings {
    return this.stringsValue
  }

  private apply(transition: Transition): BoosterState {
    const before = this.state
    if (!before || this.timers.disposed) return before!
    const after = transition(before)
    if (after === before) return before
    this.state = after
    this.render()
    this.reflect(before, after)
    return after
  }

  private reflect(before: BoosterState, after: BoosterState): void {
    if (after.bank !== before.bank) {
      const { available, reserveFull, nextAvailableAt, serverTime } = after.bank
      dispatchGameble("gameble:bank-changed", { available, reserveFull, nextAvailableAt, serverTime })
      this.countdown?.set(nextAvailableAt, serverTime)
    }
    const revealing = revealingOpening(after.status)
    if (revealing !== revealingOpening(before.status)) dispatchGameble("gameble:opening-revealing", { revealing })
    if (before.lockDepth === 0 && after.lockDepth > 0) dispatchGameble("gameble:navigation-locked", { locked: true })
    if (before.lockDepth > 0 && after.lockDepth === 0) {
      dispatchGameble("gameble:navigation-locked", { locked: false })
      if (!this.timers.disposed) this.whenIdle()
    }
  }

  private queueAfterRender(): void {
    if (this.afterRenderQueued) return
    this.afterRenderQueued = true
    queueMicrotask(() => {
      this.afterRenderQueued = false
      if (this.timers.disposed) return
      this.giveFocus()
      this.announceCelebration()
    })
  }

  private giveFocus(): void {
    const state = this.state
    const target = state && focusTarget(state)
    if (!target) return
    const element = this.focusElement(target)
    if (!element || (element instanceof HTMLButtonElement && element.disabled)) return
    this.apply(focusGiven)
    element.focus({ preventScroll: true })
  }

  private focusElement(target: FocusTarget): HTMLElement | null {
    if (target === "open") return this.hasBoosterActionsOutlet ? this.boosterActionsOutlet.openButton : null
    if (target === "back") return this.hasBoosterActionsOutlet ? this.boosterActionsOutlet.backLink : null
    if ("slot" in target) return this.hasBoosterTrayOutlet ? this.boosterTrayOutlet.slotElement(target.slot) : null
    return this.part(target.card, "hit")
  }

  private announceCelebration(): void {
    const state = this.state
    const results = state && celebrationToAnnounce(state)
    if (!results || state.celebrationAnnounced) return
    this.apply(celebrationSpoken)
    this.announce(celebrationAnnouncement(results, this.strings.celebration, this.delimiterValue))
  }

  private announce(text: string): void {
    const span = cloneFirstElement(this.announcementTarget)
    if (!span) return
    span.textContent = text
    this.liveTarget.append(span)
    while (this.liveTarget.children.length > ANNOUNCEMENTS_KEPT) this.liveTarget.firstElementChild?.remove()
  }

  private readRarities(): void {
    for (const template of this.rarityTargets) {
      const tier = template.dataset.tier as Rarity
      if (!RARITIES.includes(tier)) continue
      this.icons.set(tier, template)
      this.rarityNames[tier] = template.dataset.name ?? tier
      this.rarityLabels[tier] = template.dataset.label ?? this.rarityNames[tier]
    }
  }

  private readFaces(): void {
    this.faces.clear()
    for (const template of this.faceTargets) {
      const index = Number(template.dataset.index)
      const size = template.dataset.size ?? ""
      if (!this.faces.has(index)) this.faces.set(index, new Map())
      this.faces.get(index)!.set(size, template)
    }
  }

  private keepFaces(answer: OpeningAnswer): void {
    this.faces.clear()
    answer.cards.forEach((card, index) => {
      const sizes = new Map<string, HTMLTemplateElement>()
      for (const [size, html] of Object.entries(card.faces)) sizes.set(size, serverTemplate(html))
      this.faces.set(index, sizes)
    })
  }

  private faceFragment(index: number, size: string): DocumentFragment | null {
    const template = this.faces.get(index)?.get(size)
    return template ? cloneContent(template) : null
  }

  private number(value: number): string {
    return formatNumber(value, this.delimiterValue)
  }

  private tierLabel(tier: Rarity): string {
    return this.rarityLabels[tier] ?? tier
  }

  private bannerLine(index: number): string | null {
    const card = this.state?.answer?.cards[index]
    return card ? t(this.strings.bannerLine, { title: card.title, year: card.year ?? "" }) : null
  }

  private part(index: number, name: string): HTMLElement | null {
    return this.hasBoosterStageOutlet ? this.boosterStageOutlet.part(index, name) : null
  }

  private slot(index: number): HTMLLIElement | null {
    return this.hasBoosterStageOutlet ? this.boosterStageOutlet.slot(index) : null
  }

  private get shake(): HTMLElement | null {
    return this.hasBoosterStageOutlet ? this.boosterStageOutlet.shake : null
  }

  private get fx(): HTMLElement | null {
    return this.hasBoosterStageOutlet ? this.boosterStageOutlet.fx : null
  }

  private get flash(): HTMLElement | null {
    return this.hasBoosterStageOutlet ? this.boosterStageOutlet.flash : null
  }

  private canister() {
    return this.hasBoosterCanisterOutlet ? this.boosterCanisterOutlet.parts : null
  }

  private traySlot(index: number): HTMLElement | null {
    return this.hasBoosterTrayOutlet ? this.boosterTrayOutlet.slotElement(index) : null
  }

  private phoneLayout(): boolean {
    return this.current.layout === "phone"
  }

  private watchLayout(): void {
    if (typeof window.matchMedia !== "function") return
    this.media = { phone: window.matchMedia(PHONE_QUERY), narrow: window.matchMedia(NARROW_QUERY) }
    this.media.phone.addEventListener("change", this.layoutChanged)
    this.media.narrow.addEventListener("change", this.layoutChanged)
    this.layoutChanged()
  }

  private whenIdle(): void {
    const before = this.current
    const focusedInside = this.element.contains(document.activeElement)
    const after = this.apply((s) => layoutApplied(s, focusedInside))
    if (after.layout !== before.layout && this.hasBoosterStageOutlet) this.boosterStageOutlet.forgetGesture()
    if (!bankDue(this.current)) return
    this.apply(owedBankTaken)
    void this.refreshBank()
  }

  private async refreshBank(): Promise<void> {
    const generation = this.current.bankGeneration
    const fresh = await fetchBank({ url: this.bankUrlValue })
    if (!fresh || this.timers.disposed) return
    this.apply((s) => bankFetched(s, fresh, generation))
  }

  private countdownLeft(seconds: number | null): void {
    this.left = seconds
    this.render()
  }

  private atZero(): void {
    if (this.timers.disposed || !this.state) return
    const action = countdownAtZero(this.state)
    if (action === "page") refreshPage()
    else if (action === "bank") void this.refreshBank()
    else this.apply(bankFetchOwed)
  }

  private refuse(result: OpeningRefusal): void {
    settle(this.canister()?.move)
    const message = this.apply((s) => openingRefused(s, result, this.strings.failed)).reason ?? this.strings.failed
    this.announce(message)
    dispatchGameble("gameble:toast", { title: this.strings.refusedTitle, message, tone: "alert" })
    this.apply(unlock)
    if (result.kind === "refused") void this.refreshBank()
  }

  private async retract(): Promise<void> {
    const { wait } = this.timers
    const count = this.current.answer?.cards.length ?? 0
    this.apply(retracting)
    if (!motionReduced()) {
      for (let index = 0; index < count; index++) {
        const travel = this.part(index, "travel")
        const from = this.phoneLayout() ? pileTransform(pileDepth(index, this.current.stored)) : pose()
        settle(travel)
        animate(travel, sinkKeyframes(from), { duration: SINK, delay: index * SINK_STAGGER, easing: "cubic-bezier(.5,0,.8,.4)", fill: "forwards" })
      }
      await wait(SINK + (count - 1) * SINK_STAGGER)
    }
    this.apply(retracted)
    if (!motionReduced()) {
      animate(this.canister()?.wrap, dockKeyframes(), { duration: DOCK, easing: "cubic-bezier(.2,.9,.3,1)", fill: "none" })
      await wait(DOCK)
    }
  }

  private async blowAndDeal(count: number): Promise<void> {
    const { wait, later } = this.timers
    const parts = this.canister()
    this.apply(ejecting)
    animate(parts?.capTop, capTopKeyframes(), { duration: CAPS_MS, easing: "cubic-bezier(.12,.8,.3,1)", fill: "forwards" })
    animate(parts?.capBottom, capBottomKeyframes(), { duration: CAPS_MS, easing: "cubic-bezier(.12,.8,.3,1)", fill: "forwards" })
    animate(parts?.body, bodyKeyframes(), { duration: BODY_MS, easing: "cubic-bezier(.5,0,1,.6)", fill: "forwards" })
    animate(parts?.rays, fadeKeyframes(1, 0), { duration: RAYS_FADE_MS, fill: "forwards" })
    blast(this.fx, parts?.button)
    stageFlash(this.flash, "warm", 0.35, FLASH_MS)
    stageShake(this.shake, 5, SHAKE_MS)
    await wait(HEAD_DELAY)
    this.apply(resultHeadShown)

    const origin = this.canister()?.button?.getBoundingClientRect()
    const phone = this.phoneLayout()
    const stagger = phone ? PHONE_DEAL_STAGGER : DEAL_STAGGER
    this.apply(cardsDealt)
    let end = 0
    ;(phone ? pileOrder(count) : dealOrder(count)).forEach((index, position) => {
      const slot = this.slot(index)
      const travel = this.part(index, "travel")
      if (!slot || !travel || !origin) return
      const rect = slot.querySelector(".booster-card__frame")?.getBoundingClientRect() ?? slot.getBoundingClientRect()
      const dx = origin.left + origin.width / 2 - (rect.left + rect.width / 2)
      const dy = origin.top + origin.height / 2 - (rect.top + rect.height / 2)
      const delay = position * stagger
      const rest = phone ? pilePose(pileDepth(index, this.current.stored)) : undefined
      animate(travel, dealKeyframes(dx, dy, dealRotation(index, count), rest), { duration: DEAL_MS, delay, fill: "backwards", easing: "linear" })
      later(delay + DEAL_MS * DEAL_LAND_AT, () => stageShake(this.shake, 1.5, LAND_SHAKE_MS))
      end = Math.max(end, delay + DEAL_MS)
    })
    await wait(end)
  }

  private async fadeAndDeal(count: number): Promise<void> {
    animate(this.canister()?.wrap, fadeKeyframes(1, 0), { duration: RM_CANISTER_FADE, fill: "forwards" })
    this.apply(resultHeadShown)
    this.apply(cardsDealt)
    for (let index = 0; index < count; index++) {
      animate(this.part(index, "travel"), fadeKeyframes(0, 1), { duration: RM_CARD_FADE, delay: index * RM_FADE_STAGGER, fill: "backwards" })
    }
    await this.timers.wait(Math.max(RM_CANISTER_FADE, RM_CARD_FADE + (count - 1) * RM_FADE_STAGGER))
  }

  private async openBooster(): Promise<void> {
    const before = this.state
    if (!before || this.apply(openingStarted) === before) return
    this.apply(lock)
    if (before.phase === "dealt") await this.retract()
    rememberPack(null)

    const key = this.current.pendingKey ?? newKey()
    this.apply((s) => arming(s, key))
    const reduced = motionReduced()
    if (!reduced) animate(this.canister()?.move, armKeyframes(), { duration: ARM_MS, fill: "forwards" })
    const [result] = await Promise.all([
      sendOpening({ url: this.openUrlValue, key, csrfToken: csrfToken() }),
      this.timers.wait(reduced ? 0 : ARM_MS),
    ])
    if (this.timers.disposed) return
    if (result.kind !== "opened") {
      this.refuse(result)
      return
    }

    const answer = result.answer
    this.keepFaces(answer)
    this.apply((s) => openingAnswered(s, answer))

    if (motionReduced()) await this.fadeAndDeal(answer.cards.length)
    else await this.blowAndDeal(answer.cards.length)

    this.apply(openingEnded)
    this.apply(unlock)
  }

  private async artReady(index: number): Promise<void> {
    const started = performance.now()
    while (!this.slot(index)?.querySelector(".booster-card__front .card__art[data-art]") && performance.now() - started < ART_WAIT_MAX) {
      await this.timers.wait(ART_POLL)
    }
  }

  private mark(index: number, quiet: boolean): void {
    const before = this.current
    const after = this.apply((s) => revealMarked(s, index, performance.now()))
    const card = after.answer?.cards[index]
    if (after === before || !card || !after.counts) return
    dispatchGameble("gameble:tier-revealed", { tier: card.tier, counts: after.counts })
    if (!quiet) this.announce(t(this.strings.announceCard, { position: index + 1, card: card.label, rarity: this.rarityNames[card.tier] }))
  }

  private riseLimit(index: number): number {
    if (!this.phoneLayout()) return LEGENDARY_JUMP_PX
    const frame = this.slot(index)?.querySelector(".booster-card__frame")
    const stage = this.shake
    if (!frame || !stage) return 0
    return phoneJump(frame.getBoundingClientRect().top - stage.getBoundingClientRect().top)
  }

  private swell(): (scale: number) => number {
    return (scale) => (this.phoneLayout() ? phoneSwell(scale) : scale)
  }

  private showBanner(tier: Rarity, large: boolean, line: string | null): void {
    this.apply((s) => bannerShown(s, { tier, large, line, reduced: motionReduced() }))
  }

  private async revealTier(index: number, tier: Rarity, quiet: boolean): Promise<void> {
    const { wait } = this.timers
    const level = tierIndex(tier)
    const lift = this.part(index, "lift")
    const flip = this.part(index, "flip")
    const height = Math.min(LIFT_PX[level] || COMMON_LIFT_PX, this.riseLimit(index))
    const swell = this.swell()
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
    this.mark(index, quiet)
    if (level >= 3) stageShake(this.shake, 5, EPIC_SHAKE_MS)
    const host = this.part(index, "fx")
    burst(host, tier)
    if (host) {
      const { width, height: boxHeight } = host.getBoundingClientRect()
      for (let count = 0; count < RINGS[level]; count++) {
        ring(host, `booster-fx__ring booster-fx__ring--${count % 2 === 0 ? "tier" : "white"}`, width / 2, boxHeight / 2 - height, 110 + level * 30, scaled(count * 90))
      }
    }
    if (level === 3) this.showBanner(tier, false, null)
    settle(lift)
    animate(lift, settleKeyframes(height, swell), { duration: SETTLE_MS[level], easing: "cubic-bezier(.2,.8,.3,1)", fill: "none" })
    await wait(SETTLE_MS[level])
  }

  private async revealLegendary(index: number, quiet: boolean): Promise<void> {
    const { wait, later } = this.timers
    const lift = this.part(index, "lift")
    const flip = this.part(index, "flip")
    const rise = this.riseLimit(index)
    const swell = this.swell()
    this.apply((s) => legendarySignalled(s, index))
    this.announce(this.strings.legendarySignal)

    settle(lift)
    animate(lift, legendaryJumpKeyframes(rise, swell), { duration: LEGENDARY_JUMP, fill: "forwards" })
    await wait(LEGENDARY_JUMP)

    animate(flip, legendarySpinKeyframes(), { duration: SPIN, easing: "cubic-bezier(.2,.6,.3,1)", fill: "none" })
    later(MARK_IN_SPIN, () => this.mark(index, quiet))
    await wait(IMPACT_AT)

    settle(lift)
    animate(lift, legendaryImpactKeyframes(rise, swell), { duration: scaled(360), easing: "ease-out", fill: "forwards" })
    const host = this.part(index, "fx")
    burst(host, "legendary")
    if (host && !motionReduced()) {
      const { width, height } = host.getBoundingClientRect()
      ;[0, 100, 200].forEach((delay, count) =>
        ring(host, `booster-fx__ring booster-fx__ring--${count % 2 === 0 ? "tier" : "white"}`, width / 2, height / 2 - rise, 200 + count * 60, scaled(delay)),
      )
    }
    stageFlash(this.flash, "gold", 0.5, LEGENDARY_FLASH_MS)
    stageShake(this.shake, 8, LEGENDARY_SHAKE_MS)
    this.showBanner("legendary", true, this.bannerLine(index))
    await wait(IMPACT)

    this.apply(legendaryEnded)
    settle(lift)
    animate(lift, legendaryDropKeyframes(rise, swell), { duration: DROP, easing: "cubic-bezier(.3,1.5,.5,1)", fill: "none" })
    later(scaled(300), () => stageShake(this.shake, 2, scaled(120)))
    await wait(DROP)
  }

  private async revealStill(index: number, tier: Rarity, quiet: boolean): Promise<void> {
    const legendary = tier === "legendary"
    if (legendary) {
      this.apply((s) => legendarySignalled(s, null))
      this.announce(this.strings.legendarySignal)
    }
    this.mark(index, quiet)
    animate(this.part(index, "lift"), fadeKeyframes(0.2, 1), { duration: RM_REVEAL_FADE, fill: "none" })
    if (legendary) {
      this.showBanner("legendary", true, this.bannerLine(index))
      await this.timers.wait(RM_LEGENDARY_STILL)
      this.apply(legendaryEnded)
    } else {
      await this.timers.wait(RM_REVEAL_FADE)
    }
  }

  private async reveal(index: number, fromAll: boolean, { awaitArt = true } = {}): Promise<void> {
    const before = this.current
    const card = before.answer?.cards[index]
    if (!card || this.apply((s) => revealStarted(s, index, fromAll)) === before) return
    this.apply(lock)
    if (awaitArt) await this.artReady(index)
    if (this.timers.disposed) return
    if (motionReduced()) await this.revealStill(index, card.tier, fromAll)
    else if (card.tier === "legendary") await this.revealLegendary(index, fromAll)
    else await this.revealTier(index, card.tier, fromAll)
    this.apply((s) => revealEnded(s, index, fromAll))
    this.apply(unlock)
  }

  private summary(tiers: Rarity[]): string {
    const { summary, summaryTier } = this.strings
    return revealSummary(tiers, { summary, summaryTier, rarityNames: this.rarityNames, delimiter: this.delimiterValue })
  }

  private async revealEveryCard(): Promise<void> {
    const before = this.state
    const answer = before?.answer
    if (!before || !answer || !canRevealAll(before)) return
    if (before.layout === "phone") {
      await this.revealAndStoreAll(answer)
      return
    }
    const plan = revealAllPlan(before)
    if (plan.length === 0) return
    this.apply(revealAllStarted)
    const running: Promise<void>[] = []
    for (const { index, wait: hold } of plan) {
      const done = this.reveal(index, true, { awaitArt: false })
      running.push(done)
      if (hold === "full") await done
      else await this.timers.wait(REVEAL_ALL_GAP)
    }
    await Promise.all(running)
    while (this.current.revealing.length > 0) await this.timers.wait(ART_POLL)
    this.apply(revealAllEnded)
    this.announce(this.summary(plan.map(({ index }) => answer.cards[index].tier)))
    this.whenIdle()
  }

  private async revealAndStoreAll(answer: OpeningAnswer): Promise<void> {
    this.apply(revealAllStarted)
    while (this.current.revealing.length > 0) await this.timers.wait(ART_POLL)
    const shown: Rarity[] = []
    for (let index = 0; index < answer.cards.length; index++) {
      if (this.timers.disposed || this.current.answer !== answer) return
      if (this.current.stored[index]) continue
      if (!this.current.revealed[index]) {
        await this.reveal(index, true)
        shown.push(answer.cards[index].tier)
      }
      await this.timers.wait(phoneAllHold(answer.cards[index].tier))
      await this.store(index, true)
    }
    this.apply(revealAllEnded)
    if (shown.length > 0) this.announce(this.summary(shown))
    this.whenIdle()
  }

  private async store(index: number, fromAll: boolean): Promise<void> {
    const before = this.current
    const card = before.answer?.cards[index]
    if (!card || this.apply((s) => storeStarted(s, index, fromAll, performance.now())) === before) return
    const float = this.part(index, "float")
    const frame = this.slot(index)?.querySelector(".booster-card__frame")
    const target = this.traySlot(index)
    const from = float?.style.transform || "none"
    if (float) float.style.transform = ""
    if (!motionReduced() && float && frame && target) {
      settle(float)
      animate(float, storeKeyframes(from, frame.getBoundingClientRect(), target.getBoundingClientRect()), {
        duration: STORE_MS,
        easing: "cubic-bezier(.45,0,.6,1)",
        fill: "forwards",
      })
      await this.timers.wait(STORE_MS)
    }
    if (this.timers.disposed) return
    this.apply((s) => cardStored(s, index))
    if (!motionReduced()) {
      animate(this.traySlot(index), slotPopKeyframes(), { duration: SLOT_POP_MS, easing: "cubic-bezier(.2,1.35,.35,1)" })
      traySparks(this.fx, this.traySlot(index), card.tier)
    }
    this.apply((s) => storeEnded(s, fromAll))
    this.whenIdle()
  }

  private springBack(index: number): void {
    const float = this.part(index, "float")
    if (!float) return
    const from = float.style.transform || "none"
    float.style.transform = ""
    if (!motionReduced()) animate(float, springBackKeyframes(from), { duration: SPRING_BACK_MS, easing: "cubic-bezier(.2,1.6,.4,1)" })
  }

  private leaveFor(index: number): void {
    const answer = this.state?.answer
    const card = answer?.cards[index]
    if (!answer || !card) return
    rememberPack(answer.pack.token)
    visit(cardHref(this.cardUrlValue, card.slug, answer.pack.token, index))
  }

  private async repost(index: number): Promise<string> {
    const card = this.state?.answer?.cards[index]
    if (!card || !this.repostUrlValue) return ""
    const result = await sendRepost({ url: repostHref(this.repostUrlValue, card.slug, card.season), csrfToken: csrfToken() })
    const message = result.kind === "reposted" ? this.strings.reposted : result.kind === "refused" ? result.message : this.strings.repostFailed
    dispatchGameble("gameble:toast", { message, tone: result.kind === "reposted" ? "notice" : "alert" })
    return message
  }

  private render(): void {
    const state = this.state
    if (!state) return
    const view = controls(state)
    const phone = state.layout === "phone"
    this.element.dataset.layout = state.layout
    this.element.dataset.phase = state.phase
    this.element.dataset.status = state.status
    this.element.setAttribute("aria-labelledby", phone ? "booster-title" : "booster-panel-title")

    this.renderInfo(state, view)
    this.renderActions(state, view)
    this.renderCanister(state)
    this.renderStage(state, view)
    this.renderBanner(state)
    this.renderPlate(state, view)
    this.renderTray(state, view)
    this.renderZoom(state, view)
    this.renderCelebrations(state, view)
    this.queueAfterRender()
  }

  private nextClock(): string | null {
    return this.left === null ? null : formatClock(this.left)
  }

  private nextLine(state: BoosterState): Clock | null {
    const clock = this.nextClock()
    const { reserveFull, nextAvailableAt } = state.bank
    if (reserveFull || clock === null || !nextAvailableAt) return null
    return { clock, spoken: t(this.strings.nextAt, { time: localTime(nextAvailableAt) }) }
  }

  private nextSize(state: BoosterState): number {
    return state.bank.nextPackSize ?? this.packSizeValue
  }

  private renderInfo(state: BoosterState, view: Controls): void {
    const { available, reserveFull } = state.bank
    const shownSize = state.answer?.cards.length || this.nextSize(state)
    const info = {
      lit: available,
      size: this.number(shownSize),
      reserve: t(this.strings.reserveCount, { count: available, n: this.number(available) }),
      tone: view.tone,
      reserveFull,
      next: this.nextLine(state),
    }
    for (const outlet of this.boosterInfoOutlets) outlet.render(info)
  }

  private renderActions(state: BoosterState, view: Controls): void {
    if (!this.hasBoosterActionsOutlet) return
    const actions = this.boosterActionsOutlet
    const host = state.layout === "phone" ? this.phoneActionsTarget : this.panelActionsTarget
    if (actions.element.parentElement !== host) host.append(actions.element)
    actions.arrange(state.layout)
    actions.render({
      open: view.open,
      openDisabled: view.openDisabled,
      busy: view.busy,
      revealAllDisabled: view.revealAllDisabled,
      locked: view.locked,
      reason: state.reason,
    })
  }

  private renderCanister(state: BoosterState): void {
    if (!this.hasBoosterCanisterOutlet) return
    const nextSize = this.nextSize(state)
    const clock = this.nextClock()
    const { nextAvailableAt } = state.bank
    const season = this.seasonValue
    this.boosterCanisterOutlet.render({
      away: state.canisterAway,
      empty: state.phase === "empty",
      next:
        clock !== null && nextAvailableAt
          ? { clock: t(this.strings.emptyNext, { time: clock }), spoken: t(this.strings.nextAt, { time: localTime(nextAvailableAt) }) }
          : null,
      label: season > 0 ? t(this.strings.canisterLabel, { season, count: nextSize }) : t(this.strings.canisterLabelPlain, { count: nextSize }),
      busy: state.phase !== "sealed" && state.phase !== "dealt",
      armed: state.armed,
      hintHidden: state.phase !== "sealed",
      facts: t(this.strings.canisterFacts, { count: nextSize, n: this.number(nextSize) }),
      docks: state.docks,
    })
  }

  private hintText(hint: Hint): string {
    switch (hint.kind) {
      case "remaining":
        return t(this.strings.hintRemaining, { count: hint.count, n: this.number(hint.count) })
      case "done":
        return t(this.strings.hintDone, { count: hint.count, n: this.number(hint.count) })
      default:
        return ""
    }
  }

  private hand(state: BoosterState): HandView | null {
    const answer = state.answer
    const cards = answer?.cards ?? []
    if (!answer || cards.length === 0) return null
    const phone = state.layout === "phone"
    const total = cards.length
    const cardName = (card: OpeningCard, index: number): string =>
      state.revealed[index]
        ? t(phone ? this.strings.faceUpStore : this.strings.faceUp, { card: card.label, rarity: this.rarityNames[card.tier] })
        : t(this.strings.faceDown, { position: index + 1, total })
    const shown: CardView[] = []
    cards.forEach((card, index) => {
      if (phone && state.stored[index]) return
      shown.push({
        index,
        tier: card.tier,
        revealed: state.revealed[index] ?? false,
        revealedAt: state.revealedAt[index],
        legendary: state.legendary === index,
        name: cardName(card, index),
        tierLabel: this.tierLabel(card.tier),
        repostName: t(this.strings.repostCard, { card: card.title }),
        depth: phone ? pileDepth(index, state.stored) : null,
      })
    })
    return { key: `${answer.pack.token}:${state.rebuilds}`, phone, cardBack: answer.pack.cardBack, dealt: state.dealt, cards: shown }
  }

  private renderStage(state: BoosterState, view: Controls): void {
    if (!this.hasBoosterStageOutlet) return
    const phone = state.layout === "phone"
    this.boosterStageOutlet.render(
      {
        legendary: state.legendary !== null,
        headShown: state.headShown,
        hand: this.hand(state),
        hint: !phone && view.hint ? this.hintText(view.hint) : null,
      },
      { face: this.face, icon: this.icon },
    )
  }

  private renderBanner(state: BoosterState): void {
    if (!this.hasBoosterStageOutlet) return
    const banner = state.layout === "phone" ? null : state.banner
    if ((banner?.key ?? null) === this.bannerKey) return
    this.bannerKey = banner?.key ?? null
    if (!banner) {
      this.boosterStageOutlet.hideBanner()
      return
    }
    const duration = bannerDuration(banner)
    this.boosterStageOutlet.showBanner(
      {
        tier: banner.tier,
        large: banner.large,
        name: banner.large ? this.tierLabel(banner.tier) : this.rarityNames[banner.tier],
        line: banner.line,
        keyframes: bannerKeyframes(banner.reduced),
        duration,
      },
      this.icon,
    )
    const key = banner.key
    this.timers.later(duration, () => this.apply((s) => bannerEnded(s, key)))
  }

  private onTable(state: BoosterState): boolean {
    return state.layout === "phone" && state.dealt && (state.answer?.cards.length ?? 0) > 0
  }

  private renderPlate(state: BoosterState, view: Controls): void {
    if (!this.hasBoosterPlateOutlet) return
    const answer = state.answer
    const top = view.plate === null ? null : answer?.cards[view.plate]
    const hint = state.layout === "phone" ? view.hint : null
    this.boosterPlateOutlet.render(
      {
        shown: this.onTable(state),
        hint: hint && { kind: hint.kind === "remaining" ? "done" : hint.kind, done: this.hintText(hint) },
        plate:
          view.plate !== null && top
            ? {
                key: `${answer?.pack.token}-${view.plate}`,
                tier: top.tier,
                tierText: this.tierLabel(top.tier),
                line: t(this.strings.bannerLine, { title: top.title, year: top.year ?? "" }),
              }
            : null,
        celebrating: Boolean(shownCelebration(state)) && view.plate === null,
        busy: view.busy,
      },
      this.icon,
    )
  }

  private renderTray(state: BoosterState, view: Controls): void {
    if (!this.hasBoosterTrayOutlet) return
    const answer = state.answer
    const cards = answer?.cards ?? []
    this.boosterTrayOutlet.render(
      {
        key: `${answer?.pack.token ?? ""}:${state.rebuilds}`,
        shown: this.onTable(state),
        count: t(this.strings.trayCount, { n: this.number(view.storedCount), total: this.number(cards.length) }),
        busy: view.busy,
        slots: cards.map((card, index) => ({
          tier: card.tier,
          coverUrl: card.coverUrl,
          name: t(this.strings.traySlot, { card: card.label, rarity: this.rarityNames[card.tier] }),
          stored: state.stored[index] ?? false,
        })),
      },
      this.icon,
    )
  }

  private renderZoom(state: BoosterState, view: Controls): void {
    if (!this.hasBoosterZoomOutlet) return
    const { zoom, answer } = state
    const card = zoom !== null && state.layout === "phone" ? answer?.cards[zoom] : null
    this.boosterZoomOutlet.render(
      card && zoom !== null && answer
        ? {
            index: zoom,
            tier: card.tier,
            title: card.title,
            line: t(this.strings.zoomLine, { rarity: this.rarityNames[card.tier], year: card.year ?? "" }),
            href: cardHref(this.cardUrlValue, card.slug, answer.pack.token, zoom),
            repostName: t(this.strings.repostCard, { card: card.title }),
            previous: view.zoomPrevious,
            next: view.zoomNext,
          }
        : null,
      { face: (index) => this.faceFragment(index, "xl"), icon: this.icon },
    )
  }

  private resultView(result: CelebrationResult, position: number): ResultView {
    const strings = this.strings.celebration
    const count = countParts(result, strings, this.delimiterValue)
    const { from, to } = gaugeFractions(result)
    return {
      url: result.url,
      tier: result.tier,
      label: resultLinkName(result, strings, this.delimiterValue),
      title: resultTitle(result, strings),
      name: result.name,
      before: count.before,
      owned: count.owned,
      rest: count.rest,
      position,
      from,
      to,
      juice: juice(result.tier),
      ticks: gaugeTicks(result),
    }
  }

  private celebrationView(state: BoosterState, results: readonly CelebrationResult[], phone: boolean): CelebrationView {
    const strings = this.strings.celebration
    const isFolded = folded(results)
    const shown = shownResult(state)
    const stepping = phone && !isFolded && results.length > 1
    const subline = isFolded ? foldedSubline(results, strings) : null
    return {
      identity: results,
      steps: phone ? state.celebrationSteps : 0,
      still: state.celebrationStill && (!phone || state.celebrationSteps === 0),
      results: isFolded ? [] : phone ? [this.resultView(results[shown], 0)] : results.map((result, position) => this.resultView(result, position)),
      folded:
        isFolded && subline
          ? {
              label: foldedLinkName(results, strings),
              title: foldedTitle(results, strings),
              marks: foldedMarks(results),
              lead: subline.lead,
              set: subline.set,
              tier: subline.tier,
            }
          : null,
      position: stepping ? t(strings.position, { index: shown + 1, count: results.length }) : null,
    }
  }

  private renderCelebrations(state: BoosterState, view: Controls): void {
    const results = shownCelebration(state)
    const phone = state.layout === "phone"
    for (const outlet of this.boosterCelebrationOutlets) {
      const shows = results !== null && results.length > 0 && (outlet.phone ? phone && this.onTable(state) && view.plate === null : !phone)
      outlet.render(shows && results ? this.celebrationView(state, results, outlet.phone) : null)
    }
  }
}

export default BoosterController
