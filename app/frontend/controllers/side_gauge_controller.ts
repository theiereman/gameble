import { Controller } from "@hotwired/stimulus"
import { currentModuleIndex, scrollFill } from "../lib/landing_scroll"
import { motionReduced } from "../lib/motion"

export default class extends Controller<HTMLElement> {
  static targets = ["marker", "segment"]

  declare readonly markerTargets: HTMLAnchorElement[]
  declare readonly segmentTargets: HTMLElement[]

  private frame = 0

  connect(): void {
    window.addEventListener("scroll", this.schedule, { passive: true })
    window.addEventListener("resize", this.schedule)
    this.update()
  }

  disconnect(): void {
    window.removeEventListener("scroll", this.schedule)
    window.removeEventListener("resize", this.schedule)
    cancelAnimationFrame(this.frame)
    this.frame = 0
  }

  go(event: Event): void {
    const marker = event.currentTarget as HTMLAnchorElement
    const heading = document.getElementById(marker.hash.slice(1))
    if (!heading) return
    event.preventDefault()
    heading.scrollIntoView({ behavior: motionReduced() ? "auto" : "smooth", block: "start" })
    heading.focus({ preventScroll: true })
    this.update()
  }

  private readonly schedule = (): void => {
    if (this.frame) return
    this.frame = requestAnimationFrame(() => {
      this.frame = 0
      this.update()
    })
  }

  private update(): void {
    this.markCurrent()
    this.fill()
  }

  private markCurrent(): void {
    const tops = this.markerTargets.map((marker) => document.getElementById(marker.hash.slice(1))?.getBoundingClientRect().top ?? Infinity)
    const current = currentModuleIndex(tops, window.innerHeight, this.atPageEnd())
    this.markerTargets.forEach((marker, index) => {
      if (index === current) marker.setAttribute("aria-current", "location")
      else marker.removeAttribute("aria-current")
    })
  }

  private atPageEnd(): boolean {
    return window.scrollY + window.innerHeight >= document.documentElement.scrollHeight - 1
  }

  private fill(): void {
    const scrollable = document.documentElement.scrollHeight - window.innerHeight
    const lit = scrollFill(window.scrollY, scrollable, this.segmentTargets.length)
    this.segmentTargets.forEach((segment, index) => segment.classList.toggle("is-lit", index < lit))
  }
}
