import { Controller } from "@hotwired/stimulus"

const READING_LINE = "0px 0px -66% 0px"

export default class extends Controller<HTMLElement> {
  static targets = ["link"]

  declare readonly linkTargets: HTMLAnchorElement[]

  private observer?: IntersectionObserver

  connect(): void {
    this.observer = new IntersectionObserver(this.crossed, { rootMargin: READING_LINE })
    for (const link of this.linkTargets) {
      const heading = document.getElementById(link.hash.slice(1))
      if (heading) this.observer.observe(heading)
    }
  }

  disconnect(): void {
    this.observer?.disconnect()
    this.observer = undefined
  }

  private readonly crossed = (entries: Array<Pick<IntersectionObserverEntry, "isIntersecting" | "target">>): void => {
    const reached = entries.find((entry) => entry.isIntersecting)
    if (!reached) return

    for (const link of this.linkTargets) {
      if (link.hash === `#${reached.target.id}`) link.setAttribute("aria-current", "location")
      else link.removeAttribute("aria-current")
    }
  }
}
