# Review — versions and fit of what the 2026-10-05 update relies on

Independent reviewer, 2026-10-05. Lens: is every committed decision checked against reality (registries, installed code, vendor docs), not asserted from memory? Scope: the 2026-10-05 update (AD-13 per-player streams, AD-17 worker filter, AD-18 plurals, AD-27 layout, motion, CSP and browsers) and the Stack table compared with `Gemfile.lock`, `package.json` and `package-lock.json`. The spine was not edited.

**Verdict:** The versions are right: every pinned row matches the lockfiles and is still the latest release. Of the browser features added on 2026-10-05, three were checked (Turbo View Transitions, OffscreenCanvas in workers, allow_browser) and they hold. The rest were taken on trust. Checking them found two high findings in AD-13 that the installed defaults would break, and several rules that the spine needs to state.

Method: I ran registry API queries on 2026-10-05, read the installed gem and npm sources (`turbo-rails 2.0.23`, `@hotwired/turbo 8.0.23`, `vite_rails 3.11.1`, `actionpack/actionview/activejob 8.1.4`, `solid_cable 4.1.0`), ran `rails runner` and `node` probes in the repo, and did web and MDN lookups. Sources are given on each finding.

---

## High

### H1 — The per-player signed stream puts the player's database id in the HTML (AD-13 vs AD-15)

- **Evidence:** In turbo-rails 2.0.23, `Turbo::Streams::StreamName#stream_name_from` uses `streamable.to_gid_param`, and `signed_stream_name` *signs* that value with `MessageVerifier`. It does not encrypt it. I ran this in the repo:
  `Turbo::StreamsChannel.signed_stream_name(Accounts::Player.first)` gives `IloybGtPaTh2…--841f…`, which base64-decodes to `gid://gameble/Accounts::Player/1`.
  So `turbo_stream_from current_player`, the idiomatic way to write AD-13's "one private Turbo Stream with a signed name", puts the bigint id into every page. AD-15 says "Database ids never appear in URLs, HTML or JSON."
- The signature also never expires. Only rotating `secret_key_base` revokes it. The repo has no `app/channels/application_cable/connection.rb`, so the cable connection does not identify the player. As a result, a ban (AD-14: "a ban that takes effect late") does not close a subscription that is already open.
- Source: installed `turbo-rails-2.0.23/app/channels/turbo/streams/stream_name.rb` lines 12-30; https://rubydoc.info/github/hotwired/turbo-rails/Turbo/Streams/StreamName
- **Fix (amend AD-13):** "The private stream is named from an opaque random per-player stream key held in `Accounts`, never from a record or GlobalID. The key is rotated on ban and on deletion. The Action Cable connection identifies the player from the session cookie and refuses a banned player." In code, use `turbo_stream_from :player, current_player.stream_key` and broadcast to the same pair.

### H2 — Broadcast jobs enqueued inside the transaction escape it (AD-10 + AD-13 with a separate queue database)

- **Evidence:** AD-10 runs handlers inside the operation's transaction. AD-13 says broadcasts "are sent by a job, never inside a transaction". AD-21 puts Solid Queue in its own `queue` database, so a `perform_later` inside the primary transaction commits to the queue database at once. The job can then run before the primary commits and read stale rows, or broadcast a state that was rolled back.
- I probed the repo at runtime: `ActiveJob::Base.enqueue_after_transaction_commit` is `false`, and `Turbo::Streams::BroadcastStreamJob.enqueue_after_transaction_commit` is `false`. The class attribute defaults to `false` in `activejob-8.1.4/lib/active_job/enqueuing.rb:23`, and `config/application.rb` does not override it. `broadcast_*_later_to` enqueues `Turbo::Streams::*Job`, which inherits `ActiveJob::Base`, not `ApplicationJob`.
- The code already works around this in one place: `packs/game/app/handlers/game/handlers/season_published.rb` wraps its enqueue in `ActiveRecord.after_all_transactions_commit`. The spine does not make that a rule.
- **Fix (amend AD-13):** "Jobs are enqueued after commit." Set `config.active_job.enqueue_after_transaction_commit = true` in `config/application.rb`. It applies to `ActiveJob::Base`, so Turbo's broadcast jobs are covered too. Add a test asserting that a rolled-back operation enqueues nothing.

---

## Medium

### M1 — Script nonces give no protection on Turbo Drive renders (AD-27 CSP)

- **Evidence:** In `@hotwired/turbo 8.0.23`, `activateScriptElement` creates every re-executed `<script>` with `createdScriptElement.nonce = getCspNonce()`, which reads the page's `csp-nonce` meta. It does this whether or not the server-rendered script carried a nonce (`node_modules/@hotwired/turbo/dist/turbo.es2017-esm.js:214-228`). An injected inline script on a page reached by Turbo Drive therefore runs. This is reported and still open as of August 2026 (hotwired/turbo#1431, turbo-rails#757): https://discuss.hotwired.dev/t/csp-nonce-enforcement-bypassed-on-turbo-drive-navigation-security-relevant/6569
- Turbo Drive also keeps the first document's CSP, so the nonce must stay the same for the whole session. That is why the Rails 8.1 template uses `request.session.id`. `reset_session` at sign-out rotates the nonce, and inline elements rendered after a Turbo-followed sign-out redirect are then blocked.
- **Fix (amend AD-27):**
  - "No inline `<script>` in views or components. In production, `script-src 'self'` has no nonce, and nonces apply to `style-src` only. Turbo's progress-bar `<style>` needs one."
  - "Sign-out and sign-in are full page loads (`data-turbo="false"`)."
  - Keep a script nonce only in development, for `vite_react_refresh_tag`. vite_rails 3.11.1 adds `nonce: true` itself.

### M2 — Nonce rules break the Vite dev server unless written for it (AD-27 CSP, dev)

- **Evidence:**
  - Vite reads its nonce from `<meta property="csp-nonce" nonce="…">` for the `<style>` tags it injects (CSS imported from TS modules, the error overlay). Rails' `csp_meta_tag` emits `<meta name="csp-nonce" content="…">`, which Vite does not read. Source: https://github.com/vitejs/vite/pull/16052
  - In CSP Level 2 and later, `'unsafe-inline'` is ignored when the same directive holds a nonce. The Rails template's dev fallback (`style_src … :unsafe_inline`) therefore stops working as soon as `style-src` is in `content_security_policy_nonce_directives`.
  - The HMR websocket goes straight to `ws://localhost:3036` and needs `connect-src` in development.
  - `config/initializers/content_security_policy.rb` is still the commented template.
- **Fix:** Add to AD-27, or to the CSP story: "In development, `style-src` carries no nonce and allows `'unsafe-inline'`, `script-src` adds `'unsafe-eval'` and the Vite host, and `connect-src` adds `ws://#{ViteRuby.config.host_with_port}`." The alternative is to render `<meta property="csp-nonce" nonce="<%= content_security_policy_nonce %>">` in the layout. Test the report-only policy in development before production.

### M3 — Nonce-only `style-src` blocks `style="…"` attributes, including in server-rendered faces placed in islands (AD-16 + AD-27)

- **Evidence:** A nonce cannot authorise an inline style *attribute*. Only `style-src-attr` or `'unsafe-inline'` can. AD-16 puts server-rendered card faces into the booster island as HTML, so any per-card `style="--tier: …"` in the face component is blocked when enforcement starts. React `style={{…}}` props are not affected, because they go through the CSSOM: `app/frontend/components/RevealCard.tsx:100` is fine. There is no `style=` in `app/views` or `app/components` today.
- **Fix (one line in AD-27):** "Server-rendered HTML carries no `style` attribute. Per-element values are classes or `data-*` attributes applied through the CSSOM by Stimulus." Alternatively, state `style-src-attr 'unsafe-inline'` explicitly. It is low risk, but it is a choice the spine should make.

### M4 — Turbo Frame navigations get no View Transition, so phone sub-views animate one way only (AD-27)

- **Evidence:** In Turbo 8.0.23, only `PageView` renders go through `ViewTransitioner.renderChange` (source lines 3845-3866 and 4262). `FrameRenderer` does not, even with `data-turbo-action="advance"`. The handbook describes transitions only for page visits: https://turbo.hotwired.dev/handbook/drive
- Opening a sub-view (a frame with `advance`) therefore swaps instantly. Browser Back is a page-level restoration visit, so it *does* transition, with `data-turbo-visit-direction="back"`. The memlog's "sub-views slide over their screen" is not delivered by the meta tag alone.
- Pattern used by others: https://symfonycasts.com/screencast/last-stack/view-transitions
- **Fix (amend AD-27):** "Sub-view motion is one Stimulus controller that wraps `turbo:before-frame-render` in `document.startViewTransition` when it is available and motion is allowed. Every URL a frame advances to renders the full page on its own, for reload, deep link and a restoration that misses the cache."

### M5 — The in-app "Animations réduites" preference does not stop Turbo's View Transitions (AD-27)

- **Evidence:** Turbo turns transitions off only for the *system* setting: `prefersViewTransitions` checks `!window.matchMedia("(prefers-reduced-motion: reduce)").matches` (source line 3826). The player preference stored in `Accounts` or the signed-out cookie (AD-27) is invisible to it.
- **Fix:** "The layout renders the `view-transition` meta only when the player's motion preference allows it." Turbo needs the meta on both pages, so leaving it off disables transitions cleanly.

### M6 — `Intl.PluralRules` and Rails I18n disagree on French plurals (AD-18)

- **Evidence:** I ran these in the repo on 2026-10-05.
  - Node: `new Intl.PluralRules("fr")` gives `0 → one`, `1 → one`, `1.5 → one`, `2 → other`, `1000000 → many`.
  - Rails: the default `I18n::Backend::Simple` returns `other` for `count: 0` under `:fr`.
  - So the server writes "0 cartes" and an island writes "0 carte". A million picks a `many` key that AD-18's `one`/`other` maps do not have, so the result is undefined text.
  - French has had the `many` category since CLDR 38: https://www.unicode.org/cldr/charts/49/verify/numbers/fr.html
  - Separately, `(1234).toLocaleString("fr")` groups with U+202F, and AD-18 requires U+00A0.
- **Fix (amend AD-18):**
  - "`t()` falls back to `other` for any category missing from the map."
  - "Server and islands use the same French rule." Either add rails-i18n's French pluralization on the server, so that 0 and 1 are `one`, or make `t()` follow Rails' rule.
  - "Numbers are formatted by one shared helper that inserts U+00A0, never by `toLocaleString`/`Intl.NumberFormat` output as is."

### M7 — "Supported browsers are `allow_browser :modern`" is not true of the pages that show art (AD-27, AD-17)

- **Evidence:** `ApplicationController` uses `allow_browser versions: :modern, unless: :public_read?`, and `PublicRead` skips the check on every GET and HEAD to cards, public profiles and the library. That is on purpose, for link previews and older browsers. These pages draw card art through the worker filter, so a browser below Safari 17.2, Chrome 120 or Firefox 121 (the `:modern` set, `actionpack-8.1.4/lib/action_controller/metal/allow_browser.rb:75`) can reach them. `allow_browser` also relies on the User-Agent string.
- **Fix (amend AD-27/AD-17):**
  - "Browser floor: `:modern` for signed-in pages. Public read pages serve any browser."
  - "The filter detects `Worker`, `OffscreenCanvas` and `createImageBitmap` and, if any is missing, draws the cover pixelated with no palette, like the CORS fallback."

---

## Low

### L1 — The no-CORS retry cannot run in the worker; bitmaps need closing (AD-17)

- A `fetch(url, {mode: "no-cors"})` returns an opaque response with no readable body, so the worker cannot decode it. The retry has to be an `<img>` on the main thread, with no `crossorigin` and with `referrerPolicy = "no-referrer"`, drawn with `imageSmoothingEnabled = false` and never read back. The resulting origin-unclean bitmap cannot be quantised.
- MDN: a bitmap from `transferToImageBitmap()` "should be either consumed or closed to avoid resource leaks", and iOS caps total canvas memory. https://developer.mozilla.org/en-US/docs/Web/API/OffscreenCanvas/transferToImageBitmap
- **Fix:** In AD-17 write "retried once on the main thread as an image without CORS". In the filter story, note that the LRU calls `bitmap.close()` on eviction.

### L2 — Manifest `orientation: portrait` is ignored on iOS and in browser tabs (AD-27)

- WebKit does not implement the manifest `orientation` member. Chromium applies it only to an installed app in standalone or fullscreen mode. MDN: "not Baseline… Some browsers might not allow changing the default orientation… in certain display modes." https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/Manifest/Reference/orientation ; https://bugs.webkit.org/show_bug.cgi?id=158205
- The manifest route is still commented out in `config/routes.rb:9`, and the layout's manifest link is commented out too.
- **Fix:** AD-27: "a portrait manifest (honoured by installed Android apps only); the ≤ 480 px column stays usable when a phone is held sideways." Enable `rails/pwa#manifest` in the shell story.

### L3 — `viewport-fit=cover` now matters on Android as well (AD-27)

- Chrome 135 and later on Android draws edge-to-edge. With `viewport-fit=cover`, `env(safe-area-inset-bottom)` keeps fixed bottom bars above the gesture bar. https://developer.chrome.com/docs/css-ui/edge-to-edge
- The current layout meta is `width=device-width,initial-scale=1`, without `viewport-fit`. That is expected until the shell story.
- **Fix:** None for the spine. In the shell story, test the tab bar on iOS Safari *and* Android Chrome.

### L4 — `content-visibility` was recommended upstream but is absent from the spine

- `review-feasibility.md:225` recommends `content-visibility: auto` for off-screen grid cards, and AD-27 does not mention it.
- It is Baseline since September 2024 (Safari 18): https://developer.mozilla.org/en-US/docs/Web/CSS/content-visibility. Safari 17.2-17.x, which is inside `:modern`, ignores it, so it is only an enhancement.
- Pitfalls:
  - Without `contain-intrinsic-size: auto <h>`, scroll restoration jumps.
  - It does not stop `requestAnimationFrame` loops, so AD-27's loop-stopping rule still needs IntersectionObserver.
  - Safari does not paint SVG `<text>` inside a `content-visibility: auto` element: https://adactio.com/journal/21498
- **Fix:** Either add "off-screen grid cards use `content-visibility: auto` with `contain-intrinsic-size: auto`" to AD-27, or leave it to the collection story. No decision is at risk.

### L5 — Steam hosts in the CSP should come from one place (AD-27)

- The worker's `fetch` is governed by `connect-src`, and the `<img>` fallback by `img-src`. `Steam::Cdn::ASSET_BASE` hard-codes `shared.akamai.steamstatic.com`, and feasibility proposes `https://*.steamstatic.com https://steamcdn-a.akamaihd.net`.
- **Fix:** The CSP initializer reads its host list from the `Steam` CDN client's constant, so one list feeds both directives.

### L6 — Rails 8.1 is near the end of its bug-fix window

- Rails 8.1.0 was released 2025-10-22, and 8.1.4 (2026-09-24) is the latest on RubyGems as of today. The memlog notes that bug fixes end in October 2026. Security fixes continue for about another year. https://rubyonrails.org/maintenance
- **Fix:** Add "upgrade to Rails 8.2 when it ships" to Deferred.

---

## Stack table against the lockfiles

**Every pinned row matches exactly.** On the gem side I checked rails 8.1.4, puma 8.0.2, thruster 0.1.26, kamal 2.12.0, solid_queue 1.7.0, solid_cache 1.0.10, solid_cable 4.1.0, mission_control-jobs 1.3.1, turbo-rails 2.0.23, stimulus-rails 1.3.4, view_component 4.15.0, vite_rails 3.11.1, turbo-mount 0.4.4, dry-operation 1.1.0, rails_event_store 3.2.0, packwerk 3.3.1, packs-rails 0.1.0, omniauth 2.1.4, omniauth-openid 2.0.2, omniauth-rails_csrf_protection 2.0.1, rexml 3.4.4, cgi 0.5.2, pundit 2.5.2, friendly_id 5.7.0, pagy 43.6.3, faraday 2.14.4, faraday-retry 2.4.0, strong_migrations 2.8.0, i18n-tasks 1.1.2, http_accept_language 2.1.1, sentry-rails 7.1.0 and rack-attack 6.8.0. On the npm side (package-lock) I checked vite 8.3.2, react and react-dom 19.3.0, typescript 7.0.2, vitest 5.0.3, turbo-mount 0.4.4, @hotwired/turbo-rails 8.0.23, @hotwired/stimulus 3.2.2, @types/react and @types/react-dom 19.3.0, @vitejs/plugin-react 6.1.1 and stimulus-vite-helpers 3.1.0. Ruby 4.0.7 matches `.ruby-version` and the Dockerfile. PostgreSQL 18 matches `postgres:18` in `config/deploy.yml` and CI. The registries on 2026-10-05 still show rails 8.1.4, turbo-rails 2.0.23, vite_rails 3.11.1, solid_cable 4.1.0, @hotwired/turbo 8.0.23, vite 8.3.2 and vite-plugin-ruby 5.2.5 as latest.

**Mismatches and gaps.** AD-20 says "A new dependency is added to the Stack table with its version":

| Item | In the repo | In the Stack table | Fix |
| --- | --- | --- | --- |
| pg | 1.6.3 | missing (it is in the memlog) | add |
| vite-plugin-ruby (npm) | 5.2.5 (`^5.2.5`) | missing | add; vite_rails needs it |
| Node.js | 24.15.0 (`.tool-versions`, Dockerfile) | missing | add; Vite 8 sets a Node floor |
| @hotwired/turbo (npm, transitive) | 8.0.23 | missing | add; AD-27's View Transitions and the nonce behaviour depend on its exact version |
| capybara, selenium-webdriver | unpinned | missing | add; AD-22's end-to-end tests run on them |
| brakeman, bundler-audit, rubocop-rails-omakase | unpinned | missing | add, or say that Rails defaults are not listed |
| propshaft 1.3.2, image_processing 1.14.0, jbuilder; `config.active_storage.service = :local` | present | missing | likely leftovers from the generator. image_processing and Active Storage go against AD-17 ("never stored") and propshaft against Vite as the only asset pipeline. Remove them, or list each with a reason |
| `vite`, `vite-plugin-ruby` | caret ranges in `package.json` | exact versions | pin exactly, like every other entry (the lockfile pins them today) |

**Provenance gap.** The Stack header says browser APIs were "checked on 2026-10-05" for View Transitions and OffscreenCanvas only. The memlog has no `(version)` line for the other features the update relies on: CSP nonces with Vite and Turbo, signed Turbo streams, `Intl.PluralRules`, manifest orientation, `viewport-fit`, `content-visibility`. **Fix:** Add one memlog `(version)` line citing this review.

**Assumption now closed.** The earlier review left "Solid Cable gained batching" unverified. It is true: solid_cable 4.1.0 ships `SolidCable::BatchedBroadcaster` (`writer_batch_size`, `writer_batch_delay`), and `config/cable.yml` already sets both. AD-13's job-side batching is still correct. Mark the memlog assumption resolved.

---

## Confirmed as committed (no action)

- **Turbo View Transitions:** the `<meta name="view-transition" content="same-origin">` meta on both pages and `data-turbo-visit-direction` are in the handbook and in the 8.0.23 source. `startViewTransition` is Baseline since October 2025. Firefox 121-143, which is inside `:modern`, has no support, and Turbo falls back to an instant swap. https://developer.mozilla.org/en-US/docs/Web/API/Document/startViewTransition
- **Frames:** `data-turbo-action="advance"` on frames is documented and works for links inside the frame. Setting `src` from script does not advance the URL. https://turbo.hotwired.dev/reference/attributes
- **Worker APIs:** `OffscreenCanvas` 2D, `createImageBitmap` and `transferToImageBitmap` are in workers, Baseline since March 2023. Safari 16.4 is below the 17.2 floor.
- **Rails 8.1 CSP:** `content_security_policy_nonce_auto` exists (`actionview-8.1.4/lib/action_view/railtie.rb:75-77`). `vite_react_refresh_tag` adds a nonce by default (`vite_rails-3.11.1/lib/vite_rails/tag_helpers.rb:16`).
- **`allow_browser :modern`** in 8.1.4 is `safari 17.2, chrome 120, firefox 121, opera 106, ie false`.
- **`Intl.PluralRules`** has been widely available for years. The concern is semantic (M6), not support.
