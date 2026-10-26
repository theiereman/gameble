import { Controller } from "@hotwired/stimulus"
import type { Rarity } from "../lib/card_types"
import { swipeStep } from "../lib/swipe"

export type ZoomView = Readonly<{
  index: number
  tier: Rarity
  title: string
  line: string
  href: string
  repostName: string
  previous: boolean
  next: boolean
}>

export type ZoomFragments = Readonly<{
  face: (index: number) => DocumentFragment | null
  icon: (tier: Rarity) => DocumentFragment | null
}>

type Gesture = { id: number; x: number; y: number; tilted: boolean }

const RAYS_TIERS: readonly Rarity[] = ["epic", "legendary"]

const opensElsewhere = (event: MouseEvent): boolean => event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey

export default class BoosterZoomController extends Controller<HTMLDialogElement> {
  static targets = ["previous", "next", "rays", "face", "title", "icon", "line", "see", "repost", "status"]

  declare readonly previousTarget: HTMLButtonElement
  declare readonly nextTarget: HTMLButtonElement
  declare readonly raysTarget: HTMLElement
  declare readonly faceTarget: HTMLElement
  declare readonly titleTarget: HTMLElement
  declare readonly iconTarget: HTMLElement
  declare readonly lineTarget: HTMLElement
  declare readonly seeTarget: HTMLAnchorElement
  declare readonly hasRepostTarget: boolean
  declare readonly repostTarget: HTMLButtonElement
  declare readonly hasStatusTarget: boolean
  declare readonly statusTarget: HTMLElement

  private shown: ZoomView | null = null
  private showingNow: object | null = null
  private quiet = false
  private gesture: Gesture | null = null

  disconnect(): void {
    this.hide()
  }

  render(view: ZoomView | null, fragments: ZoomFragments): void {
    if (view === null) {
      this.hide()
      return
    }
    const before = this.shown
    const opening = before === null
    if (opening || before?.index !== view.index) this.fill(view, fragments)
    this.previousTarget.disabled = !view.previous
    this.nextTarget.disabled = !view.next
    this.shown = view

    if (opening) {
      this.showingNow = {}
      if (this.hasStatusTarget) this.statusTarget.textContent = ""
      if (typeof this.element.showModal === "function" && !this.element.open) this.element.showModal()
      this.seeTarget.focus()
    } else if (before?.previous !== view.previous || before?.next !== view.next) {
      this.keepFocusInside()
    }
  }

  get showing(): object | null {
    return this.showingNow
  }

  showStatus(message: string, showing: object | null): void {
    if (this.hasStatusTarget && showing !== null && showing === this.showingNow) this.statusTarget.textContent = message
  }

  previous(): void {
    this.dispatch("step", { detail: { step: -1 } })
  }

  next(): void {
    this.dispatch("step", { detail: { step: 1 } })
  }

  see(event: MouseEvent): void {
    if (opensElsewhere(event)) return
    const asked = this.dispatch("see", { cancelable: true })
    if (asked.defaultPrevented) event.preventDefault()
  }

  repost(): void {
    this.dispatch("repost")
  }

  scrim(event: MouseEvent): void {
    if (event.target === this.element) this.shut()
  }

  shut(): void {
    if (this.element.open) this.element.close()
  }

  closed(): void {
    this.shown = null
    this.showingNow = null
    if (this.quiet) {
      this.quiet = false
      return
    }
    this.dispatch("close")
  }

  press(event: PointerEvent): void {
    if (event.pointerType !== "touch" || !event.isPrimary) return
    this.gesture = { id: event.pointerId, x: event.clientX, y: event.clientY, tilted: false }
  }

  drag(event: PointerEvent): void {
    const gesture = this.gesture
    if (gesture && gesture.id === event.pointerId && (event.currentTarget as Element).querySelector("[data-tilting]")) gesture.tilted = true
  }

  release(event: PointerEvent): void {
    const gesture = this.gesture
    this.gesture = null
    if (!gesture || gesture.id !== event.pointerId || gesture.tilted || !this.shown) return
    const step = swipeStep(event.clientX - gesture.x, event.clientY - gesture.y)
    if (step !== 0 && (step > 0 ? this.shown.next : this.shown.previous)) this.dispatch("step", { detail: { step } })
  }

  cancel(): void {
    this.gesture = null
  }

  private hide(): void {
    this.shown = null
    this.showingNow = null
    if (!this.element.open) return
    this.quiet = true
    this.element.close()
  }

  private fill({ index, tier, title, line, href, repostName }: ZoomView, fragments: ZoomFragments): void {
    this.element.dataset.tier = tier
    const rays = RAYS_TIERS.includes(tier)
    this.raysTarget.hidden = !rays
    this.raysTarget.className = rays ? `card-rays card-rays--${tier} card-rays--large booster-zoom__rays` : "card-rays card-rays--large booster-zoom__rays"
    this.faceTarget.replaceChildren(fragments.face(index) ?? "")
    this.titleTarget.textContent = title
    this.iconTarget.replaceChildren(fragments.icon(tier) ?? "")
    this.lineTarget.textContent = line
    this.seeTarget.href = href
    if (this.hasRepostTarget) this.repostTarget.setAttribute("aria-label", repostName)
  }

  private keepFocusInside(): void {
    const focused = document.activeElement
    if (!this.element.open) return
    if (!this.element.contains(focused) || (focused instanceof HTMLButtonElement && focused.disabled)) this.seeTarget.focus()
  }
}
