import { Controller } from "@hotwired/stimulus"
import { menuDigit } from "../lib/menu_key"

// The session key holding the number of the menu item last used.
const STORAGE_KEY = "gameble:hub-menu-item"

// The hub's numbered menu (EXPERIENCE.md, Menu item). While the focus is
// inside the menu, a digit key from 1 to 9 (without Ctrl, Alt or Meta)
// activates the item whose `aria-keyshortcuts` is that digit, unless it is
// disabled; a digit no item carries does nothing. Using an item
// remembers its number for the session (sessionStorage), and coming back to
// the hub focuses it, once (the first enabled item when it is disabled by
// then). Right after signing in (`focus-first`) the hub
// focuses item 01 instead; where the menu is hidden (the phone), the hub's
// heading takes that focus. Without storage, nothing is restored and
// nothing fails. Nothing happens on a Turbo preview.
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

    // A sign-in always focuses item 01, whatever item was used before it.
    // An item used and now disabled (01 once the reserve is empty) gives
    // the focus to the first enabled item, as a sign-in does.
    const item = this.focusFirstValue || stored === undefined ? this.itemTargets[0] : (this.item(stored) ?? this.itemTargets[0])
    if (this.menuShown()) {
      item?.focus()
    } else if (this.hasHeadingTarget) {
      this.headingTarget.focus()
    }
  }

  // keydown inside the menu.
  press(event: KeyboardEvent): void {
    const digit = menuDigit(event)
    if (!digit) return

    const item = this.item(digit)
    if (!item) return
    event.preventDefault()
    item.click()
  }

  // click on an enabled item: remembered for the way back.
  remember(event: Event): void {
    const key = (event.currentTarget as HTMLElement).getAttribute("aria-keyshortcuts")
    if (!key) return
    try {
      window.sessionStorage.setItem(STORAGE_KEY, key)
    } catch {
      // Storage unavailable: no focus restore.
    }
  }

  // The enabled item activated by this key, if any.
  private item(key: string): HTMLElement | undefined {
    return this.itemTargets.find((item) => item.getAttribute("aria-keyshortcuts") === key && item.getAttribute("aria-disabled") !== "true")
  }

  private menuShown(): boolean {
    return this.hasMenuTarget && this.menuTarget.getClientRects().length > 0
  }
}

// The item number stored by the last use, cleared once read.
function takeStored(): string | undefined {
  try {
    const key = window.sessionStorage.getItem(STORAGE_KEY)
    window.sessionStorage.removeItem(STORAGE_KEY)
    return key ?? undefined
  } catch {
    return undefined
  }
}
