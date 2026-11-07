import { Controller } from "@hotwired/stimulus"
import { menuDigit } from "../lib/menu_key"

const STORAGE_KEY = "gameble:hub-menu-item"
const EXTRAS_PREFIX = "extras:"

export default class extends Controller<HTMLElement> {
  static targets = ["menu", "item", "heading", "main", "extras", "extrasEntry", "back"]
  static values = { focusFirst: Boolean }

  declare readonly hasMenuTarget: boolean
  declare readonly menuTarget: HTMLElement
  declare readonly itemTargets: HTMLElement[]
  declare readonly hasHeadingTarget: boolean
  declare readonly headingTarget: HTMLElement
  declare readonly hasExtrasTarget: boolean
  declare readonly mainTarget: HTMLElement
  declare readonly extrasTarget: HTMLElement
  declare readonly extrasEntryTarget: HTMLElement
  declare readonly backTarget: HTMLElement
  declare readonly focusFirstValue: boolean

  connect(): void {
    if (document.documentElement.hasAttribute("data-turbo-preview")) return

    const stored = takeStored()
    if (stored === undefined && !this.focusFirstValue) return

    let key = stored
    if (!this.focusFirstValue && stored?.startsWith(EXTRAS_PREFIX) && this.hasExtrasTarget) {
      this.showExtras(true)
      key = stored.slice(EXTRAS_PREFIX.length)
    }

    const item =
      this.focusFirstValue || key === undefined ? this.shownItems()[0] : (this.item(key) ?? this.shownItems()[0])
    if (this.menuShown()) {
      item?.focus()
    } else if (this.hasHeadingTarget) {
      this.headingTarget.focus()
    }
  }

  press(event: KeyboardEvent): void {
    if (event.key === "Escape" && this.extrasShown()) {
      event.preventDefault()
      this.closeExtras()
      return
    }

    const digit = menuDigit(event)
    if (!digit) return

    const item = this.item(digit)
    if (!item) return
    event.preventDefault()
    item.click()
  }

  openExtras(): void {
    this.showExtras(true)
    this.backTarget.focus()
  }

  closeExtras(): void {
    this.showExtras(false)
    this.extrasEntryTarget.focus()
  }

  keepShownList(event: Event): void {
    const target = event.target
    if (target === this.mainTarget || target === this.extrasTarget || target === this.extrasEntryTarget) {
      event.preventDefault()
    }
  }

  remember(event: Event): void {
    const key = (event.currentTarget as HTMLElement).getAttribute("aria-keyshortcuts")
    if (!key) return
    try {
      window.sessionStorage.setItem(STORAGE_KEY, this.extrasShown() ? EXTRAS_PREFIX + key : key)
    } catch {
      // Storage refused: the menu just does not remember the item.
    }
  }

  private showExtras(shown: boolean): void {
    this.mainTarget.hidden = shown
    this.extrasTarget.hidden = !shown
    this.extrasEntryTarget.setAttribute("aria-expanded", String(shown))
  }

  private extrasShown(): boolean {
    return this.hasExtrasTarget && !this.extrasTarget.hidden
  }

  private shownItems(): HTMLElement[] {
    return this.itemTargets.filter((item) => !item.closest("[hidden]"))
  }

  private item(key: string): HTMLElement | undefined {
    return this.shownItems().find(
      (item) => item.getAttribute("aria-keyshortcuts") === key && item.getAttribute("aria-disabled") !== "true",
    )
  }

  private menuShown(): boolean {
    return this.hasMenuTarget && this.menuTarget.getClientRects().length > 0
  }
}

function takeStored(): string | undefined {
  try {
    const key = window.sessionStorage.getItem(STORAGE_KEY)
    window.sessionStorage.removeItem(STORAGE_KEY)
    return key ?? undefined
  } catch {
    return undefined
  }
}
