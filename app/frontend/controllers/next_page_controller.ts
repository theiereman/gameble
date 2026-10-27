import { Controller } from "@hotwired/stimulus"
import "../lib/turbo"
import {
  isTurboStream,
  NEAR_END_MARGIN,
  NextPage,
  renderingWhile,
  TURBO_STREAM,
  type Step,
  type StreamRender,
} from "../lib/next_page"

type Request = { links: Element; abort: AbortController }

type StreamRenderDetail = { render: StreamRender<Element> }

async function fetchStream(url: string, signal: AbortSignal): Promise<string | null> {
  try {
    const response = await fetch(url, { headers: { Accept: TURBO_STREAM }, credentials: "same-origin", signal })
    if (!response.ok || !isTurboStream(response.headers.get("Content-Type"))) return null
    return await response.text()
  } catch {
    return null
  }
}

export default class extends Controller<HTMLElement> {
  static targets = ["pages"]

  private readonly pages = new Map<Element, NextPage>()
  private request?: Request
  private observer?: IntersectionObserver
  private focusCheck?: number

  pagesTargetConnected(links: HTMLElement): void {
    const next = links.querySelector<HTMLAnchorElement>("a[rel=next]")?.href ?? null
    this.pages.set(links, new NextPage(next))
    this.observing().observe(links)
  }

  pagesTargetDisconnected(links: HTMLElement): void {
    this.pages.delete(links)
    this.observer?.unobserve(links)
    if (this.request?.links === links) this.cancelRequest()
  }

  disconnect(): void {
    this.cancelRequest()
    window.clearTimeout(this.focusCheck)
    this.focusCheck = undefined
    this.observer?.disconnect()
    this.observer = undefined
  }

  focusLeft(): void {
    window.clearTimeout(this.focusCheck)
    this.focusCheck = window.setTimeout(() => {
      this.focusCheck = undefined
      for (const [links, next] of this.pages) if (!this.focusIn(links)) this.perform(links, next.focusLeft())
    }, 0)
  }

  private observing(): IntersectionObserver {
    this.observer ??= new IntersectionObserver(
      (entries) => {
        for (const entry of entries) if (entry.isIntersecting) this.approached(entry.target)
      },
      { rootMargin: NEAR_END_MARGIN },
    )
    return this.observer
  }

  private approached(links: Element): void {
    if (this.request || document.documentElement.hasAttribute("data-turbo-preview")) return

    const next = this.pages.get(links)
    const step = next?.approached()
    if (next && step?.kind === "fetch") void this.load(links, next, step.url)
  }

  private async load(links: Element, next: NextPage, url: string): Promise<void> {
    const abort = new AbortController()
    this.request = { links, abort }
    const answer = await fetchStream(url, abort.signal)
    if (this.request?.abort !== abort) return

    this.request = undefined
    if (answer === null) next.failed()
    else this.perform(links, next.answered(answer, this.focusIn(links)))
  }

  private perform(links: Element, step: Step): void {
    if (step.kind !== "render" || !links.isConnected) return

    // Turbo renders each stream action a repaint later, when a filter reload may have replaced the grid.
    const guard = (event: Event): void => {
      const detail = (event as CustomEvent<StreamRenderDetail>).detail
      detail.render = renderingWhile(detail.render, () => links.isConnected)
    }
    document.addEventListener("turbo:before-stream-render", guard)
    try {
      window.Turbo.renderStreamMessage(step.answer)
    } finally {
      document.removeEventListener("turbo:before-stream-render", guard)
    }
  }

  private focusIn(links: Element): boolean {
    return links.contains(document.activeElement)
  }

  private cancelRequest(): void {
    this.request?.abort.abort()
    this.request = undefined
  }
}
