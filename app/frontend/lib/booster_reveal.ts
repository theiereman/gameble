import { bannerShown, legendaryEnded, legendarySignalled, lock, revealEnded, revealMarked, revealStarted, unlock } from "./booster"
import { animate, burst, ring, settle, stageFlash, stageShake } from "./booster_effects"
import type { BoosterStageHost } from "./booster_host"
import { fadeKeyframes, flipKeyframes, legendaryDropKeyframes, legendaryImpactKeyframes, legendaryJumpKeyframes, legendarySpinKeyframes, liftKeyframes, settleKeyframes, trembleKeyframes } from "./booster_keyframes"
import {
  ART_POLL,
  ART_WAIT_MAX,
  COMMON_LIFT_MS,
  COMMON_LIFT_PX,
  DROP,
  EPIC_SHAKE_MS,
  FLIP_MS,
  IMPACT,
  IMPACT_AT,
  LEGENDARY_FLASH_MS,
  LEGENDARY_JUMP,
  LEGENDARY_JUMP_PX,
  LEGENDARY_SHAKE_MS,
  LIFT_PX,
  MARK_AT,
  MARK_IN_SPIN,
  RINGS,
  RM_LEGENDARY_STILL,
  RM_REVEAL_FADE,
  SETTLE_MS,
  SPIN,
  TREMBLE_MS,
  phoneJump,
  phoneSwell,
  scaled,
  tierIndex,
} from "./booster_motion"
import type { Rarity } from "./card_types"
import { dispatchGameble } from "./events"
import { t } from "./i18n"
import { motionReduced } from "./motion"

export type RevealHost = BoosterStageHost &
  Readonly<{
    legendarySignal: string
    announceCardLine: string
    bannerLine: string
    rarityNames: () => Record<Rarity, string>
  }>

export class RevealSequence {
  constructor(private readonly host: RevealHost) {}

  async reveal(index: number, fromAll: boolean, { awaitArt = true } = {}): Promise<void> {
    const { host } = this
    const before = host.current()
    const card = before.answer?.cards[index]
    if (!card || host.apply((s) => revealStarted(s, index, fromAll)) === before) return
    host.apply(lock)
    if (awaitArt) await this.artReady(index)
    if (host.timers().disposed) return
    if (motionReduced()) await this.revealStill(index, card.tier, fromAll)
    else if (card.tier === "legendary") await this.revealLegendary(index, fromAll)
    else await this.revealTier(index, card.tier, fromAll)
    host.apply((s) => revealEnded(s, index, fromAll))
    host.apply(unlock)
  }

  private async artReady(index: number): Promise<void> {
    const { host } = this
    const started = performance.now()
    while (!host.slot(index)?.querySelector(".booster-card__front .card__art[data-art]") && performance.now() - started < ART_WAIT_MAX) {
      await host.timers().wait(ART_POLL)
    }
  }

  private mark(index: number, quiet: boolean): void {
    const { host } = this
    const before = host.current()
    const after = host.apply((s) => revealMarked(s, index, performance.now()))
    const card = after.answer?.cards[index]
    if (after === before || !card || !after.counts) return
    dispatchGameble("gameble:tier-revealed", { tier: card.tier, counts: after.counts })
    if (!quiet) host.announce(t(host.announceCardLine, { position: index + 1, card: card.label, rarity: host.rarityNames()[card.tier] }))
  }

  private bannerFor(index: number): string | null {
    const card = this.host.current().answer?.cards[index]
    return card ? t(this.host.bannerLine, { title: card.title, year: card.year ?? "" }) : null
  }

  private riseLimit(index: number): number {
    const { host } = this
    if (!host.phoneLayout()) return LEGENDARY_JUMP_PX
    const frame = host.slot(index)?.querySelector(".booster-card__frame")
    const stage = host.shake()
    if (!frame || !stage) return 0
    return phoneJump(frame.getBoundingClientRect().top - stage.getBoundingClientRect().top)
  }

  private swell(): (scale: number) => number {
    return (scale) => (this.host.phoneLayout() ? phoneSwell(scale) : scale)
  }

  private showBanner(tier: Rarity, large: boolean, line: string | null): void {
    this.host.apply((s) => bannerShown(s, { tier, large, line, reduced: motionReduced() }))
  }

  private async revealTier(index: number, tier: Rarity, quiet: boolean): Promise<void> {
    const { host } = this
    const { wait } = host.timers()
    const level = tierIndex(tier)
    const lift = host.part(index, "lift")
    const flip = host.part(index, "flip")
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
    if (level >= 3) stageShake(host.shake(), 5, EPIC_SHAKE_MS)
    const fx = host.part(index, "fx")
    burst(fx, tier)
    if (fx) {
      const { width, height: boxHeight } = fx.getBoundingClientRect()
      for (let count = 0; count < RINGS[level]; count++) {
        ring(fx, `booster-fx__ring booster-fx__ring--${count % 2 === 0 ? "tier" : "white"}`, width / 2, boxHeight / 2 - height, 110 + level * 30, scaled(count * 90))
      }
    }
    if (level === 3) this.showBanner(tier, false, null)
    settle(lift)
    animate(lift, settleKeyframes(height, swell), { duration: SETTLE_MS[level], easing: "cubic-bezier(.2,.8,.3,1)", fill: "none" })
    await wait(SETTLE_MS[level])
  }

  private async revealLegendary(index: number, quiet: boolean): Promise<void> {
    const { host } = this
    const { wait, later } = host.timers()
    const lift = host.part(index, "lift")
    const flip = host.part(index, "flip")
    const rise = this.riseLimit(index)
    const swell = this.swell()
    host.apply((s) => legendarySignalled(s, index))
    host.announce(host.legendarySignal)

    settle(lift)
    animate(lift, legendaryJumpKeyframes(rise, swell), { duration: LEGENDARY_JUMP, fill: "forwards" })
    await wait(LEGENDARY_JUMP)

    animate(flip, legendarySpinKeyframes(), { duration: SPIN, easing: "cubic-bezier(.2,.6,.3,1)", fill: "none" })
    later(MARK_IN_SPIN, () => this.mark(index, quiet))
    await wait(IMPACT_AT)

    settle(lift)
    animate(lift, legendaryImpactKeyframes(rise, swell), { duration: scaled(360), easing: "ease-out", fill: "forwards" })
    const fx = host.part(index, "fx")
    burst(fx, "legendary")
    if (fx && !motionReduced()) {
      const { width, height } = fx.getBoundingClientRect()
      ;[0, 100, 200].forEach((delay, count) =>
        ring(fx, `booster-fx__ring booster-fx__ring--${count % 2 === 0 ? "tier" : "white"}`, width / 2, height / 2 - rise, 200 + count * 60, scaled(delay)),
      )
    }
    stageFlash(host.flash(), "gold", 0.5, LEGENDARY_FLASH_MS)
    stageShake(host.shake(), 8, LEGENDARY_SHAKE_MS)
    this.showBanner("legendary", true, this.bannerFor(index))
    await wait(IMPACT)

    host.apply(legendaryEnded)
    settle(lift)
    animate(lift, legendaryDropKeyframes(rise, swell), { duration: DROP, easing: "cubic-bezier(.3,1.5,.5,1)", fill: "none" })
    later(scaled(300), () => stageShake(host.shake(), 2, scaled(120)))
    await wait(DROP)
  }

  private async revealStill(index: number, tier: Rarity, quiet: boolean): Promise<void> {
    const { host } = this
    const legendary = tier === "legendary"
    if (legendary) {
      host.apply((s) => legendarySignalled(s, null))
      host.announce(host.legendarySignal)
    }
    this.mark(index, quiet)
    animate(host.part(index, "lift"), fadeKeyframes(0.2, 1), { duration: RM_REVEAL_FADE, fill: "none" })
    if (legendary) {
      this.showBanner("legendary", true, this.bannerFor(index))
      await host.timers().wait(RM_LEGENDARY_STILL)
      host.apply(legendaryEnded)
    } else {
      await host.timers().wait(RM_REVEAL_FADE)
    }
  }
}
