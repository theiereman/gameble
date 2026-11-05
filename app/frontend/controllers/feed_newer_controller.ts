import { Controller } from "@hotwired/stimulus"
import "../lib/turbo"
import { fetchStream, type StreamRender } from "../lib/next_page"
import { anchorShift, NEAR_START_MARGIN, newestAction, newestPillShown } from "../lib/feed_newer"

type StreamRenderDetail = { render: StreamRender<Element> }

const READER_INPUTS = ["wheel", "touchmove", "keydown"] as const

export default class extends Controller<HTMLElement> {
  static targets = ["pages", "newest"]
  static values = { live: Boolean }

  declare readonly hasPagesTarget: boolean
  declare readonly newestTarget: HTMLElement
  declare readonly hasNewestTarget: boolean
  declare readonly liveValue: boolean

  private observer?: IntersectionObserver
  private request?: AbortController
  private readerScrolled = false

  connect(): void {
    window.addEventListener("scroll", this.refreshPill, { passive: true })
    for (const input of READER_INPUTS) window.addEventListener(input, this.readerMoved, { passive: true })
  }

  disconnect(): void {
    window.removeEventListener("scroll", this.refreshPill)
    for (const input of READER_INPUTS) window.removeEventListener(input, this.readerMoved)
    this.request?.abort()
    this.request = undefined
    this.observer?.disconnect()
    this.observer = undefined
  }

  pagesTargetConnected(links: HTMLElement): void {
    this.observing().observe(links)
    this.refreshPill()
  }

  pagesTargetDisconnected(links: HTMLElement): void {
    this.observer?.unobserve(links)
    this.refreshPill()
  }

  newest(event: Event): void {
    if (newestAction(this.liveValue, this.hasPagesTarget) !== "scroll") return

    event.preventDefault()
    const smooth = !window.matchMedia("(prefers-reduced-motion: reduce)").matches
    window.scrollTo({ top: 0, behavior: smooth ? "smooth" : "auto" })
  }

  private readonly readerMoved = (): void => {
    this.readerScrolled = true
    this.refreshPill()
  }

  private readonly refreshPill = (): void => {
    if (!this.hasNewestTarget) return

    this.newestTarget.hidden = !newestPillShown({
      readerScrolled: this.readerScrolled,
      scrollY: window.scrollY,
      viewportHeight: window.innerHeight,
      newerLeft: this.hasPagesTarget,
    })
  }

  private observing(): IntersectionObserver {
    this.observer ??= new IntersectionObserver(
      (entries) => {
        for (const entry of entries) if (entry.isIntersecting) void this.loadNewer(entry.target)
      },
      { rootMargin: NEAR_START_MARGIN },
    )
    return this.observer
  }

  private async loadNewer(links: Element): Promise<void> {
    if (this.request || document.documentElement.hasAttribute("data-turbo-preview")) return

    const url = links.querySelector<HTMLAnchorElement>("a[rel=prev]")?.href
    if (!url) return

    const abort = new AbortController()
    this.request = abort
    const answer = await fetchStream(url, abort.signal)
    if (this.request !== abort) return

    this.request = undefined
    if (answer === null) this.observer?.unobserve(links)
    else if (links.isConnected) this.renderKeepingPlace(answer)
  }

  private renderKeepingPlace(answer: string): void {
    const keepPlace = (event: Event): void => {
      const detail = (event as CustomEvent<StreamRenderDetail>).detail
      const render = detail.render
      detail.render = async (stream) => {
        const anchor = this.entryInView()
        const before = anchor?.getBoundingClientRect().top
        await render(stream)
        if (anchor?.isConnected && before !== undefined)
          window.scrollBy(0, anchorShift(before, anchor.getBoundingClientRect().top))
      }
    }
    document.addEventListener("turbo:before-stream-render", keepPlace)
    try {
      window.Turbo.renderStreamMessage(answer)
    } finally {
      document.removeEventListener("turbo:before-stream-render", keepPlace)
    }
  }

  private entryInView(): Element | undefined {
    const entries = this.element.querySelectorAll(".feed__entry")
    return Array.from(entries).find((entry) => entry.getBoundingClientRect().bottom > 0)
  }
}
