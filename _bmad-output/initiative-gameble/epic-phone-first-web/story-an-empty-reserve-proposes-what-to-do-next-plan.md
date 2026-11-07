---
title: 'An empty reserve proposes what to do next'
type: 'feature'
ticket: '7'
created: '2026-11-03'
status: done
baseline_revision: '7351a8fe5e0fe6100d20a9eabf874c6805fa2d50'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** When a player has no capsule left, the capsule screen only says "Reserve empty" and a countdown; it leaves the player with nothing to do and no reason to go on to sets, friends or their profile.

**Approach:** With no capsule left (standard and special both zero) and no hand still being played, the capsule screen shows a "what next" panel under the stage, on every layout: three links in order, Sets, Social and Me, each with one live hook when there is data for it (the in-progress set closest to its next tier, a friend holding a card one of the player's goals needs, rewards waiting to be claimed), plus the next daily capsule time once today's daily is collected. The panel is server-rendered: inline when the page loads with an empty reserve, otherwise fetched through a Turbo frame the first time the reserve runs out during the session.

## Boundaries & Constraints

**Always:** server-rendered ERB, no markup built in script; every string in en.yml and fr.yml (French plurals with `zero`); every controller action authorized with Pundit; the frame endpoint is a GET that only reads, through domain queries; the booster root controller drives the panel through an outlet (children never read the state); TypeScript logic for when the panel shows is a pure function in `app/frontend/lib/booster_*.ts` with vitest coverage; no `style` attributes; tap targets at least 44px; no database ids in the markup; file size limits (400 Ruby/TS, 500 CSS); no planning ids.

**Decisions (agent, conservative):** "something new to unlock" is read as achievement rewards waiting to be claimed (`Game::UnclaimedAchievements`), the existing "new" signal; "a friend holding a card you need" uses the first trade suggestion (`Game::TradeSuggestions`, a card a goal needs), so a player without goals or friends gets no social hook; each proposal links to its tab (`library_path`, `social_path`, `me_path`), not to the hooked set, friend or reward; the daily line shows only when today's daily capsule is collected (the ready slot already covers the other case).

**Never:** changing the Sets, Social or Me pages (stories built in parallel); the bell; new trade rules; touching `app/views/boosters/_daily.html.erb`'s behaviour; adding tests to `test/system/booster_test.rb`, `test/system/shell_test.rb` or `test/integration/shell_test.rb` (oversize) beyond fixing broken assertions; computing the hooks on every capsule screen GET when the reserve is not empty.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Load empty | GET booster, standard 0 and special 0 | panel visible with the three proposals and their hooks, inline | no hook data: each proposal shows its title only |
| Load not empty | GET booster, any capsule left | panel hidden, frame empty, no hook query run | — |
| Last capsule | open the last capsule, reveal all (phone: store all) | panel shows under the stage, frame loads `booster/next-steps` | frame fetch fails: panel stays with its heading, no hooks |
| Mid hand | last capsule dealt, cards still face down / on the pile | panel hidden | — |
| Capsule arrives | panel shown, bank refresh brings a capsule | panel hidden; shown again later reloads the frame | — |
| Special only | standard tab selected and empty, special > 0 | panel hidden | — |
| Daily | daily collected today / still ready | line "Next daily capsule: <local time>" / no line | — |
| Frame endpoint | GET outside a frame, or a visitor | redirect to the capsule screen / Pundit refusal as for the booster | — |

</intent-contract>

## Code Map

- `app/domains/game/app/queries/game/` -- new query (e.g. `Game::NextSteps.call(player, season:)`) returning a Data with `closest_set` (the `SetStanding` of `SetBoard.call(...).in_progress` with the smallest `missing`, ties by board order, plus its `Catalog::SetsById` set), `friend` (`TradeSuggestions.call(player).suggestions.first&.player`) and `rewards` (`UnclaimedAchievements.count(player)`). Same logic as `SetBoardLoading#closest_to_next_tier` (`app/controllers/concerns/set_board_loading.rb`).
- `config/routes.rb:38` -- next to `resource :booster`, add the frame route (e.g. `get "booster/next-steps"`, named `booster_next_steps`).
- New controller for the frame (or an action on `BoostersController`, `app/controllers/boosters_controller.rb`) -- `authorize :booster, :next_steps?`; redirect to `booster_path` unless `turbo_frame_request?` (pattern: `LibraryController#in_progress`); loads the query and `Game::BankSummary.call`. `app/policies/booster_policy.rb` gains `next_steps? = player?`.
- `app/views/boosters/_booster.html.erb` -- render a new `boosters/_next_steps` partial after `booster__phone-actions`: a `section.booster-next-steps` with `data-controller="booster-next-steps"`, `hidden` unless the reserve is empty and no opened pack is shown, holding `turbo_frame_tag "booster-next-steps-frame", target: "_top"`; its content (a new `_next_steps_list` partial) inline only when shown at load. `BoostersController#show` loads the query only in that case.
- The proposals partial -- heading, optional daily line (`local_time_sentence(bank[:next_bonus_at])`, pattern in `app/views/pages/_daily_booster.html.erb:13`), and three links with `pixel_icon("tab-sets" | "tab-social" | "tab-me")`, a title and an optional hook. Set hook: `SetLabel.for(set)` with `GoalsHelper#goal_next_words(standing)` (`app/helpers/goals_helper.rb:57`, private, reachable from views/helpers); friend name: `friend_name(player)` (`app/helpers/friends_helper.rb`).
- `app/helpers/boosters_helper.rb:5` -- add `booster-next-steps` to `BOOSTER_CHILDREN` so the root gets the outlet.
- New `app/frontend/controllers/booster_next_steps_controller.ts` -- `static targets = ["frame"]`, `static values = { url: String }`, `render({ shown })`: no-op when unchanged; else toggles `element.hidden`, and on show sets the frame's `src` to the url or calls `reload()` when it already has it (pattern: `app/frontend/controllers/poller_controller.ts`).
- `app/frontend/controllers/booster_controller.ts` (400 lines, AT the limit) -- add the `booster-next-steps` outlet (static list, `has…`/`…Outlet` declares, `…OutletConnected = () => this.render()`); free lines first by moving `announce()` and `ANNOUNCEMENTS_KEPT` into a small lib function.
- `app/frontend/lib/booster_outlet_access.ts` (`OutletSource`, `outletsOf`) and `app/frontend/lib/booster_render_host.ts` (`BoosterOutlets`) -- add `nextSteps`.
- `app/frontend/lib/booster_render.ts` (347 lines) -- `render()` calls the outlet with `{ shown: nextStepsShown(state) }`.
- `app/frontend/lib/booster_view.ts` (or `booster_state.ts`) -- pure `nextStepsShown(state)`: `bank.available + bank.special === 0` and (`phase === "empty"` or (`phase === "dealt"` and `handDone(state)` from `booster_rules.ts:61`)).
- New CSS file `app/frontend/styles/booster-next-steps.css`, imported in `app/frontend/entrypoints/application.css` next to `booster-daily.css` (do not grow `booster.css`, at 500): `grid-column: 1 / -1` like `.booster-daily`; on the empty phase with the panel shown, lower the stage's min-height (`.booster[data-phase="empty"]:has(.booster-next-steps:not([hidden]))`) so the panel sits under the "Reserve empty" line on a phone.
- Locales `config/locales/en.yml` / `fr.yml` under `booster.next_steps` (title, daily line, three titles, set hook, friend hook, rewards hook with one/other and French zero/one/other).
- Tests: `test/system/capsule_flow_test.rb` (58 lines, helpers `create_pack`, `sign_in_to_capsules`, `reduce_motion`), `test/controllers/boosters_controller_test.rb`, `app/frontend/lib/*.test.ts`. Test data: goals/friends fixtures as in `test/controllers/trades_controller_test.rb` suggestions tests and `test/domains/game/trade_suggestions_test.rb` and `set_board_test.rb`; policy tests live in `test/policies/`.

## Tasks & Acceptance

**Execution:**
- [x] `app/domains/game/app/queries/game/next_steps.rb` + `test/domains/game/next_steps_test.rb` -- the three hooks in one read -- keeps the controller to one query call
- [x] routes, policy, frame controller/action, `BoostersController#show`, views, helper constant -- server side of the panel -- R2 empty state
- [x] `booster_next_steps_controller.ts`, outlet wiring, `booster_render.ts`, `nextStepsShown` -- panel shown and loaded when the reserve runs out
- [x] CSS file and import -- full-width panel, 44px links, stage lowered on an empty phase
- [x] locales en/fr
- [x] `app/frontend/lib/*.test.ts` -- `nextStepsShown` across the matrix rows (empty, special only, mid hand, phone stored, desktop revealed, opening)
- [x] `test/controllers/` -- inline panel with hooks when empty, no panel content when not empty, frame endpoint renders the frame and redirects outside a frame
- [x] `test/system/capsule_flow_test.rb` -- empty reserve at phone width and at desktop width shows the three proposals leading to Sets, Social and Me; opening the last capsule and revealing it shows the panel loaded through the frame

**Acceptance Criteria:**
- Given a player with no capsule, a set two cards from its next tier, a goal whose card a friend spares, and a reward to claim, when they open the capsule screen at 390x844, then they see the three proposals in order with "2 more for …", the friend's name and "1 reward to claim", and each leads to Sets, Social and Me.
- Given the same player on a 1280-wide window, then the same panel shows.
- Given a player with one capsule, when they open it and reveal every card, then the panel appears without a page reload.
- Given a player with no set in progress, no goal and no reward, then the three proposals show without hooks.

## Implementation Notes

- **Query:** `Game::NextSteps.call(player, season:)` returns `Steps(closest_set, friend, rewards)`; `closest_set` is a `ClosestSet(set, standing)`, picked like `SetBoardLoading#closest_to_next_tier` (smallest `missing`, ties by board order) among the in-progress standings whose set `Catalog::SetsById` finds, in one `SetsById` read.
- **Frame endpoint:** a separate `BoosterNextStepsController#show` (`get "booster/next-steps"`, `booster_next_steps`), `authorize :booster, :next_steps?`, redirect to `booster_path` outside a frame; it reads `Game::BankSummary` and `Game::NextSteps`. `BoostersController#show` calls `Game::NextSteps` only when `available` and `special` are both zero and no opened pack is shown (`reserve_run_out?`).
- **Markup split:** the heading sits in `boosters/_next_steps` outside the frame, and the daily line and the three links in `boosters/_next_steps_list` inside it. That way a frame fetch that fails leaves the heading (matrix row "Last capsule"), and the frame stays empty when the reserve is not (matrix row "Load not empty"). The plan's code map put the heading in the proposals partial; the matrix won. On `turbo:frame-missing`, the child controller calls `preventDefault()` so Turbo does not write "Content missing" into the panel.
- **Hooks:** they are built in a new `BoosterNextStepsHelper#booster_next_steps`. Set hook: `"%{set} · %{next}"` with `SetLabel.for` and `GoalsHelper#goal_next_words` (for example "Roguelike · 2 more for Bronze"). Friend hook: "%{name} has a card one of your goals needs". Rewards hook: plural with a French `zero` form. Titles are "Your sets", "Your friends", "Your profile" ("Vos sets", "Vos amis", "Votre profil"); the heading is "What next?" ("Et maintenant ?").
- **Frontend:** `booster_next_steps_controller.ts` reads its starting `shown` from `element.hidden`, so a panel rendered inline does not fetch again on the first render. When it goes from hidden to shown, it sets the frame's `src`, or calls `reload()` when `src` already equals the url. `nextStepsShown` lives in `booster_view.ts` as designed. `booster_controller.ts` was at 400 lines: `announce()` and `ANNOUNCEMENTS_KEPT` moved to `lib/booster_live.ts` (`announceIn`), and the file is now 399 lines with the new outlet. `booster_render.ts` is 349 lines.
- **CSS:** new `booster-next-steps.css`, imported after `booster-daily.css`. The panel spans `grid-column: 1 / -1`, and the links are at least `--space-touch-min` high, in an `auto-fit` grid (three across on a desktop, stacked on a phone). On an empty phase with the panel shown, the stage and shake min-heights drop to 0 and the shake row to `minmax(200px, auto)`. Checked by screenshots at 390x844 and 1280 wide (since removed). On a desktop the panel still sits below the info column, which is taller than the empty stage.
- **Tests:**
  - `test/domains/game/next_steps_test.rb` (4).
  - `test/controllers/booster_next_steps_controller_test.rb` (7): inline panel with hooks, no hooks, daily line, panel hidden with no hook SQL when a capsule is left, frame, redirect outside a frame, visitor refused. It is a new file because `boosters_controller_test.rb` is already 401 lines.
  - `test/policies/booster_policy_test.rb` (new).
  - `app/frontend/lib/booster_next_steps.test.ts` (5).
  - Two system tests in `test/system/capsule_flow_test.rb`.
- **Panel DOM logic:** after the implementation, the hidden-to-shown switch and the frame load moved from the child controller into `lib/booster_next_steps_panel.ts` (`showNextSteps`), so the matrix rows "Capsule arrives" (hide, then reload on the next show) and the rendered-at-load case are covered by a happy-dom vitest (`booster_next_steps_panel.test.ts`). The failed-fetch row holds by structure: the heading sits outside the frame, and `turbo:frame-missing` is prevented.
- **Hooks reading (2026-11-03):** the orchestrating session accepted the reading in the Decisions above (rewards to claim, first trade suggestion, links to the tabs); the author has not yet confirmed it.
- **Surprise:** the parallel Rails run needs `PARALLEL_WORKERS=1` against the single prepared worktree database. The per-worker databases have no schema.
- **Verification run:** `test/controllers test/integration test/domains test/helpers test/policies` ran 3528 tests. Postgres went into recovery mode partway through, and 215 tests raised connection errors (no assertion failures). The 15 files involved were rerun on their own: 221 runs, 0 failures. The system tests `capsule_flow_test.rb` and `booster_reserves_test.rb` pass, as do vitest (826), typecheck, prettier, stylelint, rubocop, packwerk, `i18n-tasks missing`, zeitwerk, brakeman, `check_markup_apis`, `check_planning_references` and `check_file_sizes`. `bin/ci` itself was not run, because it drops and recreates the test database.

## Plan Change Log

## Review Triage Log

### 2026-11-03 — Review pass
- verdicts: 3 findings — high 0, medium 0, low 3, false 0, maybe-false 0
- findings:
  - `[low]` `[patch]` `showNextSteps` compared the frame's `src` with the relative url, but Turbo rewrites `src` to the response's absolute url after a load, so the `reload()` branch never ran in a browser (the panel still refetched through the `src` branch, and the vitest described a path the browser never takes) — compared both as absolute urls (`new URL(…, document.baseURI)`); added vitest cases for an absolute `src` (reload) and a `src` left on another page by a redirect (asks for the proposals again).
  - `[low]` `[patch]` the "opening" row of `nextStepsShown` was only tested before the answer, when the bank still held a capsule, so the phase check was never what kept the panel hidden — added the answered-but-still-opening state (bank at zero, phase `opening`) to `booster_next_steps.test.ts`.
  - `[low]` `[patch]` the "no hook read" controller test grepped only the set-board SQL, so the trade-suggestion hook could run on a non-empty GET unnoticed — the recorder now keeps each query's name and the test also refuses `Game::TradeSuggestions` and `game_goals` queries (the rewards count stays out: the tab bar's badge reads it on every page).

## Design Notes

The hooks run up to a dozen queries (`TradeSuggestions` alone several); loading them on every capsule screen GET would tax the screen players open most, so they run only when the panel is due: inline when the page opens on an empty reserve, through the frame otherwise. Turbo's lazy loading cannot be relied on here (a `hidden` frame never intersects, and a visible one below the fold would wait for a scroll), hence the outlet setting `src` on show.

```ts
export const nextStepsShown = (state: BoosterState): boolean =>
  state.bank.available + state.bank.special === 0 &&
  (state.phase === "empty" || (state.phase === "dealt" && handDone(state)))
```

## Verification

**Commands:**
- `bin/rails test test/controllers test/integration test/domains test/helpers` -- expected: pass
- `bin/rails test test/system/capsule_flow_test.rb test/system/booster_reserves_test.rb` -- expected: pass
- `npm run test:js && npm run format:check && npm run lint:css` -- expected: pass
- `bin/ci`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `script/check_file_sizes`, `script/check_planning_references`, `bundle exec i18n-tasks missing` -- expected: pass

## Auto Run Result

**Summary:** with standard and special reserves both empty and no hand left to play, the capsule screen shows "What next?" under the stage on every layout: Sets, Social and Me in that order, each with its hook when there is data (the in-progress set closest to its next tier, a friend sparing a card a goal needs, rewards to claim), and the next daily capsule time once today's daily is collected. Rendered inline when the screen opens on an empty reserve; otherwise loaded through a Turbo frame (`GET /:locale/booster/next-steps`) the first time the reserve runs out, and reloaded each time it is shown again.

**Files changed:**
- `app/domains/game/app/queries/game/next_steps.rb` -- the three hooks in one read.
- `app/controllers/booster_next_steps_controller.rb`, `config/routes.rb`, `app/policies/booster_policy.rb` -- the frame endpoint and its policy.
- `app/controllers/boosters_controller.rb`, `app/views/boosters/show.html.erb`, `_booster.html.erb` -- hooks read only when the screen opens on an empty reserve.
- `app/views/boosters/_next_steps.html.erb`, `_next_steps_list.html.erb`, `app/views/booster_next_steps/show.html.erb`, `app/helpers/booster_next_steps_helper.rb` -- the panel, its proposals and hooks.
- `app/helpers/boosters_helper.rb`, `app/frontend/controllers/booster_controller.ts`, `booster_next_steps_controller.ts`, `lib/booster_outlet_access.ts`, `lib/booster_render_host.ts`, `lib/booster_render.ts` -- the new outlet, driven by the root.
- `app/frontend/lib/booster_view.ts` (`nextStepsShown`), `lib/booster_next_steps_panel.ts` (`showNextSteps`), `lib/booster_live.ts` (announcements moved out of the root controller, kept at 399 lines).
- `app/frontend/styles/booster-next-steps.css`, `entrypoints/application.css` -- the panel and the lowered empty stage.
- `config/locales/en.yml`, `fr.yml` -- copy, French plural with `zero`, narrow no-break spaces.
- Tests: `test/domains/game/next_steps_test.rb`, `test/controllers/booster_next_steps_controller_test.rb`, `test/policies/booster_policy_test.rb`, `app/frontend/lib/booster_next_steps.test.ts`, `booster_next_steps_panel.test.ts`, two tests in `test/system/capsule_flow_test.rb`.

**Review:** one quick pass, 3 findings, all `low`, all patched (absolute-url comparison before reloading the frame; the answered-but-opening state tested; the no-hook-read test widened to the trade-suggestion and goal queries). Nothing deferred, nothing rejected.

**Follow-up review recommendation:** `false` -- patched: high 0, medium 0, low 3.

**Verification:** `bin/ci` (`PARALLEL_WORKERS=1`, own test database): every step green except one Rails failure, the French typography test (missing U+202F before "?" and ":" in the new French copy), fixed and rerun green; 3922 runs otherwise passing. `bin/setup` inside `bin/ci` renamed the lockfile's package to the worktree's name; restored. `npm run test:js` 831 passing; typecheck, prettier, stylelint, packwerk, zeitwerk, i18n-tasks, file sizes and planning references clean. System: `capsule_flow_test.rb` + `booster_reserves_test.rb` 5 runs green, `capsule_flow_test.rb` green again on a second run.

**Residual risks:** on a desktop the panel sits below the left info column, taller than the empty stage, so it starts low on the page; `test/system/booster_test.rb` (oversize, not named) was not run; the hooks reading (rewards to claim, first trade suggestion, links to the tabs) awaits the author's confirmation.

## Code Review

### 2026-11-04 — 0 decision-needed, 0 patch, 3 defer, 2 rejected

- [x] [Review][Defer] Hooks fail as a whole when one query raises, and the frame can run for a non-empty reserve or a nil season — deferred: low odds today, isolate each hook if the panel grows
- [x] [Review][Defer] The panel's appearance is not announced and a failed fetch leaves a bare heading — deferred: accessibility and retry polish for the author
- [x] [Review][Defer] The weak no-hook-read test greps SQL log names — deferred: replace by a stubbed NextSteps when the file is next touched

**Rejected**
- Daily line with a nil next bonus time: low, the claim always schedules the next one.
- Closest-set selection duplicated with the board concern, CSS literals, duplicated test setup: low.
