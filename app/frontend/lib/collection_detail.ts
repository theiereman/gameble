// The choices of the card detail beside the collection grid, apart from the DOM.

export type SlotClick = Pick<MouseEvent, "defaultPrevented" | "button" | "metaKey" | "ctrlKey" | "shiftKey" | "altKey">

export function opensBeside(click: SlotClick, phone: boolean): boolean {
  if (phone || click.defaultPrevented || click.button !== 0) return false
  return !(click.metaKey || click.ctrlKey || click.shiftKey || click.altKey)
}

export function openAction(frameHoldsCard: boolean): "advance" | "replace" {
  return frameHoldsCard ? "replace" : "advance"
}

export function selectedLink<Link extends { href: string }>(links: Link[], frameSource: string | null, base: string): Link | undefined {
  if (!frameSource) return undefined
  const shown = new URL(frameSource, base).pathname
  return links.find((link) => new URL(link.href, base).pathname === shown)
}
