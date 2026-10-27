import type { BoosterState } from "./booster"
import { cardHref, csrfToken, rememberPack, visit } from "./booster_page"
import { dispatchGameble } from "./events"
import { repostHref, sendRepost } from "./repost"

export type CardExitHost = Readonly<{
  state: () => BoosterState | undefined
  cardUrl: string
  repostUrl: string
  reposted: string
  repostFailed: string
}>

export class CardExit {
  constructor(private readonly host: CardExitHost) {}

  leaveFor(index: number): void {
    const answer = this.host.state()?.answer
    const card = answer?.cards[index]
    if (!answer || !card) return
    rememberPack(answer.pack.token)
    visit(cardHref(this.host.cardUrl, card.slug, answer.pack.token, index))
  }

  async repost(index: number): Promise<string> {
    const { host } = this
    const card = host.state()?.answer?.cards[index]
    if (!card || !host.repostUrl) return ""
    const result = await sendRepost({ url: repostHref(host.repostUrl, card.slug, card.season), csrfToken: csrfToken() })
    const message =
      result.kind === "reposted" ? host.reposted : result.kind === "refused" ? result.message : host.repostFailed
    dispatchGameble("gameble:toast", { message, tone: result.kind === "reposted" ? "notice" : "alert" })
    return message
  }
}
