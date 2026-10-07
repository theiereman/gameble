// Application entrypoint, served by Vite (AD-16): Turbo, Stimulus, and the React islands mounted with Turbo Mount.
import "@hotwired/turbo-rails"
import { Application } from "@hotwired/stimulus"
import { registerControllers } from "stimulus-vite-helpers"
import { TurboMount } from "turbo-mount"
import { registerComponent } from "turbo-mount/react"
import { createElement, lazy, Suspense, type ComponentType } from "react"

import BoosterErrorBoundary from "../components/BoosterErrorBoundary"
import type { BoosterProps } from "../components/Booster"
import TradeBoard from "../components/TradeBoard"

const application = Application.start()
registerControllers(application, import.meta.glob("../controllers/**/*_controller.ts", { eager: true }))

const turboMount = new TurboMount({ application })
// Turbo Mount types components as taking no props; the props arrive as JSON written by Rails,
// so each island's own props type is the contract, checked inside the component.
const island = <P>(component: ComponentType<P>) => component as ComponentType

// The booster island (AD-16), on the booster screen only: its code loads
// on that page alone; the boundary, loaded here, survives a failed chunk.
const Booster = lazy(() => import("../components/Booster"))
const LazyBooster = (props: BoosterProps) =>
  createElement(BoosterErrorBoundary, { strings: props.strings }, createElement(Suspense, { fallback: null }, createElement(Booster, props)))
registerComponent(turboMount, "Booster", island(LazyBooster))

// Loaded eagerly: it replaces the server's fallback fields without an empty frame.
registerComponent(turboMount, "TradeBoard", island(TradeBoard))
