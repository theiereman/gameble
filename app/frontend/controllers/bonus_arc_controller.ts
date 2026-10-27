import { Controller } from "@hotwired/stimulus"
import { dispatchGameble, type BankChangedDetail } from "../lib/events"
import { arcPoints, type Point } from "../lib/arc"
import { motionReduced } from "../lib/motion"

// The daily booster's arc: a canister flies from the panel to the packs chip (or the BOOSTER tab on a phone) and the count brightens.
// It listens to `turbo:before-stream-render` while both ends are in place, and starts only for a stream carrying `data-bonus-arc-collected`.
// Only transform and opacity move; a flight under way is cancelled on disconnect.
const ARC_MS = 480
const ARC_MS_PHONE = 520
const BUMP_MS = 600
const ICON_SIZE = 24
const PANEL = "#daily-booster"
const CHIP = "#packs-chip"
const BOOSTER_TAB = ".tab-bar a.tab-bar__tab[href*='/booster']"

type StreamElementLike = HTMLElement & { templateContent?: DocumentFragment }

const centre = (element: Element): Point => {
  const rect = element.getBoundingClientRect()
  return { x: rect.left + rect.width / 2, y: rect.top + rect.height / 2 }
}

const visible = (element: Element | null): element is HTMLElement => {
  if (!element) return false
  const rect = element.getBoundingClientRect()
  return rect.width > 0 && rect.height > 0 && getComputedStyle(element).visibility !== "hidden"
}

export default class extends Controller<HTMLElement> {
  private flyer?: HTMLElement
  private animation?: Animation
  private bumpTimer?: number

  disconnect(): void {
    this.animation?.cancel()
    this.animation = undefined
    this.flyer?.remove()
    this.flyer = undefined
    window.clearTimeout(this.bumpTimer)
  }

  render(event: Event): void {
    const stream = (event as CustomEvent<{ newStream?: StreamElementLike }>).detail?.newStream
    const marker = stream?.templateContent?.querySelector<HTMLElement>("[data-bonus-arc-collected]")
    if (!marker) return

    const bank = parseBank(marker.dataset.bonusArcBank)
    if (motionReduced()) {
      this.arrived(bank, false)
      return
    }

    const origin = visible(document.querySelector(`${PANEL} .button`)) ? document.querySelector(`${PANEL} .button`) : document.querySelector(PANEL)
    const tab = document.querySelector(BOOSTER_TAB)
    const destination = visible(tab) ? tab : document.querySelector(CHIP)
    const source = document.querySelector<SVGElement>(`${CHIP} .packs-chip__icon`)
    if (!origin || !visible(destination) || !source || typeof document.documentElement.animate !== "function") {
      this.arrived(bank, false)
      return
    }
    this.fly(centre(origin), centre(destination), source, visible(tab), bank)
  }

  private fly(from: Point, to: Point, icon: SVGElement, phone: boolean, bank: BankChangedDetail | undefined): void {
    this.animation?.cancel()
    this.flyer?.remove()
    const flyer = document.createElement("div")
    flyer.className = "bonus-arc"
    flyer.setAttribute("aria-hidden", "true")
    const clone = icon.cloneNode(true) as SVGElement
    clone.classList.add("bonus-arc__icon")
    flyer.append(clone)
    document.body.append(flyer)
    this.flyer = flyer

    const half = ICON_SIZE / 2
    const points = arcPoints(from, to)
    const frames: Keyframe[] = points.map((point, i) => ({
      offset: i / (points.length - 1),
      transform: `translate(${point.x - half}px, ${point.y - half}px) scale(${1.2 - 0.4 * (i / (points.length - 1))})`,
      opacity: i === 0 ? 0.6 : 1,
    }))
    const animation = flyer.animate(frames, { duration: phone ? ARC_MS_PHONE : ARC_MS, easing: "linear", fill: "both" })
    this.animation = animation
    const done = (): void => {
      if (this.animation !== animation) return
      this.animation = undefined
      flyer.remove()
      if (this.flyer === flyer) this.flyer = undefined
      this.arrived(bank, true)
    }
    animation.addEventListener("finish", done)
  }

  private arrived(bank: BankChangedDetail | undefined, bump: boolean): void {
    window.setTimeout(() => {
      if (bank) dispatchGameble("gameble:bank-changed", bank)
      if (!bump) return
      const count = document.querySelector<HTMLElement>(`${CHIP} .packs-chip__count`)
      if (!count) return
      count.classList.add("is-bumped")
      window.clearTimeout(this.bumpTimer)
      this.bumpTimer = window.setTimeout(() => count.classList.remove("is-bumped"), BUMP_MS)
    }, 0)
  }
}

function parseBank(raw: string | undefined): BankChangedDetail | undefined {
  if (!raw) return undefined
  try {
    const bank = JSON.parse(raw) as Partial<BankChangedDetail>
    if (typeof bank.available !== "number" || typeof bank.reserveFull !== "boolean" || typeof bank.serverTime !== "string") return undefined
    return { available: bank.available, reserveFull: bank.reserveFull, nextAvailableAt: bank.nextAvailableAt ?? null, serverTime: bank.serverTime }
  } catch {
    return undefined
  }
}
