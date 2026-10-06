// Application entrypoint, served by Vite (AD-16): Turbo, Stimulus, and the React islands mounted with Turbo Mount.
import "@hotwired/turbo-rails"
import { Application } from "@hotwired/stimulus"
import { registerControllers } from "stimulus-vite-helpers"
import { TurboMount } from "turbo-mount"
import { registerComponent } from "turbo-mount/react"
import { createElement, lazy, Suspense, type ComponentType } from "react"

import RevealErrorBoundary from "../components/RevealErrorBoundary"
import type { PackRevealProps } from "../components/PackReveal"

const application = Application.start()
registerControllers(application, import.meta.glob("../controllers/**/*_controller.ts", { eager: true }))

const turboMount = new TurboMount({ application })
// Turbo Mount types components as taking no props; the props arrive as JSON written by Rails,
// so each island's own props type is the contract, checked inside the component.
const island = <P>(component: ComponentType<P>) => component as ComponentType

// The pack reveal (AD-16), mounted once right after an opening: its code
// loads on that page only.
const PackReveal = lazy(() => import("../components/PackReveal"))
const LazyPackReveal = (props: PackRevealProps) =>
  createElement(RevealErrorBoundary, { strings: props.strings }, createElement(Suspense, { fallback: null }, createElement(PackReveal, props)))
registerComponent(turboMount, "PackReveal", island(LazyPackReveal))
