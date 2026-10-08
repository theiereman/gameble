export const LIVE_REFRESH_HOLD = "data-live-refresh-hold"

export function holdLiveRefresh(element: Element, hold: boolean): void {
  element.toggleAttribute(LIVE_REFRESH_HOLD, hold)
}

export function liveRefreshHeld(root: ParentNode): boolean {
  return root.querySelector(`[${LIVE_REFRESH_HOLD}]`) !== null
}
