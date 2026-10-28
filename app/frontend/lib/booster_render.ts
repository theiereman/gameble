import type { CardView, HandView } from "../controllers/booster_stage_controller"
import {
  bannerEnded,
  controls,
  onTable,
  shownCelebration,
  type BoosterState,
  type Controls,
  type Hint,
} from "./booster"
import { reserveCount } from "./booster_bank"
import { bannerKeyframes } from "./booster_keyframes"
import { bannerDuration, pileDepth } from "./booster_motion"
import { formatClock } from "./booster_clock"
import { cardHref } from "./booster_page"
import type { BoosterRenderHost } from "./booster_render_host"
import { renderCelebrations } from "./booster_render_celebration"
import { t } from "./i18n"
import { formatLocalTime } from "./local_time"
import type { OpeningCard } from "./opening"

type Clock = Readonly<{ clock: string; spoken: string }>

const localTime = (iso: string): string =>
  formatLocalTime(iso, "datetime", { locale: document.documentElement.lang }) ?? iso

export class BoosterRenderer {
  private bannerKey: number | null = null

  constructor(private readonly host: BoosterRenderHost) {}

  render(state: BoosterState): void {
    const { element } = this.host
    const view = controls(state)
    const phone = state.layout === "phone"
    element.dataset.layout = state.layout
    element.dataset.phase = state.phase
    element.dataset.status = state.status
    element.setAttribute("aria-labelledby", phone ? "booster-title" : "booster-panel-title")

    this.renderReserves(state)
    element.dataset.reserve = state.reserve
    this.renderOriginLook(state)
    this.renderInfo(state, view)
    this.renderActions(state, view)
    this.renderCanister(state)
    this.renderStage(state, view)
    this.renderBanner(state)
    this.renderPlate(state, view)
    this.renderTray(state, view)
    this.renderZoom(state, view)
    renderCelebrations(this.host, state, view)
  }

  private get strings() {
    return this.host.strings
  }

  private nextClock(): string | null {
    const left = this.host.left()
    return left === null ? null : formatClock(left)
  }

  private nextLine(state: BoosterState): Clock | null {
    const clock = this.nextClock()
    const { reserveFull, nextAvailableAt } = state.bank
    if (reserveFull || clock === null || !nextAvailableAt) return null
    return { clock, spoken: t(this.strings.nextAt, { time: localTime(nextAvailableAt) }) }
  }

  private nextSize(state: BoosterState): number {
    return state.bank.nextPackSize ?? this.host.packSize
  }

  private originKind(state: BoosterState): string | null {
    if (state.reserve !== "special") return null
    return (state.phase === "dealt" ? state.answer?.pack.kind : state.bank.nextSpecialKind) || null
  }

  private originName(state: BoosterState): string | null {
    const kind = this.originKind(state)
    const names: Record<string, string> = {
      bonus: this.strings.originBonus,
      reward: this.strings.originReward,
    }
    return (kind && names[kind]) || null
  }

  private renderOriginLook(state: BoosterState): void {
    const { element } = this.host
    const kind = this.originKind(state)
    if (kind) element.dataset.origin = kind
    else delete element.dataset.origin
  }

  private renderReserves(state: BoosterState): void {
    const { reserves } = this.host.outlets()
    if (!reserves) return
    const tab = (template: string, count: number) => ({
      label: t(template, { n: this.host.number(count) }),
      empty: count === 0,
    })
    reserves.render({
      selected: state.reserve,
      tabs: {
        standard: tab(this.strings.tabStandard, state.bank.available),
        special: tab(this.strings.tabSpecial, state.bank.special),
      },
    })
  }

  private renderInfo(state: BoosterState, view: Controls): void {
    const { reserveFull } = state.bank
    const special = state.reserve === "special"
    const available = reserveCount(state.bank, state.reserve)
    const origin = this.originName(state)
    const shownSize = state.answer?.cards.length || this.nextSize(state)
    const info = {
      lit: special ? 0 : available,
      size: this.host.number(shownSize),
      reserve: t(this.strings.reserveCount, { count: available, n: this.host.number(available) }),
      tone: view.tone,
      reserveFull: reserveFull && !special,
      next: special ? null : this.nextLine(state),
      origin: origin && (state.phase === "sealed" ? origin : t(this.strings.originOpening, { origin })),
    }
    for (const outlet of this.host.outlets().info) outlet.render(info)
  }

  private renderActions(state: BoosterState, view: Controls): void {
    const actions = this.host.outlets().actions
    if (!actions) return
    const host = state.layout === "phone" ? this.host.phoneActions : this.host.panelActions
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
    const canister = this.host.outlets().canister
    if (!canister) return
    const nextSize = this.nextSize(state)
    const clock = this.nextClock()
    const { nextAvailableAt } = state.bank
    const season = this.host.season
    canister.render({
      away: state.canisterAway,
      empty: state.phase === "empty",
      next:
        clock !== null && nextAvailableAt
          ? {
              clock: t(this.strings.emptyNext, { time: clock }),
              spoken: t(this.strings.nextAt, { time: localTime(nextAvailableAt) }),
            }
          : null,
      label:
        season > 0
          ? t(this.strings.canisterLabel, { season, count: nextSize })
          : t(this.strings.canisterLabelPlain, { count: nextSize }),
      busy: state.phase !== "sealed" && state.phase !== "dealt",
      armed: state.armed,
      hintHidden: state.phase !== "sealed",
      facts: t(this.strings.canisterFacts, { count: nextSize, n: this.host.number(nextSize) }),
      docks: state.docks,
      origin: this.originName(state),
    })
  }

  private hintText(hint: Hint): string {
    switch (hint.kind) {
      case "remaining":
        return t(this.strings.hintRemaining, { count: hint.count, n: this.host.number(hint.count) })
      case "done":
        return t(this.strings.hintDone, { count: hint.count, n: this.host.number(hint.count) })
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
    const rarityNames = this.host.rarityNames()
    const cardName = (card: OpeningCard, index: number): string =>
      state.revealed[index]
        ? t(phone ? this.strings.faceUpStore : this.strings.faceUp, {
            card: card.label,
            rarity: rarityNames[card.tier],
          })
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
        tierLabel: this.host.tierLabel(card.tier),
        repostName: t(this.strings.repostCard, { card: card.title }),
        depth: phone ? pileDepth(index, state.stored) : null,
      })
    })
    return {
      key: `${answer.pack.token}:${state.rebuilds}`,
      phone,
      cardBack: answer.pack.cardBack,
      dealt: state.dealt,
      cards: shown,
    }
  }

  private renderStage(state: BoosterState, view: Controls): void {
    const stage = this.host.outlets().stage
    if (!stage) return
    const phone = state.layout === "phone"
    stage.render(
      {
        legendary: state.legendary !== null,
        headShown: state.headShown,
        hand: this.hand(state),
        hint: !phone && view.hint ? this.hintText(view.hint) : null,
      },
      { face: this.host.face, icon: this.host.icon },
    )
  }

  private renderBanner(state: BoosterState): void {
    const stage = this.host.outlets().stage
    if (!stage) return
    const banner = state.layout === "phone" ? null : state.banner
    if ((banner?.key ?? null) === this.bannerKey) return
    this.bannerKey = banner?.key ?? null
    if (!banner) {
      stage.hideBanner()
      return
    }
    const duration = bannerDuration(banner)
    stage.showBanner(
      {
        tier: banner.tier,
        large: banner.large,
        name: banner.large ? this.host.tierLabel(banner.tier) : this.host.rarityNames()[banner.tier],
        line: banner.line,
        keyframes: bannerKeyframes(banner.reduced),
        duration,
      },
      this.host.icon,
    )
    const key = banner.key
    this.host.timers().later(duration, () => this.host.apply((s) => bannerEnded(s, key)))
  }

  private renderPlate(state: BoosterState, view: Controls): void {
    const plateOutlet = this.host.outlets().plate
    if (!plateOutlet) return
    const answer = state.answer
    const top = view.plate === null ? null : answer?.cards[view.plate]
    const hint = state.layout === "phone" ? view.hint : null
    plateOutlet.render(
      {
        shown: onTable(state),
        hint: hint && { kind: hint.kind === "remaining" ? "done" : hint.kind, done: this.hintText(hint) },
        plate:
          view.plate !== null && top
            ? {
                key: `${answer?.pack.token}-${view.plate}`,
                tier: top.tier,
                tierText: this.host.tierLabel(top.tier),
                line: t(this.strings.bannerLine, { title: top.title, year: top.year ?? "" }),
              }
            : null,
        celebrating: Boolean(shownCelebration(state)) && view.plate === null,
        busy: view.busy,
      },
      this.host.icon,
    )
  }

  private renderTray(state: BoosterState, view: Controls): void {
    const tray = this.host.outlets().tray
    if (!tray) return
    const answer = state.answer
    const cards = answer?.cards ?? []
    tray.render(
      {
        key: `${answer?.pack.token ?? ""}:${state.rebuilds}`,
        shown: onTable(state),
        count: t(this.strings.trayCount, {
          n: this.host.number(view.storedCount),
          total: this.host.number(cards.length),
        }),
        busy: view.busy,
        slots: cards.map((card, index) => ({
          tier: card.tier,
          coverUrl: card.coverUrl,
          name: t(this.strings.traySlot, { card: card.label, rarity: this.host.rarityNames()[card.tier] }),
          stored: state.stored[index] ?? false,
        })),
      },
      this.host.icon,
    )
  }

  private renderZoom(state: BoosterState, view: Controls): void {
    const zoomOutlet = this.host.outlets().zoom
    if (!zoomOutlet) return
    const { zoom, answer } = state
    const card = zoom !== null && state.layout === "phone" ? answer?.cards[zoom] : null
    zoomOutlet.render(
      card && zoom !== null && answer
        ? {
            index: zoom,
            tier: card.tier,
            title: card.title,
            line: t(this.strings.zoomLine, { rarity: this.host.rarityNames()[card.tier], year: card.year ?? "" }),
            href: cardHref(this.host.cardUrl, card.slug, answer.pack.token, zoom),
            repostName: t(this.strings.repostCard, { card: card.title }),
            previous: view.zoomPrevious,
            next: view.zoomNext,
          }
        : null,
      { face: (index) => this.host.faceFragment(index, "xl"), icon: this.host.icon },
    )
  }
}
