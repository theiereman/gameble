import { Controller } from "@hotwired/stimulus"
import {
  type StripState,
  blurred,
  focused,
  hovered,
  isCurrentChoice,
  restingStrip,
  sendChoice,
  shownSeason,
  stripTarget,
  unhovered,
} from "../lib/back_picker"
import { cloneContent } from "../lib/templates"

const ACTIVE = "back-picker__tile--active"
const LOCKED = "back-picker__tile--locked"

export default class extends Controller<HTMLElement> {
  static targets = ["strip", "status", "tile", "activeChip", "unlockedChip", "lockedChip", "failure"]
  static values = { active: String, season: Number }

  declare readonly stripTarget: HTMLElement
  declare readonly statusTarget: HTMLElement
  declare readonly tileTargets: HTMLElement[]
  declare readonly activeChipTarget: HTMLTemplateElement
  declare readonly unlockedChipTarget: HTMLTemplateElement
  declare readonly lockedChipTarget: HTMLTemplateElement
  declare readonly failureTarget: HTMLTemplateElement
  declare activeValue: string
  declare seasonValue: number
  declare readonly hasSeasonValue: boolean

  private active = ""
  private worn: number | null = null
  private strip: StripState = restingStrip
  private shown: string | null = null
  private saving = false
  private resizes?: ResizeObserver

  connect(): void {
    this.active = this.activeValue
    this.worn = this.hasSeasonValue ? this.seasonValue : null
    this.shown = this.active
    this.resizes = new ResizeObserver(() => this.measureStrip())
    this.resizes.observe(this.stripTarget)
    this.measureStrip()
  }

  disconnect(): void {
    this.resizes?.disconnect()
  }

  hover(event: PointerEvent): void {
    if (event.pointerType === "touch") return
    const key = this.keyOf(event.target)
    if (key) this.update(hovered(this.strip, key))
  }

  unhover(event: PointerEvent): void {
    const key = this.keyOf(event.target)
    if (!key || key === this.keyOf(event.relatedTarget)) return
    this.update(unhovered(this.strip, key))
  }

  focus(event: FocusEvent): void {
    const key = this.keyOf(event.target)
    if (key) this.update(focused(this.strip, key))
  }

  blur(event: FocusEvent): void {
    if (!this.keyOf(event.relatedTarget)) this.update(blurred(this.strip))
  }

  tap(event: MouseEvent): void {
    const key = this.keyOf(event.target)
    if (key) this.update(focused(this.strip, key))
  }

  async choose(event: SubmitEvent): Promise<void> {
    const form = event.target as HTMLFormElement
    if (!this.element.contains(form)) return
    event.preventDefault()
    const fields = new FormData(form)
    const back = String(fields.get("back") ?? "")
    const season = fields.get("season") ? Number(fields.get("season")) : null
    if (this.saving || isCurrentChoice({ back, season }, { back: this.active, season: this.worn })) return

    this.saving = true
    const result = await sendChoice({ url: form.action, back, season, csrfToken: this.csrfToken() })
    this.saving = false
    if (result.kind === "chosen" && this.tileFor(result.back)) {
      this.equip(result.back, result.season)
      this.update(this.strip, true)
      this.announce(result.announcement)
    } else {
      this.showFailure()
    }
  }

  private equip(back: string, season: number | null): void {
    const previous = this.tileFor(this.active)
    this.active = back
    this.worn = season
    this.activeValue = back
    if (season === null) this.element.removeAttribute("data-back-picker-season-value")
    else this.seasonValue = season
    if (previous) this.dress(previous, false)
    const next = this.tileFor(back)
    if (next) this.dress(next, true)
  }

  private dress(tile: HTMLElement, active: boolean): void {
    tile.classList.toggle(ACTIVE, active)
    const button = tile.querySelector<HTMLButtonElement>(".back-picker__back")
    const label = active ? button?.dataset.activeLabel : button?.dataset.unlockedLabel
    if (button && label) button.setAttribute("aria-label", label)

    const worn = active ? this.worn : null
    const stamps = [...tile.querySelectorAll<HTMLElement>(".back-picker__stamp")]
    const seasons = stamps.map((stamp) => Number(stamp.dataset.season))
    const shown = shownSeason(seasons, worn)
    stamps.forEach((stamp) => (stamp.hidden = Number(stamp.dataset.season) !== shown))
    tile.querySelectorAll<HTMLElement>(".back-picker__season").forEach((seasonButton) => {
      seasonButton.setAttribute("aria-pressed", String(worn !== null && Number(seasonButton.dataset.season) === worn))
    })
  }

  private update(state: StripState, force = false): void {
    this.strip = state
    const key = stripTarget(state, this.active)
    if (!force && key === this.shown) return
    this.shown = key
    this.render(key)
  }

  private render(key: string): void {
    const tile = this.tileFor(key)
    const detail = tile?.querySelector<HTMLTemplateElement>("template.back-picker__detail")
    if (!tile || !detail) return
    this.stripTarget.replaceChildren(cloneContent(this.chipFor(tile, key)), cloneContent(detail))
    this.stripTarget.dataset.showing = key === this.active ? "active" : "other"
  }

  private showFailure(): void {
    this.shown = null
    this.stripTarget.replaceChildren(cloneContent(this.failureTarget))
    this.stripTarget.dataset.showing = "failed"
    this.announce(this.failureTarget.content.textContent?.trim() ?? "")
  }

  private chipFor(tile: HTMLElement, key: string): HTMLTemplateElement {
    if (key === this.active) return this.activeChipTarget
    return tile.classList.contains(LOCKED) ? this.lockedChipTarget : this.unlockedChipTarget
  }

  private announce(message: string): void {
    this.statusTarget.textContent = ""
    window.requestAnimationFrame(() => (this.statusTarget.textContent = message))
  }

  private measureStrip(): void {
    this.element.style.setProperty("--back-picker-strip-height", `${this.stripTarget.offsetHeight}px`)
  }

  private keyOf(target: EventTarget | null): string | null {
    if (!(target instanceof Element)) return null
    const tile = target.closest<HTMLElement>("[data-back-picker-target~='tile']")
    return tile && this.element.contains(tile) ? (tile.dataset.key ?? null) : null
  }

  private tileFor(key: string): HTMLElement | undefined {
    return this.tileTargets.find((tile) => tile.dataset.key === key)
  }

  private csrfToken(): string | null {
    return document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content ?? null
  }
}
