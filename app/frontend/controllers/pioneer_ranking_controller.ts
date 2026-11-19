import { Controller } from "@hotwired/stimulus"
import { writeText } from "../lib/dom_writes"

const RESULTS_FRAME = "pioneer-ranking-results"
const MINE_HASH = "#pioneer-ranking-me"
const PINNED = "pioneer-place--pinned"
const READING = "[data-pioneer-ranking-reading]"

export default class PioneerRankingController extends Controller<HTMLElement> {
  static targets = ["status", "address", "place", "mine"]

  declare readonly statusTarget: HTMLElement
  declare readonly placeTarget: HTMLElement
  declare readonly mineTarget: HTMLElement
  declare readonly hasPlaceTarget: boolean
  declare readonly hasMineTarget: boolean

  private chosen?: string
  private rowOnScreen = false
  private focusInBar = false
  private observer?: IntersectionObserver
  private announcement?: number

  connect(): void {
    this.render()
  }

  disconnect(): void {
    this.observer?.disconnect()
    this.observer = undefined
    window.cancelAnimationFrame(this.announcement ?? 0)
  }

  chose(event: Event): void {
    this.chosen = (event.currentTarget as HTMLButtonElement).name
  }

  reloaded(event: Event): void {
    if (!(event.target instanceof HTMLElement) || event.target.id !== RESULTS_FRAME) return

    const pressed = `button[name="${this.chosen}"][aria-pressed="true"]`
    if (this.chosen) this.element.querySelector<HTMLElement>(pressed)?.focus()
    this.chosen = undefined
    const reading = this.element.querySelector<HTMLElement>(READING)?.dataset.pioneerRankingReading ?? ""
    writeText(this.statusTarget, "")
    window.cancelAnimationFrame(this.announcement ?? 0)
    this.announcement = window.requestAnimationFrame(() => writeText(this.statusTarget, reading))
  }

  addressTargetConnected(marker: HTMLElement): void {
    const url = marker.dataset.url
    if (url && url !== location.pathname + location.search) history.replaceState(history.state, "", url)
  }

  placeTargetConnected(): void {
    this.render()
  }

  mineTargetConnected(row: HTMLElement): void {
    this.rowOnScreen = true
    this.observing().observe(row)
    if (location.hash === MINE_HASH) row.focus()
    this.render()
  }

  mineTargetDisconnected(row: HTMLElement): void {
    this.observer?.unobserve(row)
    this.rowOnScreen = false
    this.render()
  }

  go(event: Event): void {
    if (!this.hasMineTarget) return

    event.preventDefault()
    this.mineTarget.scrollIntoView({ block: "center" })
    this.mineTarget.focus({ preventScroll: true })
  }

  barFocused(): void {
    this.focusInBar = true
    this.render()
  }

  barLeft(): void {
    this.focusInBar = false
    this.render()
  }

  private observing(): IntersectionObserver {
    this.observer ??= new IntersectionObserver((entries) => {
      for (const entry of entries) this.rowOnScreen = entry.isIntersecting
      this.render()
    })
    return this.observer
  }

  private render(): void {
    if (!this.hasPlaceTarget) return

    const pinned = !(this.hasMineTarget && this.rowOnScreen) || this.focusInBar
    this.placeTarget.classList.toggle(PINNED, pinned)
  }
}
