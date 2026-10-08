// An island's live region: a new node per message, so each is spoken; the
// latest few kept.
import { useCallback, useState } from "react"

/** The live region keeps the latest few announcements; older ones are spoken already. */
const ANNOUNCEMENTS_KEPT = 5

export type Announcement = { key: number; text: string }

export function useLiveRegion(): { announcements: Announcement[]; announce: (text: string) => void } {
  const [announcements, setAnnouncements] = useState<Announcement[]>([])
  const announce = useCallback(
    (text: string) =>
      setAnnouncements((previous) => [...previous.slice(-(ANNOUNCEMENTS_KEPT - 1)), { key: (previous.at(-1)?.key ?? 0) + 1, text }]),
    [],
  )
  return { announcements, announce }
}
