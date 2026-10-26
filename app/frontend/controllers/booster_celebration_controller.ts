import { Controller } from "@hotwired/stimulus"
import { isRank, notchCount, sparkOffsets, type GaugeTick, type Juice } from "../lib/celebration"
import type { SetTierName } from "../lib/opening"

export type ResultView = Readonly<{
  url: string
  tier: SetTierName
  label: string
  title: string
  name: string
  before: string
  owned: string
  rest: string
  position: number
  from: number
  to: number
  juice: Juice
  ticks: readonly GaugeTick[]
}>

export type FoldedView = Readonly<{
  label: string
  title: string
  marks: readonly { tier: SetTierName; lightAt: number }[]
  lead: string
  set: string
  tier: string
}>

export type CelebrationView = Readonly<{
  identity: object
  steps: number
  still: boolean
  results: readonly ResultView[]
  folded: FoldedView | null
  position: string | null
}>

const TICK_SPARK_RADIUS = 22
const END_SPARK_RADIUS = 34
const RIBBON_SPARK_RADIUS = 30

const ms = (value: number): string => `${value}ms`

export default class BoosterCelebrationController extends Controller<HTMLElement> {
  static targets = ["list", "item", "step", "result", "folded", "tick", "mark", "notches", "sparks", "stamp", "check", "rank"]
  static values = { phone: Boolean }

  declare readonly listTarget: HTMLTemplateElement
  declare readonly itemTarget: HTMLTemplateElement
  declare readonly stepTarget: HTMLTemplateElement
  declare readonly resultTarget: HTMLTemplateElement
  declare readonly foldedTarget: HTMLTemplateElement
  declare readonly tickTarget: HTMLTemplateElement
  declare readonly markTarget: HTMLTemplateElement
  declare readonly notchesTarget: HTMLTemplateElement
  declare readonly sparksTarget: HTMLTemplateElement
  declare readonly stampTarget: HTMLTemplateElement
  declare readonly checkTarget: HTMLTemplateElement
  declare readonly rankTargets: HTMLTemplateElement[]
  declare readonly phoneValue: boolean

  private shown: CelebrationView | null = null
  private container: HTMLElement | null = null

  get phone(): boolean {
    return this.phoneValue
  }

  render(view: CelebrationView | null): void {
    const before = this.shown
    if (view === null) {
      this.clear()
      return
    }
    if (before && before.identity === view.identity) {
      if (before.steps !== view.steps) this.showStep(view)
      this.container?.toggleAttribute("data-still", view.still)
      this.shown = view
      return
    }
    this.clear()
    this.shown = view
    this.container = this.build(view)
    this.element.append(this.container)
  }

  leave(event: MouseEvent): void {
    if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return
    this.dispatch("leave")
  }

  step(): void {
    this.dispatch("step")
  }

  private showStep(view: CelebrationView): void {
    const [shown] = view.results
    const banner = this.container?.querySelector(".booster-celebration__banner")
    if (shown && banner) banner.replaceWith(this.resultBanner(shown))
    const position = this.container?.querySelector(".booster-celebration__position")
    if (position) position.textContent = view.position ?? ""
  }

  private clear(): void {
    this.container?.remove()
    this.container = null
    this.shown = null
  }

  private clone<T extends Element = HTMLElement>(template: HTMLTemplateElement): T {
    return (template.content.cloneNode(true) as DocumentFragment).firstElementChild as T
  }

  private build(view: CelebrationView): HTMLElement {
    const list = this.clone(this.listTarget)
    list.toggleAttribute("data-still", view.still)
    if (!this.phoneValue) {
      const banners = view.folded ? [this.foldedBanner(view.folded)] : view.results.map((result) => this.resultBanner(result))
      for (const banner of banners) {
        const item = this.clone(this.itemTarget)
        item.append(banner)
        list.append(item)
      }
      return list
    }
    const [shown] = view.results
    list.append(view.folded ? this.foldedBanner(view.folded) : this.resultBanner(shown))
    if (view.position !== null) {
      const step = this.clone(this.stepTarget)
      const position = step.querySelector(".booster-celebration__position")
      if (position) position.textContent = view.position
      list.append(step)
    }
    return list
  }

  private resultBanner(result: ResultView): HTMLElement {
    const banner = this.clone<HTMLAnchorElement>(this.resultTarget)
    const complete = result.tier === "complete"
    banner.href = result.url
    banner.dataset.tier = result.tier
    banner.setAttribute("aria-label", result.label)
    banner.style.setProperty("--i", String(result.position))
    banner.style.setProperty("--from", String(result.from))
    banner.style.setProperty("--to", String(result.to))

    this.fillHead(banner, result.title, complete ? this.clone(this.checkTarget) : this.tierMark(result.tier), result.juice.glosses, result.juice.ribbonSparks, result.juice.glints)

    this.write(banner, "set-name", result.name)
    if (!complete) banner.querySelector(".booster-celebration__name .booster-celebration__stamp")?.remove()
    this.write(banner, "before", result.before)
    this.write(banner, "owned", result.owned)
    this.write(banner, "total", result.rest)

    const gauge = banner.querySelector(".booster-celebration__gauge")!
    if (complete) {
      const end = gauge.querySelector(".booster-celebration__end")
      const sparks = this.sparks(result.juice.endSparks, END_SPARK_RADIUS)
      if (end && sparks) end.append(sparks)
    } else {
      gauge.querySelectorAll(".booster-celebration__lime, .booster-celebration__glow, .booster-celebration__end").forEach((part) => part.remove())
    }
    for (const tick of result.ticks) gauge.append(this.tick(tick, result))
    return banner
  }

  private foldedBanner(folded: FoldedView): HTMLElement {
    const banner = this.clone<HTMLAnchorElement>(this.foldedTarget)
    banner.setAttribute("aria-label", folded.label)
    banner.style.setProperty("--i", "0")
    this.fillHead(banner, folded.title, null, 0, 0, false)
    const marks = banner.querySelector(".booster-celebration__marks")
    for (const { tier, lightAt } of folded.marks) {
      const mark = this.clone(this.markTarget)
      mark.dataset.tier = tier
      mark.style.setProperty("--light", ms(lightAt))
      mark.append(tier === "complete" ? this.clone(this.stampTarget) : this.tierMark(tier))
      marks?.append(mark)
    }
    const set = banner.querySelector(".booster-celebration__set")
    if (set) {
      set.textContent = folded.set
      set.before(`${folded.lead} `)
      set.after(` ${folded.tier}`)
    }
    return banner
  }

  private write(banner: Element, part: string, text: string): void {
    const element = banner.querySelector(`.booster-celebration__${part}`)
    if (element) element.textContent = text
  }

  private fillHead(banner: HTMLElement, title: string, lead: Element | null, glosses: number, sparks: number, glints: boolean): void {
    const ribbon = banner.querySelector(".booster-celebration__ribbon")
    const words = ribbon?.firstElementChild
    if (words) words.textContent = title
    if (lead) ribbon?.prepend(lead)
    for (let gloss = 0; gloss < glosses; gloss++) {
      const shine = document.createElement("i")
      shine.className = "booster-celebration__gloss"
      ribbon?.append(shine)
    }
    const spark = this.sparks(sparks, RIBBON_SPARK_RADIUS)
    if (spark) banner.querySelector(".booster-celebration__fold")?.after(spark)
    if (!glints) banner.querySelector(".booster-celebration__glints")?.remove()
  }

  private tick(tick: GaugeTick, result: ResultView): HTMLElement {
    const element = this.clone(this.tickTarget)
    element.dataset.tier = tick.tier
    element.dataset.state = tick.state
    element.style.setProperty("--at", String(tick.at))
    if (tick.lightAt !== null) element.style.setProperty("--light", ms(tick.lightAt))
    if (!this.phoneValue) element.append(this.tierMark(tick.tier))
    if (tick.tier === result.tier) {
      const sparks = this.sparks(result.juice.tickSparks, TICK_SPARK_RADIUS)
      if (sparks) element.append(sparks)
    }
    return element
  }

  private tierMark(tier: SetTierName): HTMLElement {
    if (isRank(tier)) {
      const rank = this.rankTargets.find((template) => template.dataset.rank === tier)
      if (rank) return this.clone(rank)
    }
    const notches = this.clone(this.notchesTarget)
    for (let notch = 0; notch < notchCount(tier); notch++) notches.append(document.createElement("i"))
    return notches
  }

  private sparks(count: number, radius: number): HTMLElement | null {
    if (count === 0) return null
    const host = this.clone(this.sparksTarget)
    for (const { dx, dy, k } of sparkOffsets(count, radius)) {
      const spark = document.createElement("i")
      spark.style.setProperty("--dx", `${dx}px`)
      spark.style.setProperty("--dy", `${dy}px`)
      spark.style.setProperty("--k", String(k))
      host.append(spark)
    }
    return host
  }
}
