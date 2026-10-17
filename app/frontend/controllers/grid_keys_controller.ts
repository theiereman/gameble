import { Controller } from "@hotwired/stimulus"
import { columnsOf, nextIndex } from "../lib/grid_keys"

export default class extends Controller<HTMLElement> {
  connect(): void {
    const links = this.links()
    this.rove(links.find((link) => link.getAttribute("tabindex") === "0") ?? links[0])
  }

  move(event: KeyboardEvent): void {
    if (event.defaultPrevented || event.altKey || event.ctrlKey || event.metaKey || event.shiftKey) return
    const links = this.links()
    const index = links.findIndex((link) => link.contains(event.target as Node))
    if (index === -1) return
    const columns = columnsOf(links.map((link) => (link.parentElement ?? link).getBoundingClientRect().top))
    const next = nextIndex(event.key, index, links.length, columns)
    if (next === null) return
    event.preventDefault()
    const target = links[next]
    this.rove(target)
    target?.focus()
  }

  remember(event: FocusEvent): void {
    const link = this.links().find((candidate) => candidate.contains(event.target as Node))
    if (link) this.rove(link)
  }

  private links(): HTMLAnchorElement[] {
    return Array.from(this.element.querySelectorAll<HTMLAnchorElement>(":scope > li > a"))
  }

  private rove(current: HTMLAnchorElement | undefined): void {
    for (const link of this.links()) link.tabIndex = link === current ? 0 : -1
  }
}
