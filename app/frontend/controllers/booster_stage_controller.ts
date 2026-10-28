import { Controller } from "@hotwired/stimulus"
import { animate } from "../lib/booster_effects"
import { cardBackClass, cardBackProperties, pilePose } from "../lib/booster_motion"
import { CardSwipe, dragTransform, type SwipeRelease } from "../lib/booster_swipe"
import { writeData, writeText } from "../lib/dom_writes"
import { BANNER_TIERS, type Fragments } from "../lib/screen"
import { cloneTemplate } from "../lib/templates"
import type { Rarity } from "../lib/card_types"
import type { CardBackView } from "../lib/opening"

export type CardView = Readonly<{
  index: number
  tier: Rarity
  revealed: boolean
  revealedAt: number | undefined
  legendary: boolean
  name: string
  tierLabel: string
  repostName: string
  depth: number | null
}>

export type HandView = Readonly<{
  key: string
  phone: boolean
  cardBack: CardBackView
  dealt: boolean
  cards: readonly CardView[]
}>

export type StageView = Readonly<{
  legendary: boolean
  headShown: boolean
  hand: HandView | null
  hint: string | null
}>

export type BannerView = Readonly<{
  tier: Rarity
  large: boolean
  name: string
  line: string | null
  keyframes: Keyframe[]
  duration: number
}>

export type CardIntent = { index: number }

export default class BoosterStageController extends Controller<HTMLElement> {
  static targets = ["shake", "fx", "flash", "result", "dealArea", "deal", "hint", "pileArea", "pile", "card", "banner"]

  declare readonly shakeTarget: HTMLElement
  declare readonly fxTarget: HTMLElement
  declare readonly flashTarget: HTMLElement
  declare readonly resultTarget: HTMLElement
  declare readonly dealAreaTarget: HTMLElement
  declare readonly dealTarget: HTMLOListElement
  declare readonly hintTarget: HTMLElement
  declare readonly pileAreaTarget: HTMLElement
  declare readonly pileTarget: HTMLOListElement
  declare readonly cardTarget: HTMLTemplateElement
  declare readonly bannerTarget: HTMLTemplateElement

  private handKey: string | null = null
  private slots = new Map<number, HTMLLIElement>()
  private bannerElement: HTMLElement | null = null
  private readonly swipe = new CardSwipe()

  disconnect(): void {
    this.swipe.forget()
  }

  get shake(): HTMLElement {
    return this.shakeTarget
  }

  get fx(): HTMLElement {
    return this.fxTarget
  }

  get flash(): HTMLElement {
    return this.flashTarget
  }

  get lastDragEnd(): number {
    return this.swipe.lastDragEnd
  }

  slot(index: number): HTMLLIElement | null {
    return this.slots.get(index) ?? null
  }

  part(index: number, name: string): HTMLElement | null {
    return this.slot(index)?.querySelector<HTMLElement>(`.booster-card__${name}`) ?? null
  }

  forgetGesture(): void {
    this.swipe.forget()
  }

  render({ legendary, headShown, hand, hint }: StageView, fragments: Fragments): void {
    this.element.toggleAttribute("data-legendary", legendary)
    this.resultTarget.toggleAttribute("data-shown", headShown)
    if (headShown) this.resultTarget.removeAttribute("aria-hidden")
    else this.resultTarget.setAttribute("aria-hidden", "true")

    this.dealAreaTarget.hidden = hand === null
    this.pileAreaTarget.hidden = hand === null
    this.hintTarget.hidden = hint === null
    if (hint !== null) writeText(this.hintTarget, hint)

    if ((hand?.key ?? null) !== this.handKey) this.deal(hand, fragments)
    if (hand) this.update(hand)
  }

  showBanner(
    { tier, large, name, line, keyframes, duration }: BannerView,
    icon: (tier: Rarity) => DocumentFragment | null,
  ): void {
    this.hideBanner()
    const banner = cloneTemplate(this.bannerTarget)
    if (!banner) return
    banner.classList.toggle("booster__banner--large", large)
    banner.dataset.tier = tier
    banner.querySelectorAll(".booster__banner-icon").forEach((host) => host.replaceChildren(icon(tier) ?? ""))
    banner.querySelector(".booster__banner-name")!.textContent = name
    const lineElement = banner.querySelector(".booster__banner-line")
    if (line === null) lineElement?.remove()
    else if (lineElement) lineElement.textContent = line
    this.flashTarget.before(banner)
    this.bannerElement = banner
    animate(banner, keyframes, { duration, fill: "none" })
  }

  hideBanner(): void {
    this.bannerElement?.remove()
    this.bannerElement = null
  }

  activate(event: MouseEvent): void {
    const target = event.target as Element | null
    const slot = target?.closest<HTMLLIElement>(".booster-card")
    if (!target || !slot) return
    const index = this.indexOf(slot)
    if (target.closest(".booster-card__repost")) {
      event.stopPropagation()
      if (slot.hasAttribute("data-revealed")) this.dispatch("repost", { detail: { index } satisfies CardIntent })
      return
    }
    event.preventDefault()
    this.dispatch("activate", { detail: { index } satisfies CardIntent })
  }

  press(event: PointerEvent): void {
    const slot = (event.target as Element | null)?.closest<HTMLLIElement>(".booster-card")
    if (!slot || !event.isPrimary || this.swipe.active) return
    const index = this.indexOf(slot)
    const asked = this.dispatch("press", { detail: { index } satisfies CardIntent })
    if (!asked.defaultPrevented) return
    this.swipe.press({ id: event.pointerId, x: event.clientX, y: event.clientY }, index, this.tilting(slot))
  }

  drag(event: PointerEvent): void {
    const index = this.swipe.index
    if (index === null) return
    const slot = this.slot(index)
    const float = this.part(index, "float")
    if (!slot || !float) return
    const move = this.swipe.move({ id: event.pointerId, x: event.clientX, y: event.clientY }, this.tilting(slot))
    if (move.kind === "none") return
    if (move.kind === "started") {
      float.getAnimations?.().forEach((animation) => animation.cancel())
      try {
        slot.setPointerCapture(event.pointerId)
      } catch {
        // A pointer the browser does not track (a synthetic one): no capture.
      }
    }
    float.style.transform = dragTransform(move.dx, move.dy)
  }

  lift(event: PointerEvent): void {
    this.release(event, false)
  }

  cancel(event: PointerEvent): void {
    this.release(event, true)
  }

  private release(event: PointerEvent, cancelled: boolean): void {
    const released = this.swipe.end(
      { id: event.pointerId, x: event.clientX, y: event.clientY },
      cancelled,
      performance.now(),
    )
    if (released) this.dispatch("release", { detail: released satisfies SwipeRelease })
  }

  private tilting(slot: Element): boolean {
    return slot.querySelector("[data-tilting]") !== null
  }

  private indexOf(slot: HTMLElement): number {
    return Number(slot.dataset.position) - 1
  }

  private deal(hand: HandView | null, fragments: Fragments): void {
    this.handKey = hand?.key ?? null
    this.slots.clear()
    this.swipe.forget()
    this.dealTarget.replaceChildren()
    this.pileTarget.replaceChildren()
    if (!hand) return
    const list = hand.phone ? this.pileTarget : this.dealTarget
    for (const card of hand.cards) {
      const slot = this.newSlot(card, hand, fragments)
      if (!slot) continue
      list.append(slot)
      this.slots.set(card.index, slot)
    }
  }

  private newSlot(card: CardView, hand: HandView, fragments: Fragments): HTMLLIElement | null {
    const slot = cloneTemplate<HTMLLIElement>(this.cardTarget)
    if (!slot) return null
    slot.dataset.position = String(card.index + 1)
    slot.dataset.tier = card.tier
    if (card.tier !== "legendary") slot.querySelector(".booster-card__glow")?.remove()
    const rays = slot.querySelector(".booster-card__rays")
    if (BANNER_TIERS.includes(card.tier)) rays?.classList.add(`card-rays--${card.tier}`)
    else rays?.remove()
    const back = slot.querySelector<HTMLElement>(".booster-card__back")
    back?.classList.add(cardBackClass(hand.cardBack))
    for (const [name, value] of cardBackProperties(hand.cardBack)) back?.style.setProperty(name, value)
    slot.querySelector(".booster-card__front")?.replaceChildren(fragments.face(card.index) ?? "")
    slot.querySelector(".booster-card__label-icon-box")?.replaceChildren(fragments.icon(card.tier) ?? "")
    const name = slot.querySelector(".booster-card__label-name")
    if (name) name.textContent = card.tierLabel
    const repost = slot.querySelector(".booster-card__repost")
    if (hand.phone) repost?.remove()
    else repost?.setAttribute("aria-label", card.repostName)
    return slot
  }

  private update(hand: HandView): void {
    const shown = new Set(hand.cards.map((card) => card.index))
    for (const [index, slot] of this.slots) {
      if (shown.has(index)) continue
      slot.remove()
      this.slots.delete(index)
    }
    for (const card of hand.cards) {
      const slot = this.slots.get(card.index)
      if (slot) this.updateSlot(slot, card, hand.dealt)
    }
  }

  private updateSlot(slot: HTMLLIElement, card: CardView, dealt: boolean): void {
    slot.toggleAttribute("data-dealt", dealt)
    slot.toggleAttribute("data-revealed", card.revealed)
    writeData(slot, "revealedAt", card.revealedAt === undefined ? null : String(card.revealedAt))
    slot.toggleAttribute("data-legendary", card.legendary)
    const top = card.depth === 0
    slot.toggleAttribute("data-top", top)
    writeData(slot, "depth", card.depth === null ? null : String(card.depth))
    slot.inert = card.depth !== null && !top
    if (card.depth === null) {
      for (const property of ["--pile-y", "--pile-scale", "--pile-rotate", "z-index"])
        slot.style.removeProperty(property)
    } else {
      const pose = pilePose(card.depth)
      slot.style.setProperty("--pile-y", `${pose.y}px`)
      slot.style.setProperty("--pile-scale", String(pose.scale))
      slot.style.setProperty("--pile-rotate", `${pose.rotate}deg`)
      slot.style.setProperty("z-index", String(20 - card.depth))
    }
    slot.querySelector(".booster-card__flip")?.classList.toggle("is-up", card.revealed)
    const hit = slot.querySelector(".booster-card__hit")
    if (hit && hit.getAttribute("aria-label") !== card.name) hit.setAttribute("aria-label", card.name)
  }
}
