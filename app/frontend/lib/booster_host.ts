import type { CanisterParts } from "../controllers/booster_canister_controller"
import type { BoosterState } from "./booster"
import type { ScreenTimers } from "./screen_timers"

export type Transition = (state: BoosterState) => BoosterState

export type BoosterStageHost = Readonly<{
  current: () => BoosterState
  timers: () => ScreenTimers
  apply: (transition: Transition) => BoosterState
  announce: (text: string) => void
  part: (index: number, name: string) => HTMLElement | null
  slot: (index: number) => HTMLLIElement | null
  traySlot: (index: number) => HTMLElement | null
  shake: () => HTMLElement | null
  fx: () => HTMLElement | null
  flash: () => HTMLElement | null
  canister: () => CanisterParts | null
  phoneLayout: () => boolean
}>
