import { cloneFirstElement } from "./templates"

const ANNOUNCEMENTS_KEPT = 5

export function announceIn(live: HTMLElement, template: HTMLTemplateElement, text: string): void {
  const span = cloneFirstElement(template)
  if (!span) return
  span.textContent = text
  live.append(span)
  while (live.children.length > ANNOUNCEMENTS_KEPT) live.firstElementChild?.remove()
}
