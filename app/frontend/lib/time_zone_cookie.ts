export const TIME_ZONE_COOKIE = "time_zone"

const YEAR_IN_SECONDS = 365 * 24 * 60 * 60

export function timeZoneCookie(zone: string | undefined, cookies: string, secure: boolean): string | null {
  if (!zone) return null
  const pair = `${TIME_ZONE_COOKIE}=${encodeURIComponent(zone)}`
  if (cookies.split("; ").includes(pair)) return null

  return `${pair}; path=/; max-age=${YEAR_IN_SECONDS}; samesite=lax${secure ? "; secure" : ""}`
}

export function rememberTimeZone(): void {
  const cookie = timeZoneCookie(Intl.DateTimeFormat().resolvedOptions().timeZone, document.cookie, location.protocol === "https:")
  if (cookie) document.cookie = cookie
}
