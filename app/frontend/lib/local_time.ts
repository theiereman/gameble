export type LocalTimeStyle = "datetime" | "date-time-year" | "time" | "weekday-time"

export type LocalTimeZone = { locale: string; timeZone?: string }

const CLOCK = { hour: "2-digit", minute: "2-digit", hourCycle: "h23" } as const

const FORMATS: Record<LocalTimeStyle, Intl.DateTimeFormatOptions> = {
  datetime: { day: "numeric", month: "short", ...CLOCK },
  "date-time-year": { day: "numeric", month: "short", year: "numeric", ...CLOCK },
  time: CLOCK,
  "weekday-time": { weekday: "long", ...CLOCK },
}

export function isLocalTimeStyle(value: string): value is LocalTimeStyle {
  return Object.hasOwn(FORMATS, value)
}

export function formatLocalTime(instant: string | Date, style: LocalTimeStyle, { locale, timeZone }: LocalTimeZone): string | null {
  const date = instant instanceof Date ? instant : new Date(instant)
  if (instant === "" || Number.isNaN(date.getTime())) return null
  try {
    return new Intl.DateTimeFormat(locale || undefined, { ...FORMATS[style], timeZone }).format(date)
  } catch {
    return null
  }
}
