---
title: 'Open every capsule from one thumb'
type: 'feature'
ticket: '6'
created: '2026-11-03'
status: 'built'
baseline_revision: '92d15445a3c9770a0d6de28ea3d112c4efca9892'
route: 'full'
route_source: 'auto'
review: 'none'
review_source: 'pinned'
lenses_ran: []
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['oversized']
deferred:
  - summary: collecting the daily capsule right after the last standard capsule (hand still dealt) keeps the empty standard tab selected
    location: app/frontend/lib/booster_reserve.ts dailyCapsuleChosen
    severity: low
  - summary: warming the next capsule's art before the player presses the button waits on the author (it would send an unopened capsule's cards to the browser)
    location: app/frontend/lib/booster_opening_sequence.ts
    severity: low
---

<intent-contract>

## Intent

**Problem:** A signed-in player opening gameble lands on the hub, collects the daily capsule from a hub panel, and has no way to cut the opening animation short; the next capsule's request only starts once the previous hand has sunk away.

**Approach:** The capsule screen becomes where a signed-in player arrives (bare root, PWA start, sign-in without a specific origin), with the hub still reached from the G button. The capsule screen gains a ready daily slot collected with one tap that preselects the daily capsule when the standard reserve is empty. The primary button reads "Skip" while a capsule opens and finishes the animation at once. "Open the next one" sends the next opening while the current hand sinks away. The existing chaining button, preselection and end-of-capsule hand stay as they are and are pinned by tests.

## Boundaries & Constraints

**Always:** server-rendered ERB; every string in en.yml and fr.yml; Pundit on every action; the daily collect goes through `Game::CollectDailyBonus` behind its existing POST; a GET never writes; reduced motion keeps its fade path; booster TypeScript changes live in `app/frontend/lib/booster_*.ts` with vitest coverage; file size limits (400 TS/Ruby, 500 CSS); no `style` attributes; no planning ids.

**Decisions (agent, conservative, recorded in pending-approvals):** the hub stays at `/:locale` and the G button; a player whose welcome is still pending lands on the hub so the welcome dialog shows; a passive capsule arrival still leaves the selected tab unchanged (EXPERIENCE rule), only the daily collect switches to the special tab; the next capsule's cards are never sent before its opening (no peeking at an unopened capsule), so the warming is the overlapped request.

**Never:** the bottom sheet, the empty-reserve proposals (entry 7), removing the hub, filter or list screens, new trade rules, adding tests to `test/system/shell_test.rb`, `test/integration/shell_test.rb` or `test/system/booster_test.rb` (oversize) beyond fixing broken assertions.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Bare root | signed-in player, GET `/` | redirect to `/<locale>/booster` | visitor: unchanged, `/<locale>` |
| Sign-in | origin nil or `/<locale>` | redirect to that locale's booster | welcome pending: the hub, as today; any other origin: unchanged |
| Daily ready | bonus collectable | slot "Daily capsule · Ready" with "Collect" on the capsule screen | collected or no season: no slot |
| Collect | tap "Collect", standard reserve empty | slot leaves, toast, special tab selected and sealed, "Open the capsule" opens it | already collected: alert toast, slot leaves |
| Skip | tap primary during arming/eject/deal | cards dealt at once, focus card 1 as today | reduced motion: same, fade path |
| Chain | 3 capsules, open, reveal all, "Open the next one" ×2 | three distinct packs opened in a row from the same button | refusal: toast as today |

</intent-contract>

## Code Map

- `app/controllers/locales_controller.rb` -- `redirect`: signed-in player → `booster_path(locale:)` unless `welcome_pending`.
- `app/controllers/concerns/opens_player_session.rb:31-37` `redirect_signed_in`, `sessions_controller.rb:39` and `:131 return_path`, `sign_ins_controller.rb:10` -- one helper (e.g. `landing_path_for(player, origin)`) mapping nil or a bare `/<locale>` origin to that locale's booster unless welcome pending. Keep `flash: { signed_in: true }`.
- `app/controllers/boosters_controller.rb` -- `Game::BankSummary.call` (adds `bonus_collectable`) instead of `.reserve`; watch the query budget in `test/controllers/boosters_controller_test.rb`.
- `app/views/boosters/_booster.html.erb` + new `app/views/boosters/_daily.html.erb` -- `#booster-daily` slot (only when `bank[:bonus_collectable]`): title, "Ready", `ButtonComponent` POST `daily_bonus_path`. Collected variant: a hidden element with `data-booster-target="dailyCollected"` (no text).
- `app/views/daily_bonuses/create.turbo_stream.erb` -- add `turbo_stream.replace "booster-daily"` with the collected variant; check whether the booster page carries `#packs-chip` (the booster top bar swaps in a reserve chip) and keep its chip correct. `DailyBonusesController` HTML fallback: `redirect_back_or_to home_path`.
- `app/frontend/controllers/booster_controller.ts` (400 lines, AT the limit) -- add target `dailyCollected` with `dailyCollectedTargetConnected` → `bankRefresh.dailyCollected()`, and action `skip` → `opening.skip()`; free lines by inlining `number()` and the `strings` getter.
- `app/frontend/lib/booster_bank_refresh.ts` -- `dailyCollected()`: `await refresh()` then `apply(dailyCapsuleChosen)`.
- `app/frontend/lib/booster_reserve.ts` (or `booster_state.ts`) -- pure `dailyCapsuleChosen(state)`: when phase is sealed/empty, current reserve count 0 and special > 0, select special (reuse `reserveSelected`).
- `app/frontend/lib/booster_opening_sequence.ts` -- start `sendOpening` before `retract()` (key and reserve captured first); `skip()`: flag + resolve a promise that every sequence wait races, finish running animations under the booster root (`getAnimations({ subtree: true })`), skip `later` shakes when skipping; reset per opening.
- `app/frontend/lib/booster_view.ts` `controls()` + `booster_types.ts` `OpenVariant` -- variant `"skip"` while `phase === "opening"` (enabled, not aria-disabled).
- `app/frontend/controllers/booster_actions_controller.ts` -- `open()` dispatches `skip` when the variant is skip; `app/views/boosters/_actions.html.erb` gains the `data-variant="skip"` label `booster.skip`; `boosters_helper.rb` `BOOSTER_ACTIONS` gains `skip: :skip`; `booster.css:265-268` one selector line (file at 499).
- New CSS for the slot in a new `app/frontend/styles/booster-daily.css`, imported in `app/frontend/entrypoints/application.css`; tap target ≥ 44px.
- Tests to fix: `test/controllers/sessions_controller_test.rb` (314, 335 and other `home_path` landings), `clerk_sessions_controller_test.rb:50,58`, `sign_ins_controller_test.rb:52`, `locales_controller_test.rb`, `pages_controller_test.rb:689`, `test/system/hub_test.rb` (180, 238, 250-292 sign-in focus), `daily_bonuses_controller_test.rb`. Helpers for system tests: `test/support/game_packs.rb` `create_pack`, `SteamSignIn`; copy local helpers from `test/system/booster_screen_test.rb`.

## Tasks & Acceptance

**Execution:**
- [x] controllers above -- capsule screen as landing with the welcome exception -- R2 landing
- [x] booster view, daily partial, turbo stream, booster controller, bank refresh, reserve transition, CSS, locales -- daily slot -- R2 daily
- [x] opening sequence, view controls, actions controller and view, helper, CSS -- skip and overlapped next opening
- [x] `app/frontend/lib/*.test.ts` -- `dailyCapsuleChosen`, `controls()` skip variant, skip resolving waits, request sent before retract
- [x] `test/controllers/*`, `test/integration/capsule_landing_test.rb` (new) -- landing redirects, daily slot on the booster page, turbo stream replaces `booster-daily`
- [x] `test/system/capsule_flow_test.rb` (new) -- chain three capsules with the one button; collect the daily slot then open it; skip; at phone width the end shows all five cards in the tray
- [x] fix the existing assertions listed in the Code Map

**Acceptance Criteria:**
- Given a signed-in player with three capsules, when they press the primary button, reveal all and press it again twice, then three capsules are opened and the button reads "Reserve empty".
- Given a ready daily capsule and an empty standard reserve, when the player taps "Collect" on the capsule screen, then the slot leaves and the primary button opens the daily capsule.
- Given a capsule opening with full motion, when the player presses "Skip", then the cards are dealt at once.
- Given the phone layout, when the last card of a capsule is stored, then the tray shows all its cards.

## Implementation Notes

- New concern `app/controllers/concerns/player_landing.rb` (`landing_path_for(player, origin = nil)`): a nil or bare `/<locale>` origin goes to that locale's booster, or to the hub while the welcome is pending; any other origin is kept. Used by `LocalesController`, `OpensPlayerSession`, `SignInsController` and `SessionsController#create` (a Steam sign-in, which never honoured origins but invites, lands on the booster). `return_path` (a failed sign-in) is unchanged.
- The booster page carries no `#packs-chip` (its top bar uses the reserve chip); that chip follows the refreshed bank through the existing `gameble:bank-changed` event.
- `booster_controller.ts` stays at 400 lines by inlining its `strings`, `number`, `phoneLayout` and `face` helpers; `booster.css` is at 500 lines.
- Existing system tests that signed in and expected the hub now visit the hub after signing in or assert the booster landing (hub, daily bonus, bridge cache, hub return stability, library, live updates, public profile, share card, shell, trades); the hub's focus-on-sign-in tests became landing assertions.
- Review was not run: the author asked for the story to be committed and reported at once (2026-11-03).

## Plan Change Log

## Review Triage Log

## Design Notes

Skip waits: wrap the sequence's waits as `Promise.race([timers.wait(ms), this.skipped])` where `this.skipped` is reset at each `open()`; the network promise is never raced. Warming the next capsule before it is opened would send its cards' covers to the client before the player chose to open it, and `OpenPack` may redraw them; that is left to the author.

## Verification

Results (2026-11-03): `bin/rails test` 4265 runs, 0 failures; `npm run test:js` 844 passing; format, CSS lint, typecheck, file sizes, planning references, markup APIs, rubocop, packwerk, zeitwerk, i18n-tasks and brakeman clean. System tests: the implementer ran `test/system/capsule_flow_test.rb` (green three times in a row) and the full system suite once green before the author asked to drop the system tests; no system test was run after that, at the author's request.


**Commands:**
- `bin/rails test test/controllers test/integration test/helpers` -- expected: pass
- `bin/rails test test/system/capsule_flow_test.rb test/system/daily_bonus_test.rb test/system/hub_test.rb test/system/booster_screen_test.rb test/system/booster_reserves_test.rb` -- expected: pass
- `npm run test:js && npm run format:check && npm run lint:css` -- expected: pass
- `bin/ci`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `script/check_file_sizes`, `script/check_planning_references`, `bundle exec i18n-tasks missing` -- expected: pass

## Code Review

### 2026-11-04 — 0 decision-needed, 0 patch, 4 defer, 3 rejected

- [x] [Review][Defer] The hub's focus-on-sign-in lost its browser test and the daily-collect wiring (BankRefresh.dailyCollected) has no unit test — deferred: add a welcome-pending hub focus test and a BankRefresh vitest, then run the system tests once before release
- [x] [Review][Defer] Skip is ignored while the previous hand sinks away, and finishAnimations finishes every finite animation under the booster root — deferred: behaviour choices, settle on the iPhone pass
- [x] [Review][Defer] The opening request is sent before the retract, so a failure or disposal in between loses the answer — deferred: low odds, check on the iPhone pass
- [x] [Review][Defer] A bare locale origin with a query string lands on the hub instead of the capsule screen — deferred: low, rare sign-in origin

**Rejected**
- Daily collected marker before bankRefresh exists: false, the marker only arrives through a stream after connect.
- French button names in pending-approvals and deferred-work: low, quotes of interface labels.
- Planning ids and plan hygiene, 400/500-line files at the limit, indirect landing logic, redirect_back guard: low or edits the plan.
