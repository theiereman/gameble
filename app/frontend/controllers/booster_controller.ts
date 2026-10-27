import { Controller } from "@hotwired/stimulus"
import { BankRefresh } from "../lib/booster_bank_refresh"
import type { BoosterStageHost, Transition } from "../lib/booster_host"
import { OpeningSequence } from "../lib/booster_opening_sequence"
import { BoosterRenderer } from "../lib/booster_render"
import type { BoosterOutlets, BoosterStrings } from "../lib/booster_render_host"
import { BoosterCountdown } from "../lib/booster_countdown"
import { animate, burst, ring, settle, stageFlash, stageShake, traySparks } from "../lib/booster_effects"
import { fadeKeyframes, flipKeyframes, legendaryDropKeyframes, legendaryImpactKeyframes, legendaryJumpKeyframes, legendarySpinKeyframes, liftKeyframes, settleKeyframes, slotPopKeyframes, springBackKeyframes, storeKeyframes, trembleKeyframes } from "../lib/booster_keyframes"
import { bankFrom, openedFrom } from "../lib/booster_markup"
import { ART_POLL, ART_WAIT_MAX, COMMON_LIFT_MS, COMMON_LIFT_PX, DROP, EPIC_SHAKE_MS, FLIP_MS, IMPACT, IMPACT_AT, LEGENDARY_FLASH_MS, LEGENDARY_JUMP, LEGENDARY_JUMP_PX, LEGENDARY_SHAKE_MS, LIFT_PX, MARK_AT, MARK_IN_SPIN, REVEAL_ALL_GAP, RINGS, RM_LEGENDARY_STILL, RM_REVEAL_FADE, SETTLE_MS, SLOT_POP_MS, SPIN, SPRING_BACK_MS, STORE_MS, TREMBLE_MS, phoneAllHold, phoneJump, phoneSwell, revealSummary, scaled, swipeStores, tierIndex } from "../lib/booster_motion"
import { cardHref, celebrationRemembered, csrfToken, readLayout, rememberPack, visit } from "../lib/booster_page"
import type { SwipeRelease } from "../lib/booster_swipe"
import { RARITIES, type Rarity } from "../lib/card_types"
import { celebrationAnnouncement } from "../lib/celebration"
import { dispatchGameble } from "../lib/events"
import { formatNumber, t } from "../lib/i18n"
import { motionReduced } from "../lib/motion"
import { type OpeningAnswer } from "../lib/opening"
import { repostHref, sendRepost } from "../lib/repost"
import { serverTemplate } from "../lib/server_html"
import { NARROW_QUERY, PHONE_QUERY, activation, bankDue, bannerShown, canRevealAll, canStore, cardStored, celebrationSpoken, celebrationStepped, celebrationToAnnounce, faceSize, focusGiven, focusTarget, layoutApplied, layoutAsked, layoutFor, legendaryEnded, legendarySignalled, lock, lockReleased, owedBankTaken, revealAllEnded, revealAllPlan, revealAllStarted, revealEnded, revealMarked, revealStarted, revealingOpening, start, storeEnded, storeStarted, topOfPile, unlock, zoomClosed, zoomOpened, zoomStepped, type BoosterState, type FocusTarget } from "../lib/booster"
import { screenTimers, type ScreenTimers } from "../lib/screen_timers"
import { cloneContent, cloneFirstElement } from "../lib/templates"
import type { Intent } from "../lib/screen"
import type BoosterActionsController from "./booster_actions_controller"
import type BoosterCanisterController from "./booster_canister_controller"
import type BoosterCelebrationController from "./booster_celebration_controller"
import type BoosterInfoController from "./booster_info_controller"
import type BoosterPlateController from "./booster_plate_controller"
import type BoosterStageController from "./booster_stage_controller"
import type { CardIntent } from "./booster_stage_controller"
import type BoosterTrayController from "./booster_tray_controller"
import type BoosterZoomController from "./booster_zoom_controller"

const ANNOUNCEMENTS_KEPT = 5

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
  private afterRenderQueued = false
  private media: { phone: MediaQueryList; narrow: MediaQueryList } | null = null

  private readonly stageHost: BoosterStageHost = {
    current: () => this.current,
    timers: () => this.timers,
    apply: (transition) => this.apply(transition),
    announce: (text) => this.announce(text),
    part: (index, name) => this.part(index, name),
    slot: (index) => this.slot(index),
    traySlot: (index) => this.traySlot(index),
    shake: () => this.shake,
    fx: () => this.fx,
    flash: () => this.flash,
    canister: () => this.canister(),
    phoneLayout: () => this.phoneLayout(),
  }

  private readonly outletSet = (): BoosterOutlets => ({
    info: this.boosterInfoOutlets,
    actions: this.hasBoosterActionsOutlet ? this.boosterActionsOutlet : null,
    canister: this.hasBoosterCanisterOutlet ? this.boosterCanisterOutlet : null,
    stage: this.hasBoosterStageOutlet ? this.boosterStageOutlet : null,
    plate: this.hasBoosterPlateOutlet ? this.boosterPlateOutlet : null,
    tray: this.hasBoosterTrayOutlet ? this.boosterTrayOutlet : null,
    zoom: this.hasBoosterZoomOutlet ? this.boosterZoomOutlet : null,
    celebrations: this.boosterCelebrationOutlets,
  })

  private renderer?: BoosterRenderer
  private opening?: OpeningSequence
  private bankRefresh?: BankRefresh

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
    this.assembleCollaborators()
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
      { left: (seconds) => this.countdownLeft(seconds), zero: () => this.bankRefresh?.atZero() },
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
    void this.opening?.open()
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

  private render(): void {
    const state = this.state
    if (!state || !this.renderer) return
    this.renderer.render(state)
    this.queueAfterRender()
  }

  private assembleCollaborators(): void {
    this.bankRefresh = new BankRefresh({
      state: () => this.state,
      current: () => this.current,
      bankUrl: this.bankUrlValue,
      disposed: () => this.timers.disposed,
      apply: (transition) => this.apply(transition),
    })
    this.opening = new OpeningSequence({
      ...this.stageHost,
      openUrl: this.openUrlValue,
      failedMessage: this.strings.failed,
      refusedTitle: this.strings.refusedTitle,
      keepFaces: (answer) => this.keepFaces(answer),
      refreshBank: () => this.bankRefresh!.refresh(),
    })
    this.renderer = new BoosterRenderer({
      element: this.element,
      panelActions: this.panelActionsTarget,
      phoneActions: this.phoneActionsTarget,
      strings: this.strings,
      delimiter: this.delimiterValue,
      packSize: this.packSizeValue,
      season: this.seasonValue,
      cardUrl: this.cardUrlValue,
      left: () => this.left,
      rarityNames: () => this.rarityNames,
      timers: () => this.timers,
      outlets: this.outletSet,
      apply: (transition) => this.apply(transition),
      tierLabel: (tier) => this.tierLabel(tier),
      number: (value) => this.number(value),
      face: this.face,
      faceFragment: (index, size) => this.faceFragment(index, size),
      icon: this.icon,
    })
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
    void this.bankRefresh?.refresh()
  }

  private countdownLeft(seconds: number | null): void {
    this.left = seconds
    this.render()
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

}

export default BoosterController
