// Application entrypoint, served by Vite (AD-16): Turbo, Stimulus, and the React islands mounted with Turbo Mount.
import "@hotwired/turbo-rails"
import { Application } from "@hotwired/stimulus"
import { registerControllers } from "stimulus-vite-helpers"
import { TurboMount } from "turbo-mount"
import { registerComponent } from "turbo-mount/react"
import { createElement, lazy, Suspense, type ComponentType } from "react"

import SampleIsland from "../components/SampleIsland"
import type { CardPreviewProps } from "../components/CardPreview"

const application = Application.start()
registerControllers(application, import.meta.glob("../controllers/**/*_controller.ts", { eager: true }))

const turboMount = new TurboMount({ application })
// Turbo Mount types components as taking no props; the props arrive as JSON written by Rails,
// so each island's own props type is the contract, checked inside the component.
const island = <P>(component: ComponentType<P>) => component as ComponentType

registerComponent(turboMount, "SampleIsland", island(SampleIsland))

// The back-office card preview: only its page mounts it, so its code loads
// on demand. A recorded exception to AD-16's two islands.
const CardPreview = lazy(() => import("../components/CardPreview"))
const LazyCardPreview = (props: CardPreviewProps) => createElement(Suspense, { fallback: null }, createElement(CardPreview, props))
registerComponent(turboMount, "CardPreview", island(LazyCardPreview))
