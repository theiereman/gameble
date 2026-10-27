import { arming, cardsDealt, ejecting, lock, openingAnswered, openingEnded, openingRefused, openingStarted, resultHeadShown, retracted, retracting, unlock, type OpeningRefusal } from "./booster"
import { animate, blast, settle, stageFlash, stageShake } from "./booster_effects"
import type { BoosterStageHost } from "./booster_host"
import { armKeyframes, bodyKeyframes, capBottomKeyframes, capTopKeyframes, dockKeyframes, fadeKeyframes, sinkKeyframes } from "./booster_keyframes"
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
import { sendOpening, type OpeningAnswer } from "./opening"

export type OpeningSequenceHost = BoosterStageHost &
  Readonly<{
    openUrl: string
    failedMessage: string
    refusedTitle: string
    keepFaces: (answer: OpeningAnswer) => void
    refreshBank: () => Promise<void>
  }>

export class OpeningSequence {
  constructor(private readonly host: OpeningSequenceHost) {}

  async open(): Promise<void> {
    const { host } = this
    const before = host.current()
    if (host.apply(openingStarted) === before) return
    host.apply(lock)
    if (before.phase === "dealt") await this.retract()
    rememberPack(null)

    const key = host.current().pendingKey ?? newKey()
    host.apply((s) => arming(s, key))
    const reduced = motionReduced()
    if (!reduced) animate(host.canister()?.move, armKeyframes(), { duration: ARM_MS, fill: "forwards" })
    const [result] = await Promise.all([sendOpening({ url: host.openUrl, key, csrfToken: csrfToken() }), host.timers().wait(reduced ? 0 : ARM_MS)])
    if (host.timers().disposed) return
    if (result.kind !== "opened") {
      this.refuse(result)
      return
    }

    const answer = result.answer
    host.keepFaces(answer)
    host.apply((s) => openingAnswered(s, answer))

    if (motionReduced()) await this.fadeAndDeal(answer.cards.length)
    else await this.blowAndDeal(answer.cards.length)

    host.apply(openingEnded)
    host.apply(unlock)
  }

  private refuse(result: OpeningRefusal): void {
    const { host } = this
    settle(host.canister()?.move)
    const message = host.apply((s) => openingRefused(s, result, host.failedMessage)).reason ?? host.failedMessage
    host.announce(message)
    dispatchGameble("gameble:toast", { title: host.refusedTitle, message, tone: "alert" })
    host.apply(unlock)
    if (result.kind === "refused") void host.refreshBank()
  }

  private async retract(): Promise<void> {
    const { host } = this
    const { wait } = host.timers()
    const count = host.current().answer?.cards.length ?? 0
    host.apply(retracting)
    if (!motionReduced()) {
      for (let index = 0; index < count; index++) {
        const travel = host.part(index, "travel")
        const from = host.phoneLayout() ? pileTransform(pileDepth(index, host.current().stored)) : pose()
        settle(travel)
        animate(travel, sinkKeyframes(from), { duration: SINK, delay: index * SINK_STAGGER, easing: "cubic-bezier(.5,0,.8,.4)", fill: "forwards" })
      }
      await wait(SINK + (count - 1) * SINK_STAGGER)
    }
    host.apply(retracted)
    if (!motionReduced()) {
      animate(host.canister()?.wrap, dockKeyframes(), { duration: DOCK, easing: "cubic-bezier(.2,.9,.3,1)", fill: "none" })
      await wait(DOCK)
    }
  }

  private async blowAndDeal(count: number): Promise<void> {
    const { host } = this
    const { wait, later } = host.timers()
    const parts = host.canister()
    host.apply(ejecting)
    animate(parts?.capTop, capTopKeyframes(), { duration: CAPS_MS, easing: "cubic-bezier(.12,.8,.3,1)", fill: "forwards" })
    animate(parts?.capBottom, capBottomKeyframes(), { duration: CAPS_MS, easing: "cubic-bezier(.12,.8,.3,1)", fill: "forwards" })
    animate(parts?.body, bodyKeyframes(), { duration: BODY_MS, easing: "cubic-bezier(.5,0,1,.6)", fill: "forwards" })
    animate(parts?.rays, fadeKeyframes(1, 0), { duration: RAYS_FADE_MS, fill: "forwards" })
    blast(host.fx(), parts?.button)
    stageFlash(host.flash(), "warm", 0.35, FLASH_MS)
    stageShake(host.shake(), 5, SHAKE_MS)
    await wait(HEAD_DELAY)
    host.apply(resultHeadShown)

    const origin = host.canister()?.button?.getBoundingClientRect()
    const phone = host.phoneLayout()
    const stagger = phone ? PHONE_DEAL_STAGGER : DEAL_STAGGER
    host.apply(cardsDealt)
    let end = 0
    ;(phone ? pileOrder(count) : dealOrder(count)).forEach((index, position) => {
      const slot = host.slot(index)
      const travel = host.part(index, "travel")
      if (!slot || !travel || !origin) return
      const rect = slot.querySelector(".booster-card__frame")?.getBoundingClientRect() ?? slot.getBoundingClientRect()
      const dx = origin.left + origin.width / 2 - (rect.left + rect.width / 2)
      const dy = origin.top + origin.height / 2 - (rect.top + rect.height / 2)
      const delay = position * stagger
      const rest = phone ? pilePose(pileDepth(index, host.current().stored)) : undefined
      animate(travel, dealKeyframes(dx, dy, dealRotation(index, count), rest), { duration: DEAL_MS, delay, fill: "backwards", easing: "linear" })
      later(delay + DEAL_MS * DEAL_LAND_AT, () => stageShake(host.shake(), 1.5, LAND_SHAKE_MS))
      end = Math.max(end, delay + DEAL_MS)
    })
    await wait(end)
  }

  private async fadeAndDeal(count: number): Promise<void> {
    const { host } = this
    animate(host.canister()?.wrap, fadeKeyframes(1, 0), { duration: RM_CANISTER_FADE, fill: "forwards" })
    host.apply(resultHeadShown)
    host.apply(cardsDealt)
    for (let index = 0; index < count; index++) {
      animate(host.part(index, "travel"), fadeKeyframes(0, 1), { duration: RM_CARD_FADE, delay: index * RM_FADE_STAGGER, fill: "backwards" })
    }
    await host.timers().wait(Math.max(RM_CANISTER_FADE, RM_CARD_FADE + (count - 1) * RM_FADE_STAGGER))
  }
}
