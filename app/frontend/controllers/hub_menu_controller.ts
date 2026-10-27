import { Controller } from "@hotwired/stimulus"
import { menuDigit } from "../lib/menu_key"

const STORAGE_KEY = "gameble:hub-menu-item"

export default class extends Controller<HTMLElement> {
  static targets = ["menu", "item", "heading"]
  static values = { focusFirst: Boolean }

  declare readonly hasMenuTarget: boolean
  declare readonly menuTarget: HTMLElement
  declare readonly itemTargets: HTMLElement[]
  declare readonly hasHeadingTarget: boolean
  declare readonly headingTarget: HTMLElement
  declare readonly focusFirstValue: boolean

  connect(): void {
    if (document.documentElement.hasAttribute("data-turbo-preview")) return

    const stored = takeStored()
    if (stored === undefined && !this.focusFirstValue) return

    const item = this.focusFirstValue || stored === undefined ? this.itemTargets[0] : (this.item(stored) ?? this.itemTargets[0])
    if (this.menuShown()) {
      item?.focus()
    } else if (this.hasHeadingTarget) {
      this.headingTarget.focus()
    }
  }

  press(event: KeyboardEvent): void {
    const digit = menuDigit(event)
    if (!digit) return

    const item = this.item(digit)
    if (!item) return
    event.preventDefault()
    item.click()
  }

  remember(event: Event): void {
    const key = (event.currentTarget as HTMLElement).getAttribute("aria-keyshortcuts")
    if (!key) return
    try {
      window.sessionStorage.setItem(STORAGE_KEY, key)
    } catch {
      // Storage refused: the menu just does not remember the item.
    }
  }

  private item(key: string): HTMLElement | undefined {
    return this.itemTargets.find((item) => item.getAttribute("aria-keyshortcuts") === key && item.getAttribute("aria-disabled") !== "true")
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
