import {
  arming,
  blastMarked,
  cardsDealt,
  ejecting,
  heldEntry,
  heldFor,
  heldOpened,
  lock,
  nextCapsuleWaiting,
  openingAnswered,
  openingEnded,
  openingRefused,
  openingRoute,
  openingStarted,
  resultHeadShown,
  retracted,
  retracting,
  touchMarked,
  unlock,
  type BoosterState,
  type OpeningRefusal,
  type Reserve,
} from "./booster"
import {
  BLAST_AT,
  OPENED_AT,
  breakCapsule,
  holdAll,
  lightFuse,
  quakeFrames,
  quakeTiming,
  releaseAll,
} from "./booster_capsule_timeline"
import { flashBlast, glitchScreen, shakeScreen, slamCard } from "./booster_blast"
import { CHARGE_TAPS, chargeCapsule } from "./booster_capsule_charge"
import {
  CARD_LANDS_AFTER_LEAVING,
  ROW_REST,
  cardFlight,
  darkenRow,
  flightRank,
  flightTurn,
  leavesAfterBlast,
  lightRow,
} from "./booster_deal_flight"
import { animate, settle } from "./booster_effects"
import type { BoosterStageHost } from "./booster_host"
import { dockKeyframes, fadeKeyframes, sinkKeyframes } from "./booster_keyframes"
import {
  DOCK,
  RM_CANISTER_FADE,
  RM_CARD_FADE,
  RM_FADE_STAGGER,
  SINK,
  SINK_STAGGER,
  pileDepth,
  pileOrder,
  pilePose,
  pileTransform,
  pose,
} from "./booster_motion"
import { csrfToken, newKey, rememberPack } from "./booster_page"
import { Sparks, type SparkPoint } from "./booster_sparks"
import { dispatchGameble } from "./events"
import { motionReduced } from "./motion"
import { sendOpening, type OpeningAnswer, type OpeningResult } from "./opening"
import type { QueuedOpening } from "./opening_queue"

export type OpeningSequenceHost = BoosterStageHost &
  Readonly<{
    root: HTMLElement
    openUrl: string
    reserve: () => string
    failedMessage: string
    refusedTitle: string
    keepFaces: (answer: OpeningAnswer) => void
    refreshBank: () => Promise<void>
    confirm: (entry: QueuedOpening) => void
    awaitConfirmation: (reserve: Reserve) => Promise<boolean>
  }>

export class OpeningSequence {
  private skipping = false
  private deal = 0
  private skipped: Promise<void> = new Promise(() => {})
  private skipNow = (): void => {}
  private fuse: Animation[] = []
  private readonly sparks: Sparks

  constructor(private readonly host: OpeningSequenceHost) {
    this.sparks = new Sparks(() => host.sparks())
  }

  async open(): Promise<void> {
    const { host } = this
    const touchedAt = performance.now()
    const before = host.current()
    if (host.apply(openingStarted) === before) return
    host.apply(lock)
    dispatchGameble("gameble:capsule-touched", null)
    this.armSkip()
    if (openingRoute(host.current()) === "send") await this.openBySending(before, touchedAt)
    else await this.openHeld(before, touchedAt)
  }

  skip(): void {
    if (this.skipping || this.host.current().phase !== "opening") return
    this.skipping = true
    this.skipNow()
  }

  private async openHeld(before: BoosterState, touchedAt: number): Promise<void> {
    const { host } = this
    if (before.phase === "dealt") await this.retract()
    rememberPack(null)
    host.apply((s) => touchMarked(arming(s, null), touchedAt))
    const reduced = this.arm()
    const awaited = heldFor(host.current()) ? true : host.awaitConfirmation(host.current().reserve)
    const [landed] = await Promise.all([awaited, this.untilBlast(reduced)])
    if (host.timers().disposed) return
    const entry = heldEntry(host.current(), newKey())
    if (!entry) {
      if (landed) await this.answered(await this.send(this.armedKey()))
      else this.refuse({ kind: "failed" })
      return
    }
    const answer = heldOpened(host.current(), entry).answer!
    host.keepFaces(answer)
    host.apply((s) => heldOpened(s, entry))
    host.confirm(entry)
    await this.dealHand(answer.cards.length)
  }

  private async openBySending(before: BoosterState, touchedAt: number): Promise<void> {
    const { host } = this
    const key = host.current().pendingKey ?? newKey()
    const request = this.send(key)
    if (before.phase === "dealt") await this.retract()
    rememberPack(null)
    host.apply((s) => touchMarked(arming(s, key), touchedAt))
    const reduced = this.arm()
    const [result] = await Promise.all([request, this.untilBlast(reduced)])
    await this.answered(result)
  }

  private armedKey(): string {
    const key = this.host.current().pendingKey ?? newKey()
    this.host.apply((s) => arming(s, key))
    return key
  }

  private send(key: string): Promise<OpeningResult> {
    return sendOpening({ url: this.host.openUrl, reserve: this.host.reserve(), key, csrfToken: csrfToken() })
  }

  private arm(): boolean {
    const reduced = motionReduced()
    const wrap = this.host.canister()?.wrap
    this.fuse = reduced ? [] : [...lightFuse(wrap), ...chargeCapsule(wrap, this.host.scanlines())]
    if (!reduced) {
      CHARGE_TAPS.forEach(([delay, level]) =>
        this.laterInThisDeal(delay, () => dispatchGameble("gameble:capsule-charging", { level })),
      )
    }
    return reduced
  }

  // The fuse burns to the break; with no answer yet, the capsule holds there.
  private async untilBlast(reduced: boolean): Promise<void> {
    await this.pause(reduced ? 0 : BLAST_AT)
    if (!this.skipping) holdAll(this.fuse)
  }

  private async answered(result: OpeningResult): Promise<void> {
    const { host } = this
    if (host.timers().disposed) return
    if (result.kind !== "opened") {
      this.refuse(result)
      return
    }
    const answer = result.answer
    host.keepFaces(answer)
    host.apply((s) => openingAnswered(s, answer))
    await this.dealHand(answer.cards.length)
  }

  private async dealHand(count: number): Promise<void> {
    this.host.apply((s) => blastMarked(s, performance.now()))
    if (motionReduced()) await this.fadeAndDeal(count)
    else await this.blowAndDeal(count)
    this.host.apply(openingEnded)
    this.host.apply(unlock)
  }

  private armSkip(): void {
    this.deal++
    this.skipping = false
    this.skipped = new Promise((resolve) => (this.skipNow = resolve))
  }

  private async pause(ms: number): Promise<void> {
    await Promise.race([this.host.timers().wait(ms), this.skipped])
    if (this.skipping) this.finishAnimations()
  }

  private finishAnimations(): void {
    this.sparks.clear()
    for (const animation of this.host.root.getAnimations?.({ subtree: true }) ?? []) {
      if (Number.isFinite(animation.effect?.getComputedTiming().endTime)) animation.finish()
    }
  }

  private refuse(result: OpeningRefusal): void {
    const { host } = this
    this.fuse.forEach((animation) => animation.cancel())
    this.fuse = []
    const message = host.apply((s) => openingRefused(s, result, host.failedMessage)).reason ?? host.failedMessage
    host.announce(message)
    const refused = result.kind === "refused"
    dispatchGameble(
      "gameble:toast",
      refused ? { title: host.refusedTitle, message, tone: "alert" } : { message, tone: "alert" },
    )
    host.apply(unlock)
    if (refused) void host.refreshBank()
  }

  private async retract(): Promise<void> {
    const { host } = this
    const { wait } = host.timers()
    const count = host.current().answer?.cards.length ?? 0
    const alreadyDocked = nextCapsuleWaiting(host.current())
    host.apply(retracting)
    darkenRow(host.dealFx())
    if (!motionReduced()) {
      for (let index = 0; index < count; index++) {
        const travel = host.part(index, "travel")
        const from = host.phoneLayout() ? pileTransform(pileDepth(index, host.current().stored)) : pose()
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
    host.apply(retracted)
    if (!motionReduced() && !alreadyDocked) {
      animate(host.canister()?.wrap, dockKeyframes(), {
        duration: DOCK,
        easing: "cubic-bezier(.2,.9,.3,1)",
        fill: "none",
      })
      await wait(DOCK)
    }
  }

  private async blowAndDeal(count: number): Promise<void> {
    const { host } = this
    const parts = host.canister()
    host.apply(ejecting)
    releaseAll(this.fuse)
    breakCapsule(parts?.fx)
    animate(host.shake(), quakeFrames(), quakeTiming)
    const phone = host.phoneLayout()
    const origin = parts?.button?.getBoundingClientRect()
    this.blast(origin, phone)
    host.apply(resultHeadShown)
    host.apply(cardsDealt)

    const order = phone ? pileOrder(count) : Array.from({ length: count }, (_, index) => index)
    const row: DOMRect[] = []
    order.forEach((index, position) => {
      const rank = phone ? position : flightRank(index, count)
      const slot = host.slot(index)
      const travel = host.part(index, "travel")
      const rect = slot ? (slot.querySelector(".booster-card__frame") ?? slot).getBoundingClientRect() : null
      this.setDown(index, leavesAfterBlast(rank) + CARD_LANDS_AFTER_LEAVING, rect, phone)
      if (!rect || !travel || !origin) return
      row.push(rect)
      const { keyframes, options } = cardFlight({
        dx: origin.left + origin.width / 2 - (rect.left + rect.width / 2),
        dy: origin.top + origin.height / 2 - (rect.top + rect.height / 2),
        rank,
        turn: flightTurn(index, count),
        height: rect.height,
        rest: phone ? pilePose(pileDepth(index, host.current().stored)) : ROW_REST,
        phone,
      })
      animate(travel, keyframes, options)
    })
    if (!phone) lightRow(host.dealFx(), row)
    await this.pause(OPENED_AT - BLAST_AT)
  }

  private blast(origin: DOMRect | undefined, phone: boolean): void {
    const { host } = this
    dispatchGameble("gameble:capsule-burst", null)
    flashBlast(host.flash())
    shakeScreen(host.shake(), phone)
    glitchScreen(host.shake(), host.scanlines())
    const centre = origin && this.onSparks(origin.left + origin.width / 2, origin.top + origin.height / 2)
    if (centre) this.sparks.burst(centre, phone ? 70 : 110)
  }

  // The card lands: a tap, a knock on the stage and a puff of dust under it.
  private setDown(index: number, delay: number, frame: DOMRect | null, phone: boolean): void {
    this.laterInThisDeal(delay, () => {
      dispatchGameble("gameble:card-dealt", { index })
      slamCard(this.host.shake(), phone)
      const floor = frame && this.onSparks(frame.left + frame.width / 2, frame.bottom)
      if (floor && frame) this.sparks.dust(floor, frame.width / 2 - 10)
    })
  }

  private onSparks(x: number, y: number): SparkPoint | null {
    const box = this.sparks.origin()
    return box ? { x: x - box.left, y: y - box.top } : null
  }

  private laterInThisDeal(delay: number, action: () => void): void {
    const deal = this.deal
    this.host.timers().later(delay, () => {
      if (deal === this.deal && !this.skipping) action()
    })
  }

  private async fadeAndDeal(count: number): Promise<void> {
    const { host } = this
    animate(host.canister()?.wrap, fadeKeyframes(1, 0), { duration: RM_CANISTER_FADE, fill: "forwards" })
    host.apply(resultHeadShown)
    host.apply(cardsDealt)
    for (let index = 0; index < count; index++) {
      this.laterInThisDeal(index * RM_FADE_STAGGER, () => dispatchGameble("gameble:card-dealt", { index }))
      animate(host.part(index, "travel"), fadeKeyframes(0, 1), {
        duration: RM_CARD_FADE,
        delay: index * RM_FADE_STAGGER,
        fill: "backwards",
      })
    }
    await this.pause(Math.max(RM_CANISTER_FADE, RM_CARD_FADE + (count - 1) * RM_FADE_STAGGER))
  }
}
