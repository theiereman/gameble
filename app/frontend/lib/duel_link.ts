export const LINK_GRACE_SECONDS = 60

export type Link = { readonly lostAt: number | null; readonly seen: boolean }

export function startLink(): Link {
  return { lostAt: null, seen: false }
}

export function linkChecked(link: Link, connected: boolean, online: boolean, now: number): Link {
  const seen = link.seen || (connected && online)
  if (online && (connected || !seen)) return { lostAt: null, seen }
  return { lostAt: link.lostAt ?? now, seen }
}

export function linkSecondsLeft(link: Link, now: number): number | null {
  if (link.lostAt === null) return null
  return Math.max(0, Math.ceil(LINK_GRACE_SECONDS - (now - link.lostAt) / 1000))
}
