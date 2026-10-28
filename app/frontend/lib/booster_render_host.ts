import type BoosterActionsController from "../controllers/booster_actions_controller"
import type BoosterCanisterController from "../controllers/booster_canister_controller"
import type BoosterCelebrationController from "../controllers/booster_celebration_controller"
import type BoosterInfoController from "../controllers/booster_info_controller"
import type BoosterReservesController from "../controllers/booster_reserves_controller"
import type BoosterPlateController from "../controllers/booster_plate_controller"
import type BoosterStageController from "../controllers/booster_stage_controller"
import type BoosterTrayController from "../controllers/booster_tray_controller"
import type BoosterZoomController from "../controllers/booster_zoom_controller"
import type { CelebrationStrings } from "./celebration"
import type { Rarity } from "./card_types"
import type { Template } from "./i18n"
import type { Transition } from "./booster_host"
import type { ScreenTimers } from "./screen_timers"

export type BoosterStrings = {
  announceCard: string
  bannerLine: string
  canisterFacts: Template
  canisterLabel: string
  canisterLabelPlain: string
  celebration: CelebrationStrings
  emptyNext: string
  faceDown: string
  faceUp: string
  faceUpStore: string
  failed: string
  hintDone: Template
  hintRemaining: Template
  legendarySignal: string
  nextAt: string
  refusedTitle: string
  repostCard: string
  repostFailed: string
  reposted: string
  originBonus: string
  originOpening: string
  originReward: string
  reserveCount: Template
  specialArrived: string
  standardReady: string
  tabSpecial: string
  tabStandard: string
  summary: Template
  summaryTier: string
  trayCount: string
  traySlot: string
  zoomLine: string
}

export type BoosterOutlets = Readonly<{
  info: BoosterInfoController[]
  actions: BoosterActionsController | null
  reserves: BoosterReservesController | null
  canister: BoosterCanisterController | null
  stage: BoosterStageController | null
  plate: BoosterPlateController | null
  tray: BoosterTrayController | null
  zoom: BoosterZoomController | null
  celebrations: BoosterCelebrationController[]
}>

export type BoosterRenderHost = Readonly<{
  element: HTMLElement
  panelActions: HTMLElement
  phoneActions: HTMLElement
  strings: BoosterStrings
  delimiter: string
  packSize: number
  season: number
  cardUrl: string
  left: () => number | null
  rarityNames: () => Record<Rarity, string>
  timers: () => ScreenTimers
  outlets: () => BoosterOutlets
  apply: (transition: Transition) => unknown
  tierLabel: (tier: Rarity) => string
  number: (value: number) => string
  face: (index: number) => DocumentFragment | null
  faceFragment: (index: number, size: string) => DocumentFragment | null
  icon: (tier: Rarity) => DocumentFragment | null
}>
