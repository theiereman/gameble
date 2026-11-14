import type { FocusTarget } from "./booster"
import type { BoosterStageHost } from "./booster_host"
import type { BoosterOutlets } from "./booster_render_host"
import type BoosterActionsController from "../controllers/booster_actions_controller"
import type BoosterCanisterController from "../controllers/booster_canister_controller"
import type BoosterCelebrationController from "../controllers/booster_celebration_controller"
import type BoosterInfoController from "../controllers/booster_info_controller"
import type BoosterReservesController from "../controllers/booster_reserves_controller"
import type BoosterPlateController from "../controllers/booster_plate_controller"
import type BoosterStageController from "../controllers/booster_stage_controller"
import type BoosterTrayController from "../controllers/booster_tray_controller"
import type BoosterZoomController from "../controllers/booster_zoom_controller"

export type OutletSource = Readonly<{
  boosterInfoOutlets: BoosterInfoController[]
  hasBoosterActionsOutlet: boolean
  boosterActionsOutlet: BoosterActionsController
  hasBoosterReservesOutlet: boolean
  boosterReservesOutlet: BoosterReservesController
  hasBoosterCanisterOutlet: boolean
  boosterCanisterOutlet: BoosterCanisterController
  hasBoosterStageOutlet: boolean
  boosterStageOutlet: BoosterStageController
  hasBoosterPlateOutlet: boolean
  boosterPlateOutlet: BoosterPlateController
  hasBoosterTrayOutlet: boolean
  boosterTrayOutlet: BoosterTrayController
  hasBoosterZoomOutlet: boolean
  boosterZoomOutlet: BoosterZoomController
  boosterCelebrationOutlets: BoosterCelebrationController[]
}>

export const outletsOf = (source: OutletSource): BoosterOutlets => ({
  info: source.boosterInfoOutlets,
  actions: source.hasBoosterActionsOutlet ? source.boosterActionsOutlet : null,
  reserves: source.hasBoosterReservesOutlet ? source.boosterReservesOutlet : null,
  canister: source.hasBoosterCanisterOutlet ? source.boosterCanisterOutlet : null,
  stage: source.hasBoosterStageOutlet ? source.boosterStageOutlet : null,
  plate: source.hasBoosterPlateOutlet ? source.boosterPlateOutlet : null,
  tray: source.hasBoosterTrayOutlet ? source.boosterTrayOutlet : null,
  zoom: source.hasBoosterZoomOutlet ? source.boosterZoomOutlet : null,
  celebrations: source.boosterCelebrationOutlets,
})

export type StageCore = Pick<BoosterStageHost, "current" | "timers" | "apply" | "announce" | "phoneLayout">

export const stageHostFor = (access: OutletAccess, core: StageCore): BoosterStageHost => ({
  ...core,
  part: (index, name) => access.part(index, name),
  slot: (index) => access.slot(index),
  traySlot: (index) => access.traySlot(index),
  shake: () => access.shake(),
  fx: () => access.fx(),
  flash: () => access.flash(),
  canister: () => access.canister(),
})

export class OutletAccess {
  constructor(private readonly outlets: () => BoosterOutlets) {}

  part(index: number, name: string): HTMLElement | null {
    return this.outlets().stage?.part(index, name) ?? null
  }

  slot(index: number): HTMLLIElement | null {
    return this.outlets().stage?.slot(index) ?? null
  }

  shake(): HTMLElement | null {
    return this.outlets().stage?.shake ?? null
  }

  fx(): HTMLElement | null {
    return this.outlets().stage?.fx ?? null
  }

  flash(): HTMLElement | null {
    return this.outlets().stage?.flash ?? null
  }

  canister() {
    return this.outlets().canister?.parts ?? null
  }

  traySlot(index: number): HTMLElement | null {
    return this.outlets().tray?.slotElement(index) ?? null
  }

  focusElement(target: FocusTarget): HTMLElement | null {
    const { actions, tray } = this.outlets()
    if (target === "open") return actions?.openButton ?? null
    if (target === "home") return document.querySelector<HTMLElement>(".top-bar__home")
    if ("slot" in target) return tray?.slotElement(target.slot) ?? null
    return this.part(target.card, "hit")
  }
}
