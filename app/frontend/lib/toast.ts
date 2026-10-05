// How long a toast stays (EXPERIENCE.md, Toast): at least 5 seconds, plus
// one second per started group of ten words.
export const TOAST_BASE_MS = 5000
export const TOAST_MS_PER_TEN_WORDS = 1000

export function toastDuration(text: string): number {
  const words = text.trim().split(/\s+/).filter(Boolean).length
  return TOAST_BASE_MS + Math.ceil(words / 10) * TOAST_MS_PER_TEN_WORDS
}
