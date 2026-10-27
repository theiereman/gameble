import { cardStored, storeEnded, storeStarted } from "./booster"
import { animate, settle, traySparks } from "./booster_effects"
import type { BoosterStageHost } from "./booster_host"
import { slotPopKeyframes, springBackKeyframes, storeKeyframes } from "./booster_keyframes"
import { SLOT_POP_MS, SPRING_BACK_MS, STORE_MS } from "./booster_motion"
import { motionReduced } from "./motion"

export type CardStoreHost = BoosterStageHost & Readonly<{ whenIdle: () => void }>

export class CardStore {
  constructor(private readonly host: CardStoreHost) {}

  async store(index: number, fromAll: boolean): Promise<void> {
    const { host } = this
    const before = host.current()
    const card = before.answer?.cards[index]
    if (!card || host.apply((s) => storeStarted(s, index, fromAll, performance.now())) === before) return
    const float = host.part(index, "float")
    const frame = host.slot(index)?.querySelector(".booster-card__frame")
    const target = host.traySlot(index)
    const from = float?.style.transform || "none"
    if (float) float.style.transform = ""
    if (!motionReduced() && float && frame && target) {
      settle(float)
      animate(float, storeKeyframes(from, frame.getBoundingClientRect(), target.getBoundingClientRect()), {
        duration: STORE_MS,
        easing: "cubic-bezier(.45,0,.6,1)",
        fill: "forwards",
      })
      await host.timers().wait(STORE_MS)
    }
    if (host.timers().disposed) return
    host.apply((s) => cardStored(s, index))
    if (!motionReduced()) {
      animate(host.traySlot(index), slotPopKeyframes(), { duration: SLOT_POP_MS, easing: "cubic-bezier(.2,1.35,.35,1)" })
      traySparks(host.fx(), host.traySlot(index), card.tier)
    }
    host.apply((s) => storeEnded(s, fromAll))
    host.whenIdle()
  }

  springBack(index: number): void {
    const float = this.host.part(index, "float")
    if (!float) return
    const from = float.style.transform || "none"
    float.style.transform = ""
    if (!motionReduced()) animate(float, springBackKeyframes(from), { duration: SPRING_BACK_MS, easing: "cubic-bezier(.2,1.6,.4,1)" })
  }
}
