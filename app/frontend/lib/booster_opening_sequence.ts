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
import { animate, blast, settle, stageFlash, stageShake } from "./booster_effects"
import type { BoosterStageHost } from "./booster_host"
import {
  armKeyframes,
  bodyKeyframes,
  capBottomKeyframes,
  capTopKeyframes,
  dockKeyframes,
  fadeKeyframes,
  sinkKeyframes,
} from "./booster_keyframes"
import {
  ARM_MS,
  BODY_MS,
  CAPS_MS,
  DEAL_LAND_AT,
  DEAL_MS,
  DEAL_STAGGER,
  DOCK,
  FLASH_MS,
  HEAD_DELAY,
  LAND_SHAKE_MS,
  PHONE_DEAL_STAGGER,
  RAYS_FADE_MS,
  RM_CANISTER_FADE,
  RM_CARD_FADE,
  RM_FADE_STAGGER,
  SHAKE_MS,
  SINK,
  SINK_STAGGER,
  dealKeyframes,
  dealOrder,
  dealRotation,
  pileDepth,
  pileOrder,
  pilePose,
  pileTransform,
  pose,
} from "./booster_motion"
import { csrfToken, newKey, rememberPack } from "./booster_page"
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

  constructor(private readonly host: OpeningSequenceHost) {}

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
    const [landed] = await Promise.all([awaited, this.pause(reduced ? 0 : ARM_MS)])
    if (host.timers().disposed) return
    const entry = heldEntry(host.current(), newKey())
    if (!entry) {
      if (landed) await this.answered(await this.send(this.armedKey()))
      else this.refuse({ kind: "failed" })
      return
    }
    const answer = host.apply((s) => heldOpened(s, entry)).answer!
    host.keepFaces(answer)
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
    const [result] = await Promise.all([request, this.pause(reduced ? 0 : ARM_MS)])
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
    if (!reduced) animate(this.host.canister()?.move, armKeyframes(), { duration: ARM_MS, fill: "forwards" })
    return reduced
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
    for (const animation of this.host.root.getAnimations?.({ subtree: true }) ?? []) {
      if (Number.isFinite(animation.effect?.getComputedTiming().endTime)) animation.finish()
    }
  }

  private refuse(result: OpeningRefusal): void {
    const { host } = this
    settle(host.canister()?.move)
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
    animate(parts?.capTop, capTopKeyframes(), {
      duration: CAPS_MS,
      easing: "cubic-bezier(.12,.8,.3,1)",
      fill: "forwards",
    })
    animate(parts?.capBottom, capBottomKeyframes(), {
      duration: CAPS_MS,
      easing: "cubic-bezier(.12,.8,.3,1)",
      fill: "forwards",
    })
    animate(parts?.body, bodyKeyframes(), { duration: BODY_MS, easing: "cubic-bezier(.5,0,1,.6)", fill: "forwards" })
    animate(parts?.rays, fadeKeyframes(1, 0), { duration: RAYS_FADE_MS, fill: "forwards" })
    blast(host.fx(), parts?.button)
    stageFlash(host.flash(), "warm", 0.35, FLASH_MS)
    stageShake(host.shake(), 5, SHAKE_MS)
    await this.pause(HEAD_DELAY)
    host.apply(resultHeadShown)

    const origin = host.canister()?.button?.getBoundingClientRect()
    const phone = host.phoneLayout()
    const stagger = phone ? PHONE_DEAL_STAGGER : DEAL_STAGGER
    host.apply(cardsDealt)
    let end = 0
    ;(phone ? pileOrder(count) : dealOrder(count)).forEach((index, position) => {
      const delay = position * stagger
      this.tapWhenDealt(index, delay)
      const slot = host.slot(index)
      const travel = host.part(index, "travel")
      if (!slot || !travel || !origin) return
      const rect = slot.querySelector(".booster-card__frame")?.getBoundingClientRect() ?? slot.getBoundingClientRect()
      const dx = origin.left + origin.width / 2 - (rect.left + rect.width / 2)
      const dy = origin.top + origin.height / 2 - (rect.top + rect.height / 2)
      const rest = phone ? pilePose(pileDepth(index, host.current().stored)) : undefined
      animate(travel, dealKeyframes(dx, dy, dealRotation(index, count), rest), {
        duration: DEAL_MS,
        delay,
        fill: "backwards",
        easing: "linear",
      })
      this.laterInThisDeal(delay + DEAL_MS * DEAL_LAND_AT, () => stageShake(host.shake(), 1.5, LAND_SHAKE_MS))
      end = Math.max(end, delay + DEAL_MS)
    })
    await this.pause(end)
  }

  private tapWhenDealt(index: number, delay: number): void {
    this.laterInThisDeal(delay, () => dispatchGameble("gameble:card-dealt", { index }))
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
      this.tapWhenDealt(index, index * RM_FADE_STAGGER)
      animate(host.part(index, "travel"), fadeKeyframes(0, 1), {
        duration: RM_CARD_FADE,
        delay: index * RM_FADE_STAGGER,
        fill: "backwards",
      })
    }
    await this.pause(Math.max(RM_CANISTER_FADE, RM_CARD_FADE + (count - 1) * RM_FADE_STAGGER))
  }
}
