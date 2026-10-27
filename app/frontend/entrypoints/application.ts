// Imported before Turbo so its popstate listener runs before Turbo's own.
import "../lib/bridge_cache_guard"
import "@hotwired/turbo-rails"
import { Application } from "@hotwired/stimulus"
import { registerControllers } from "stimulus-vite-helpers"

import { keepLocaleOnReturn } from "../lib/locale_return"
import { registerStreamActions } from "../lib/stream_actions"
import { rememberTimeZone } from "../lib/time_zone_cookie"

registerStreamActions(window.Turbo)
rememberTimeZone()
keepLocaleOnReturn()

const application = Application.start()
registerControllers(application, import.meta.glob("../controllers/**/*_controller.ts", { eager: true }))
