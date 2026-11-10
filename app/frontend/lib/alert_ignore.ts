export const IGNORED_ALERT_PREFIX = "gameble:ignored-alert:"

type AlertStorage = Pick<Storage, "getItem" | "setItem">

function browserStorage(): AlertStorage | null {
  try {
    return window.localStorage
  } catch {
    return null
  }
}

export function ignoredAlertKey(indicator: string): string {
  return IGNORED_ALERT_PREFIX + indicator
}

export function isIgnored(indicator: string, value: string, storage: AlertStorage | null = browserStorage()): boolean {
  if (!storage || !indicator) return false
  try {
    return storage.getItem(ignoredAlertKey(indicator)) === value
  } catch {
    return false
  }
}

export function ignoreAlert(indicator: string, value: string, storage: AlertStorage | null = browserStorage()): void {
  if (!storage || !indicator) return
  try {
    storage.setItem(ignoredAlertKey(indicator), value)
  } catch {
    return
  }
}
