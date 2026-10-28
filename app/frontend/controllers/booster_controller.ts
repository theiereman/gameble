import { Controller } from "@hotwired/stimulus"
import { BankRefresh } from "../lib/booster_bank_refresh"
import type { Transition } from "../lib/booster_host"
import { OpeningSequence } from "../lib/booster_opening_sequence"
import { OutletAccess, outletsOf, stageHostFor } from "../lib/booster_outlet_access"
import { reflectChange } from "../lib/booster_reflect"
import { startingState } from "../lib/booster_start"
import { AfterRender } from "../lib/booster_after_render"
import { gameplayFor, type Gameplay } from "../lib/booster_gameplay"
import { BoosterFaces } from "../lib/booster_faces"
import { LayoutWatch } from "../lib/booster_layout_watch"
import { BoosterRenderer } from "../lib/booster_render"
import type { BankValues } from "../lib/booster_markup"
import type { BoosterStrings } from "../lib/booster_render_host"
import { BoosterCountdown, browserCountdown } from "../lib/booster_countdown"
import { swipeStores } from "../lib/booster_motion"
import { rememberPack } from "../lib/booster_page"
import type { SwipeRelease } from "../lib/booster_swipe"
import { dispatchGameble } from "../lib/events"
import { formatNumber } from "../lib/i18n"
import {
  activation,
  bankDue,
  canStore,
  celebrationStepped,
  faceSize,
  layoutApplied,
  lockReleased,
  owedBankTaken,
  reserveSelected,
  revealingOpening,
  topOfPile,
  zoomClosed,
  zoomOpened,
  zoomStepped,
  type BoosterState,
  type Reserve,
} from "../lib/booster"
import { screenTimers, type ScreenTimers } from "../lib/screen_timers"
import { cloneFirstElement } from "../lib/templates"
import type { Intent } from "../lib/screen"
import type BoosterActionsController from "./booster_actions_controller"
import type BoosterCanisterController from "./booster_canister_controller"
import type BoosterCelebrationController from "./booster_celebration_controller"
import type BoosterInfoController from "./booster_info_controller"
import type BoosterReservesController from "./booster_reserves_controller"
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
    reserve: String,
    cardUrl: String,
    repostUrl: String,
    bankUrl: String,
    delimiter: String,
    packSize: Number,
    season: Number,
    bank: Object,
    strings: Object,
  }
  static outlets = [
    "booster-info",
    "booster-actions",
    "booster-reserves",
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
  declare readonly reserveValue: Reserve
  declare readonly cardUrlValue: string
  declare readonly repostUrlValue: string
  declare readonly bankUrlValue: string
  declare readonly delimiterValue: string
  declare readonly packSizeValue: number
  declare readonly seasonValue: number
  declare readonly bankValue: BankValues
  declare readonly stringsValue: BoosterStrings
  declare readonly boosterInfoOutlets: BoosterInfoController[]
  declare readonly hasBoosterActionsOutlet: boolean
  declare readonly boosterActionsOutlet: BoosterActionsController
  declare readonly hasBoosterReservesOutlet: boolean
  declare readonly boosterReservesOutlet: BoosterReservesController
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
  private readonly faces = new BoosterFaces()

  private readonly access = new OutletAccess(() => outletsOf(this))

  private readonly stageHost = stageHostFor(this.access, {
    current: () => this.current,
    timers: () => this.timers,
    apply: (transition) => this.apply(transition),
    announce: (text) => this.announce(text),
    phoneLayout: () => this.phoneLayout(),
  })

  private renderer?: BoosterRenderer
  private opening?: OpeningSequence
  private bankRefresh?: BankRefresh
  private afterRender?: AfterRender
  private layoutWatch?: LayoutWatch
  private gameplay?: Gameplay

  private readonly visibilityChanged = (): void => this.countdown?.visibilityChanged()

  private readonly face = (index: number): DocumentFragment | null => {
    const size = this.state ? faceSize(this.state.layout) : "m"
    return this.faces.faceFragment(index, size)
  }

  connect(): void {
    this.timers = screenTimers()
    this.faces.readRarities(this.rarityTargets)
    this.faces.readFaces(this.faceTargets)
    this.assembleCollaborators()
    this.state = startingState({
      bank: this.bankValue,
      reserve: this.reserveValue,
      pack: this.hasPackTarget ? this.packTarget.dataset : null,
      cards: this.cardTargets.map((card) => card.dataset),
      setTiers: this.setTierTargets.map((row) => row.dataset),
    })
    this.countdown = browserCountdown({
      left: (seconds) => this.countdownLeft(seconds),
      zero: () => this.bankRefresh?.atZero(),
    })
    document.addEventListener("visibilitychange", this.visibilityChanged)
    this.countdown.set(this.state.bank.nextAvailableAt, this.state.bank.serverTime)
    this.render()
    dispatchGameble("gameble:opening-revealing", { revealing: revealingOpening(this.state.status) })
    this.layoutWatch?.start()
    this.afterRender?.queue()
  }

  disconnect(): void {
    this.timers.dispose()
    this.countdown?.dispose()
    this.countdown = undefined
    document.removeEventListener("visibilitychange", this.visibilityChanged)
    this.layoutWatch?.stop()
    const before = this.state
    if (before && before.lockDepth > 0) dispatchGameble("gameble:navigation-locked", { locked: false })
    if (before) this.state = lockReleased(before)
    dispatchGameble("gameble:opening-revealing", { revealing: false })
  }

  boosterInfoOutletConnected = (): void => this.render()
  boosterActionsOutletConnected = (): void => this.render()
  boosterCanisterOutletConnected = (): void => this.render()
  boosterStageOutletConnected = (): void => this.render()
  boosterPlateOutletConnected = (): void => this.render()
  boosterTrayOutletConnected = (): void => this.render()
  boosterZoomOutletConnected = (): void => this.render()
  boosterCelebrationOutletConnected = (): void => this.render()
  selectReserve = ({ detail: { reserve } }: Intent<{ reserve: Reserve }>): void =>
    void this.apply((s) => reserveSelected(s, reserve))

  open(): void {
    void this.opening?.open()
  }

  revealAll(): void {
    void this.gameplay?.everyReveal.run()
  }

  guardBack(event: Event): void {
    if ((this.state?.lockDepth ?? 0) > 0) event.preventDefault()
  }

  activateCard({ detail: { index } }: Intent<CardIntent>): void {
    if (!this.state) return
    const action = activation(
      this.state,
      index,
      performance.now(),
      this.hasBoosterStageOutlet ? this.boosterStageOutlet.lastDragEnd : -Infinity,
    )
    if (action === "reveal") void this.gameplay?.reveals.reveal(index, false)
    else if (action === "store") void this.gameplay?.cardStore.store(index, false)
    else if (action === "leave") this.gameplay?.cardExit.leaveFor(index)
  }

  repostCard({ detail: { index } }: Intent<CardIntent>): void {
    void this.gameplay?.cardExit.repost(index)
  }

  pressCard(event: Intent<CardIntent>): void {
    if (this.state && canStore(this.state, event.detail.index, false, performance.now())) event.preventDefault()
  }

  releaseCard({ detail: { index, dx, dy, abandoned } }: Intent<SwipeRelease>): void {
    if (this.state && !abandoned && swipeStores(dx, dy) && canStore(this.state, index, false, performance.now()))
      void this.gameplay?.cardStore.store(index, false)
    else this.gameplay?.cardStore.springBack(index)
  }

  storeTop(): void {
    if (!this.state) return
    const index = topOfPile(this.state.revealed, this.state.stored)
    if (index !== null) void this.gameplay?.cardStore.store(index, false)
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
    this.gameplay?.cardExit.leaveFor(zoom)
  }

  repostZoomed(): void {
    const zoom = this.state?.zoom ?? null
    if (zoom === null) return
    const showing = this.hasBoosterZoomOutlet ? this.boosterZoomOutlet.showing : null
    void this.gameplay?.cardExit.repost(zoom).then((message) => {
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
    reflectChange(before, after, this.countdown, () => {
      if (!this.timers.disposed) this.whenIdle()
    })
    return after
  }

  private announce(text: string): void {
    const span = cloneFirstElement(this.announcementTarget)
    if (!span) return
    span.textContent = text
    this.liveTarget.append(span)
    while (this.liveTarget.children.length > ANNOUNCEMENTS_KEPT) this.liveTarget.firstElementChild?.remove()
  }

  private render(): void {
    const state = this.state
    if (!state || !this.renderer) return
    this.renderer.render(state)
    this.afterRender?.queue()
  }

  private assembleCollaborators(): void {
    this.bankRefresh = new BankRefresh({
      state: () => this.state,
      current: () => this.current,
      bankUrl: this.bankUrlValue,
      disposed: () => this.timers.disposed,
      apply: (transition) => this.apply(transition),
      announce: (r) => this.announce(r === "special" ? this.strings.specialArrived : this.strings.standardReady),
    })
    this.opening = new OpeningSequence({
      ...this.stageHost,
      openUrl: this.openUrlValue,
      reserve: () => this.current.reserve,
      failedMessage: this.strings.failed,
      refusedTitle: this.strings.refusedTitle,
      keepFaces: (answer) => this.faces.keepFaces(answer),
      refreshBank: () => this.bankRefresh!.refresh(),
    })
    this.afterRender = new AfterRender({
      state: () => this.state,
      disposed: () => this.timers.disposed,
      apply: (transition) => this.apply(transition),
      announce: (text) => this.announce(text),
      focusElement: (target) => this.access.focusElement(target),
      celebrationStrings: this.strings.celebration,
      delimiter: this.delimiterValue,
    })
    this.layoutWatch = new LayoutWatch({
      apply: (transition) => this.apply(transition),
      whenIdle: () => this.whenIdle(),
    })
    this.gameplay = gameplayFor({
      stage: this.stageHost,
      strings: this.strings,
      delimiter: this.delimiterValue,
      cardUrl: this.cardUrlValue,
      repostUrl: this.repostUrlValue,
      state: () => this.state,
      rarityNames: () => this.faces.rarityNames,
      whenIdle: () => this.whenIdle(),
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
      rarityNames: () => this.faces.rarityNames,
      timers: () => this.timers,
      outlets: () => outletsOf(this),
      apply: (transition) => this.apply(transition),
      tierLabel: (tier) => this.faces.tierLabel(tier),
      number: (value) => this.number(value),
      face: this.face,
      faceFragment: (index, size) => this.faces.faceFragment(index, size),
      icon: (tier) => this.faces.icon(tier),
    })
  }

  private number(value: number): string {
    return formatNumber(value, this.delimiterValue)
  }

  private phoneLayout(): boolean {
    return this.current.layout === "phone"
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
}

export default BoosterController
