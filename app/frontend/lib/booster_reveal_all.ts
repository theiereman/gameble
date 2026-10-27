import { canRevealAll, revealAllEnded, revealAllPlan, revealAllStarted } from "./booster"
import type { BoosterStageHost } from "./booster_host"
import { ART_POLL, REVEAL_ALL_GAP, phoneAllHold, revealSummary } from "./booster_motion"
import type { Rarity } from "./card_types"
import type { Template } from "./i18n"
import type { OpeningAnswer } from "./opening"

export type RevealAllHost = BoosterStageHost &
  Readonly<{
    summary: Template
    summaryTier: string
    delimiter: string
    rarityNames: () => Record<Rarity, string>
    reveal: (index: number, fromAll: boolean, options?: { awaitArt?: boolean }) => Promise<void>
    store: (index: number, fromAll: boolean) => Promise<void>
    whenIdle: () => void
  }>

export class RevealAll {
  constructor(private readonly host: RevealAllHost) {}

  async run(): Promise<void> {
    const { host } = this
    const before = host.current()
    const answer = before.answer
    if (!answer || !canRevealAll(before)) return
    if (before.layout === "phone") {
      await this.revealAndStore(answer)
      return
    }
    const plan = revealAllPlan(before)
    if (plan.length === 0) return
    host.apply(revealAllStarted)
    const running: Promise<void>[] = []
    for (const { index, wait: hold } of plan) {
      const done = host.reveal(index, true, { awaitArt: false })
      running.push(done)
      if (hold === "full") await done
      else await host.timers().wait(REVEAL_ALL_GAP)
    }
    await Promise.all(running)
    while (host.current().revealing.length > 0) await host.timers().wait(ART_POLL)
    host.apply(revealAllEnded)
    host.announce(this.summarize(plan.map(({ index }) => answer.cards[index].tier)))
    host.whenIdle()
  }

  private async revealAndStore(answer: OpeningAnswer): Promise<void> {
    const { host } = this
    host.apply(revealAllStarted)
    while (host.current().revealing.length > 0) await host.timers().wait(ART_POLL)
    const shown: Rarity[] = []
    for (let index = 0; index < answer.cards.length; index++) {
      if (host.timers().disposed || host.current().answer !== answer) return
      if (host.current().stored[index]) continue
      if (!host.current().revealed[index]) {
        await host.reveal(index, true)
        shown.push(answer.cards[index].tier)
      }
      await host.timers().wait(phoneAllHold(answer.cards[index].tier))
      await host.store(index, true)
    }
    host.apply(revealAllEnded)
    if (shown.length > 0) host.announce(this.summarize(shown))
    host.whenIdle()
  }

  private summarize(tiers: Rarity[]): string {
    const { summary, summaryTier, delimiter } = this.host
    return revealSummary(tiers, { summary, summaryTier, rarityNames: this.host.rarityNames(), delimiter })
  }
}
