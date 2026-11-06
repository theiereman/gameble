---
title: 'The capsule screen opens offline and opening times are measured'
type: 'feature'
ticket: '6'
created: '2026-11-06'
status: 'ready-for-dev'
baseline_revision: ''
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
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
- Tests: vitest for registration and timings; `test/controllers/pack_reveals_controller_test.rb`; a request test that `/service-worker.js` is served with a JavaScript content type.

## Tasks & Acceptance

**Execution:**
- [ ] worker, route, registration and sign-out cleanup
- [ ] timings in the client and the reveal POST, logged by the server
- [ ] tests for every matrix row that can run without a browser; the worker's fetch handler tested as a pure function where possible

**Acceptance Criteria:**
- Given a player who loaded the booster page, when the network is gone, then reopening it shows the stored page with its held capsule.

## Verification

Ruby runs through `/tmp/claude-0/-home-user-gameble/f1501461-4159-5967-b2df-065d6bef55e8/scratchpad/rb '<command>'`.

**Commands:**
- `npm run test:js && npm run typecheck && npm run format:check` -- expected: green
- `/tmp/claude-0/-home-user-gameble/f1501461-4159-5967-b2df-065d6bef55e8/scratchpad/rb 'bin/rails test'` -- expected: green
- `script/check_file_sizes && script/check_planning_references` -- expected: clean
