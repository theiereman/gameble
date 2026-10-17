export const LAST_ALBUM_KEY = "gameble:last-album"

export type AlbumStorage = Pick<Storage, "getItem" | "setItem">

export function rememberAlbum(pathname: string, storage: AlbumStorage | null): void {
  try {
    storage?.setItem(LAST_ALBUM_KEY, pathname)
  } catch {
    // Refused (private mode, quota): no row is marked.
  }
}

export function lastAlbum(storage: AlbumStorage | null): string | null {
  try {
    return storage?.getItem(LAST_ALBUM_KEY) || null
  } catch {
    return null
  }
}

export function leadsTo(href: string, base: string, pathname: string | null): boolean {
  if (!pathname) return false
  try {
    return new URL(href, base).pathname === pathname
  } catch {
    return false
  }
}

export function albumStorage(): AlbumStorage | null {
  try {
    return window.sessionStorage
  } catch {
    return null
  }
}
