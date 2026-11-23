export interface ReturnPoint {
  readonly tileId: string | null
  readonly fallbacks: readonly HTMLElement[]
}

const TILE_LINK = "a[href]"

function tileLink(tile: Element | null | undefined): HTMLElement | null {
  return tile?.querySelector<HTMLElement>(TILE_LINK) ?? null
}

/** Where focus returns once the dialog closes: the tile redrawn under the same id, else the next tile, the previous one, the heading. */
export function returnPoint(opener: Element, heading: HTMLElement | null): ReturnPoint {
  const tile = opener.closest("li")
  const neighbours = [tileLink(tile?.nextElementSibling), tileLink(tile?.previousElementSibling), heading]
  return { tileId: tile?.id || null, fallbacks: neighbours.filter((element) => element !== null) }
}

export function focusTarget(point: ReturnPoint, byId: (id: string) => Element | null): HTMLElement | undefined {
  const redrawn = point.tileId ? tileLink(byId(point.tileId)) : null
  return [redrawn, ...point.fallbacks].find((element): element is HTMLElement => element?.isConnected === true)
}
