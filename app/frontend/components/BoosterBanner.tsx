// The banner over the booster stage (Épique small, Légendaire large),
// decorative: the tier's name between its icons and stripes, the
// Légendaire's title line under it. It plays once as it is drawn (a still
// fade under reduced motion), then asks the island to clear it.
import { useLayoutEffect, useRef } from "react"
import type { Banner } from "../lib/booster"
import { EPIC_BANNER_MS, LEGENDARY_BANNER_MS, RM_LEGENDARY_STILL } from "../lib/booster_motion"
import { animate } from "../lib/booster_effects"
import { bannerKeyframes } from "../lib/booster_keyframes"

export type BoosterBannerProps = {
  banner: Banner
  /** The tier's pixel icon, as HTML. */
  icon: string
  /** "Épique", or "Légendaire !". */
  name: string
  /** The banner has played: the island clears it, unless a newer one replaced it. */
  onEnd: (key: number) => void
}

export default function BoosterBanner({ banner, icon, name, onEnd }: BoosterBannerProps) {
  const element = useRef<HTMLDivElement>(null)

  useLayoutEffect(() => {
    const duration = banner.reduced ? RM_LEGENDARY_STILL : banner.large ? LEGENDARY_BANNER_MS : EPIC_BANNER_MS
    animate(element.current, bannerKeyframes(banner.reduced), { duration, fill: "none" })
    const key = banner.key
    const timer = window.setTimeout(() => onEnd(key), duration)
    return () => window.clearTimeout(timer)
  }, [banner])

  return (
    <div ref={element} className={banner.large ? "booster__banner booster__banner--large" : "booster__banner"} data-tier={banner.tier} aria-hidden="true">
      <div className="booster__banner-row">
        <span className="booster__banner-stripe" />
        <span className="booster__banner-icon" dangerouslySetInnerHTML={{ __html: icon }} />
        <span className="booster__banner-name">{name}</span>
        <span className="booster__banner-icon" dangerouslySetInnerHTML={{ __html: icon }} />
        <span className="booster__banner-stripe" />
      </div>
      {banner.line && <p className="booster__banner-line">{banner.line}</p>}
    </div>
  )
}
