---
title: 'The capsule screen opens offline and opening times are measured'
type: 'feature'
ticket: '6'
created: '2026-11-06'
status: 'built'
baseline_revision: 'a63698ffa59630869d5a367e7d1c418827d8a7bd'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
context: ['{project-root}/AGENTS.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Offline, the capsule screen does not open at all (browser error page on the web, the shell's generic error in the apps), although the client can now open its held capsule and confirm later. Nobody knows how long an opening takes on real phones.

**Approach:** A service worker keeps the last booster page the player loaded (per locale) and the assets it uses, serves them when the network fails, and forgets them on sign-out. The booster marks touch, blast and first face, and sends those durations with the reveal POST, which the server writes to its log.

## Boundaries & Constraints

**Always:** Network first for the booster page (`/:locale/booster`, HTML only): a fresh response replaces the cached copy; the cache answers only when the network fails. Cache first for fingerprinted Vite assets the booster page references (under the Vite output path) and the pixel images; nothing else is cached, no other page, no JSON, no POST. The worker is registered from the layout for signed-in players only, on secure origins, and is a static file served at the site root with `Service-Worker-Allowed` not needed (scope `/`). On a page rendered without a signed-in player, the client deletes the worker's caches. The cached page holds the held capsules; the client's confirmation queue (localStorage) skips a capsule already queued, so a cached page never reopens one. Timings: `performance.now()` deltas in milliseconds, integers, three optional fields (`touch_to_blast`, `touch_to_first_face`, `layout`) in the reveal POST body; the server validates them (non-negative integers under 60000, layout in the three known names) and logs one line through `Rails.logger.info`, never stores them, never fails the reveal because of them.

**Never:** No caching of other screens, of the bank JSON, or of any response with `Set-Cookie`. No Swift or Kotlin change (the iOS web view needs app-bound domains to run service workers: leave iOS on its current error screen and record it in Implementation Notes). No new table.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Online visit | signed in, network fine | page from network, copy stored, worker registered | No error expected |
| Offline visit | network fails, copy stored | stored booster page with its assets | none |
| Offline, nothing stored | network fails, no copy | the browser's own failure, as today | none |
| Sign-out | page rendered with no player | caches deleted | errors ignored |
| Timings sent | reveal POST with valid timings | 204 as today, one log line with the values | No error expected |
| Bad timings | negative, too large, non-integer, unknown layout | 204 as today, values dropped from the log | No error expected |

</frozen-after-approval>

## Code Map

- `app/views/pwa/service-worker.js`, `config/routes.rb` (Rails' PWA routes are commented), `app/views/layouts/*.html.erb` -- serve and register the worker; a GET must not write (it only serves a static file).
- `app/frontend/entrypoints/` and `app/frontend/lib/` -- a small registration module (TypeScript, tested with injected `navigator.serviceWorker`/`caches`); the worker file itself can stay plain JS served by Rails.
- `vite.config.ts`, `config/vite.json` -- where fingerprinted assets live (the worker matches that path prefix).
- `app/frontend/lib/reveal.ts` (`sendReveal`), `app/frontend/lib/booster_reflect.ts` (`recordReveal`), `app/frontend/lib/booster_opening_sequence.ts` (touch and blast moments), `app/frontend/lib/booster_reveal.ts` (first face) -- timings.
- `app/controllers/pack_reveals_controller.rb` -- read and log the timings.
- `app/frontend/lib/opening_queue.ts` -- the opening confirmation queue in localStorage (`QUEUE_STORAGE_KEY`); clear it with the caches on a page rendered without a signed-in player (deferred finding of the previous stories: the queue is not tied to a player).
- Tests: vitest for registration and timings; `test/controllers/pack_reveals_controller_test.rb`; a request test that `/service-worker.js` is served with a JavaScript content type.

## Tasks & Acceptance

**Execution:**
- [x] worker, route, registration and sign-out cleanup
- [x] timings in the client and the reveal POST, logged by the server
- [x] tests for every matrix row that can run without a browser; the worker's fetch handler tested as a pure function where possible

**Acceptance Criteria:**
- Given a player who loaded the booster page, when the network is gone, then reopening it shows the stored page with its held capsule.

## Verification

Ruby runs through `/tmp/claude-0/-home-user-gameble/f1501461-4159-5967-b2df-065d6bef55e8/scratchpad/rb '<command>'`.

**Commands:**
- `npm run test:js && npm run typecheck && npm run format:check` -- expected: green
- `/tmp/claude-0/-home-user-gameble/f1501461-4159-5967-b2df-065d6bef55e8/scratchpad/rb 'bin/rails test'` -- expected: green
- `script/check_file_sizes && script/check_planning_references` -- expected: clean

## Implementation Notes

- iOS: WKWebView runs service workers only for app-bound domains, so the iOS app keeps its current error screen offline; no Swift or Kotlin change was made. Android's web view and browsers get the worker.
- The worker (`app/views/pwa/service-worker.js`, served by `ServiceWorkersController#show` (public, `ServiceWorkerPolicy`) at `/service-worker.js`) learns the Vite output path from its `?assets=` query, set by the client from `import.meta.env.BASE_URL`; it caches only `<base>assets/<name>-<8-char hash>.<ext>`, so the dev server's unfingerprinted files are never cached.
- Only `/:locale/booster` without a query is stored; any booster address falls back to that copy offline. Assets are stored when the stored page or its stylesheets reference them, or when a booster page fetches them. The asset cache is never pruned: superseded fingerprints stay until sign-out.
- The layout names the worker in `<meta name="service-worker">` for signed-in players; on each `turbo:load` of a page the server just rendered (not a preview, not a Back restoration of a snapshot) the client registers it, or, without that meta, unregisters it and deletes the `gameble-booster-*` caches, the opening queue and the opened-capsule memory.
- The page asks the worker to store the booster page (a `store-booster` message, fetched network first with `Accept: text/html` and stored under the same rules as navigations) once the worker is ready on the booster page, so the first visit is kept, and again on `gameble:booster-changed`, dispatched after each landed opening confirmation and each successful bank read, so the copy follows openings.
- The "no response with `Set-Cookie`" rule cannot be checked by a worker: `Set-Cookie` is a forbidden response header, never visible to script. It holds anyway, because a response served by a service worker never sets cookies, so a stored page cannot replay one.
- The queue skip alone does not cover a capsule confirmed after the stored copy was taken (it leaves the queue once confirmed, and opening posts JSON, so the copy is not refreshed). The client now also remembers the last eight confirmed tokens (`gameble:opened-capsules`, `rememberOpened`/`loadOpened` in `opening_queue.ts`) and skips them like queued ones when the screen starts; they are forgotten with the queue on a page without a signed-in player. A capsule whose confirmation was refused is not remembered.
- System tests run on 127.0.0.1, a secure origin, so the worker registers there too; they were not run here (no browser driver).
- Timings: the touch time is taken when the capsule is touched but written to the state only once the previous hand is put away (so its owed reveal keeps its own timings), blast when the cards start to deal, first face at the earliest card mark. Held capsules carry their timings in the owed reveal sent after confirmation. The server logs `Booster opening timings: mode=... touch_to_blast=... touch_to_first_face=... layout=...` only when at least one duration is valid.

## Review Triage Log

Pass 1 (quick): 1 high, 3 medium, 2 low.

- high, patch — a Turbo restoration of the capsule screen ran the offline restore path and wiped the opening queue: restore and preview are now skipped on a page that was freshly rendered.
- medium, patch — the first visit stored nothing and the stored copy went stale after an opening: the page now asks the worker to store it (`store-booster`) on load and on every booster change.
- medium, patch — the frozen rule to skip storing a response that sets a cookie could never hold, since the worker cannot read Set-Cookie: the check is removed and the deviation noted under Implementation Notes.
- medium, patch — the worker script was served without a Pundit policy: it now comes from its own controller with a policy.
- low, patch — the worker and its caches outlived a sign-out: a signed-out page unregisters it and clears the caches, the queue and the opened-capsule memory.
- low, rejected — `firstFaceAt` is measured from the first face drawn, not the first face visible on screen: close enough to compare openings, which is what the log is for.
