import { Controller } from "@hotwired/stimulus"

// The session key holding the number of the menu item last used.
const STORAGE_KEY = "gameble:hub-menu-item"

// The hub's numbered menu (EXPERIENCE.md, Menu item). While the focus is
// inside the menu, keys 1 to 6 (without Ctrl, Alt or Meta) activate the item whose
// `aria-keyshortcuts` is that key, unless it is disabled. Using an item
// remembers its number for the session (sessionStorage), and coming back to
// the hub focuses it, once. Right after signing in (`focus-first`) the hub
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
    const item = this.focusFirstValue || stored === undefined ? this.itemTargets[0] : this.item(stored)
    if (this.menuShown()) {
      item?.focus()
    } else if (this.hasHeadingTarget) {
      this.headingTarget.focus()
    }
  }

  // keydown inside the menu. The digit is read from the key, or from the
  // physical digit row for layouts that type digits with Shift (AZERTY);
  // never from the numpad's code, whose keys are arrows with NumLock off.
  press(event: KeyboardEvent): void {
    if (event.ctrlKey || event.metaKey || event.altKey || event.repeat) return
    const digit = /^[1-6]$/.test(event.key) ? event.key : /^Digit([1-6])$/.exec(event.code)?.[1]
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
