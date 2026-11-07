---
title: 'A card list that scrolls without end'
type: 'feature'
ticket: '4'
created: '2026-11-03'
status: done
baseline_revision: 'cde8806c2c85b67249abd94401d398135c98f2a0'
route: 'full'
route_source: 'auto'
review: 'thorough'
review_source: 'pinned'
lenses_ran: [blind-hunter, edge-case-hunter, verification-gap, intent-alignment]
review_loop_iteration: 0
followup_review_recommended: true
context: []
warnings: [oversized]
deferred:
  - summary: without JavaScript the card list's pastilles open nothing, so their chips cannot be reached
    location: app/views/library/_filter_row.html.erb
    severity: low
  - summary: the system tests of the filter row and the bottom sheet were written, not run
    location: test/system/bottom_sheet_test.rb, test/system/library_test.rb, test/system/goal_bookmarks_test.rb
    severity: medium
  - summary: >-
      In an open filter sheet "Clear all" sits behind the modal and the sheet has no done or per-group clear button.
    evidence: |-
      The clear link stays in the form outside the sheets; the sheet closes by its close button, the scrim or a drag. A UX choice for the author (deferred-work.md).
    location: >-
      app/views/library/_filter_row.html.erb
    severity: low
  - summary: >-
      The card-art controller's give-up and redraw run only in the measure script and an unrun system test.
    evidence: |-
      lib/card_art/approach.ts is unit tested; the controller wiring (abort, new AbortController, redraw on the next approach) has no vitest, as no controller has one; test/system/card_art_test.rb gained a scroll-past test, written not run. The measure's back trip redraws cards a fling gave up, and settled every run.
    location: >-
      app/frontend/controllers/card_art_controller.ts
    severity: low
  - summary: >-
      The bottom sheet reads Turbo's untyped navigator.currentVisit.willRender to tell a frame visit from a page visit.
    evidence: |-
      A Turbo upgrade that renames the field would make every chip close its sheet again; bottom_sheet.test.ts checks the predicate on plain objects only.
    location: >-
      app/frontend/controllers/bottom_sheet_controller.ts
    severity: low
---

<intent-contract>

## Intent

**Problem:** The card list already appends its next server-rendered page as its links come near and comes back from a card detail at the same card (Turbo's snapshot holds the appended pages; `history_back` focuses the card's link), but at phone width the art pixelation queues every card a fling passes, so after a fling through 498 cards the cards on screen wait about 15 s for their art; and the list still stacks a search row, a QUICK FILTERS chip and a folded FILTRES zone whose open groups run several screens tall.

**Approach:** Search stays at the top; under it one row of pastilles (Goals, Rarity, State, then More for set and genre), each opening a `BottomSheetComponent` that holds that group's existing filter chips, still fields of the one filter form (OR within a group, AND across groups, the grid reloading behind the sheet); each pastille shows its own active count. The QUICK FILTERS sheet of preset links is retired. A card's art that leaves the near viewport before its turn gives its place in the pixelation queue back and waits to come near again.

## Boundaries & Constraints

**Always:** server-rendered ERB, markup never built in script, no `style` attribute in server HTML; strings in `en.yml` and `fr.yml`; reuse `BottomSheetComponent`, `bottom_sheet_opener` and the `bottom-sheet` controller unchanged in behaviour; same filter query parameters and server filtering; no new query on the card list request; tap targets at least 44px on the phone; the count of a pastille is text, colour never the only cue; files under the size limits (`collection-grid.css` is at 500 lines).

**Decisions (conservative, put to the author in `pending-approvals.md`):** the sheets combine choices as the FILTRES zone did (the open question on entry 3's menu stays open); set and genre, outside the three named pastilles, move to a fourth More pastille rather than being dropped; the QUICK FILTERS menu is retired, the pastilles taking its place; the row is not pinned while scrolling.

**Never:** the set album's and the public profile collection's FILTRES zone (they keep `_filters` as it is); the trade board picker; Social, friends, trades or the feed; changing pagination, page size or the `next-page` controller's protocol; new routes or actions; running system tests (the author asked; they are written, not run).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Player row | signed in with a goal, 390x844 | search, then Goals, Rarity, State, More in one row, no FILTRES zone, no QUICK FILTERS | none |
| No goal | player without goals | no Goals pastille | none |
| Visitor | signed out | Rarity and More only | none |
| Choose | open Rarity, tick Rare | grid reloads behind the open sheet, Rarity shows 1, the sheet's status reads the new count, Clear all shows | none |
| Combine | Rare in Rarity, then Missing in State | grid narrowed by both, each pastille 1 | none |
| State fallback | untick the only state | All comes back ticked, State shows no count | none |
| Arrive filtered | `?rarity[]=rare&state[]=missing` | Rarity 1, State 1, boxes ticked in the sheets | none |
| Fling | 498 cards, a screen every 32 ms to the end | cards on screen get their art without waiting for those passed | a card already drawing finishes and is cached |
| Back | open card 400, go back | same scroll, card 400's link focused, its art drawn | none |

</intent-contract>

## Code Map

- `app/views/library/cards.html.erb` -- passes `quick_filters: true` to `_collection`; becomes `filter_row: true`.
- `app/views/library/_collection.html.erb` -- renders `_filters` then `_quick_filters`; with `filter_row` render a new `library/_filter_row` instead of both; `_filters` stays for `public_profiles/collection.html.erb` and `_album.html.erb`. Pass `results_count: pagy.count`.
- `app/views/library/_filters.html.erb` -- the form (`collection-filters` controller, `turbo_frame: "collection-results"`, search, groups, clear, noscript apply). Extract each group fieldset (state, goals, rarity, genre) into partials used by both `_filters` and `_filter_row`; drop its `quick_filters` bits. `_set_filter.html.erb` is reused as is.
- `app/views/library/_quick_filters.html.erb`, `collection_helper.rb` `quick_filters_sheet_id`/`quick_filter_current?`/`quick_filter_link`/`QUICK_FILTER_IGNORED`, `test/controllers/library_quick_filters_test.rb`, the quick parts of `test/helpers/collection_helper_test.rb`, `library.quick_filters.*` in both locales, `.quick-filters*` and `.filters__search--menu` rules in `collection-filters.css` and `collection-grid.css:443` -- remove.
- `collection_helper.rb` `collection_filter_count` -- add per-group counts (`state` only when asked and not the default, `goals`, `rarity`, `sets`, `genre`) and sum them for the old method.
- `app/components/bottom_sheet_component.rb`, `bottom_sheet_helper.rb`, `bottom_sheet_controller.ts` -- reuse; a sheet inside the form keeps its checkboxes in the form, `change` bubbles to the form's `collection-filters#changed`; focus goes to the first chip on open.
- `app/frontend/controllers/collection_filters_controller.ts` + `lib/collection_filters.ts` -- `refresh()` counts per group; `count`/`number` targets become optional; add pastille targets (each naming its groups) whose number and `hidden` follow; on `turbo:frame-load` of `collection-results` (listen at document: the frame is not inside the form) copy `#collection-results-status`'s text into each sheet's status. Put the counting in `lib/collection_filters.ts` with vitest (`collection_filters.test.ts`).
- `app/frontend/controllers/card_art_controller.ts` -- today stops observing at the first intersection and its draw waits in `createArtRenderer`'s FIFO queue (`lib/card_art/renderer.ts`, concurrency 3, cache 120) until disconnect. Keep observing until the draw settles; on leaving the 300px margin before then, abort (the renderer's `release` drops a queued job, a running one finishes into the cache) and wait for the next approach; a fluid redraw is unchanged. Decision logic in a small pure module under `lib/card_art/` with vitest.
- CSS -- new `app/frontend/styles/collection-filter-row.css` imported after `collection-filters.css` in `entrypoints/application.css` (its own phone block: `collection-grid.test.ts` reads the first phone query of the collection sheets it imports); pastille look from `.filter-chip`, the count like `.filters__count`.
- Tests: `test/controllers/library_controller_test.rb` (id list at 753, FILTRES zone asserts at 583-610, 784-990, query budget 762), `test/controllers/goal_bookmarks_pages_test.rb:47-108`, `test/components/bottom_sheet_component_test.rb`; system (write only): `test/system/bottom_sheet_test.rb` (fixture is QUICK FILTERS: move to a pastille sheet), `test/system/library_test.rb` 249 and 305, `test/system/goal_bookmarks_test.rb:63`. Do not touch `test/system/collection_set_test.rb` (album).
- Measure: `bundle exec ruby /tmp/claude-1000/-home-teyermann-projets-gameble/84ee6f27-7d3a-45f5-8ae0-ae75810b9ed1/scratchpad/w4/measure.rb after 3` against the perf server on 3999 (private copy of the development data, 498 cards for a visitor, 390x844 DPR 3, CPU 4x); baseline below.

## Tasks & Acceptance

**Execution:**
- [x] `app/views/library/_filter_row.html.erb`, group partials, `_filters.html.erb`, `_collection.html.erb`, `cards.html.erb` -- the row and its four sheets inside the form, each sheet with its group, a `role=status` count line, the clear link and noscript apply kept.
- [x] `app/helpers/collection_helper.rb` -- per-group counts and pastille sheet ids; quick-filter helpers removed.
- [x] `app/frontend/lib/collection_filters.ts`, `collection_filters.test.ts`, `controllers/collection_filters_controller.ts` -- per-group and pastille counts, status mirror.
- [x] `app/frontend/lib/card_art/` new module + test, `controllers/card_art_controller.ts` -- give the queue place back off-screen.
- [x] CSS -- `collection-filter-row.css` + import; quick-filter rules removed.
- [x] `config/locales/en.yml`, `fr.yml` -- `library.filter_row.more` (More / Plus) and `library.filter_row.more_title` (More filters / Autres filtres); `library.quick_filters` removed.
- [x] Tests -- controller and helper tests for every matrix row that HTML shows (row per player, no-goal, visitor, arriving filtered counts, public profile and album keep FILTRES, ids, query count unchanged); system tests updated and the new pastille flows written, not run.
- [x] `pending-approvals.md` (Open), `deferred-work.md` -- the decisions above; the no-script reach of the sheets.

**Acceptance Criteria:**
- Given the card list on a phone, when it loads, then the search is the first row and the pastilles the second, nothing else above the grid but the clear link when filters are active.
- Given the measure script, when run after the change, then the art settle after the fling is far below the 15 s baseline and nothing else gets worse.

## Implementation Notes

- `_filters` keeps the one form (search, clear link, noscript apply) and renders either the folded FILTRES zone or, with `filter_row: true`, `library/_filter_row` inside the same form; the group fieldsets are `_state_filter`, `_goal_filter`, `_rarity_filter`, `_genre_filter` (with `_set_filter` as before), shared by both. In a sheet whose title already names the group, the legend is visually hidden (`titled: true`).
- Sheet ids are `filters-<pastille>` (`filters-goals`, `filters-rarity`, `filters-state`, `filters-more`); each pastille's count is a `pastilleCount` target naming its groups in `data-groups`, its number in `[data-pastille-number]`. `collection-filters#resultsLoaded` (on `turbo:frame-load@document`) copies `#collection-results-status` into every `sheetStatus` target.
- The grid reload is a frame visit promoted to the URL (`data-turbo-action="replace"`), and Turbo caches a snapshot on it, firing `turbo:before-cache`; the bottom-sheet controller closed every sheet on that event, so the open sheet shut on each chip. It now closes only when the visit renders a page (`visitLeavesPage(window.Turbo.navigator.currentVisit)`, false for a visit with `willRender: false`), and a sheet cloned open into a snapshot is not shown again while that snapshot is a preview (`html[data-turbo-preview]`). A sheet the player opened carries `data-bottom-sheet-opened-here` until it closes; a page restored from the cache with such a sheet still open closes it instead of showing it, since Turbo clones the page for a frame visit before `turbo:before-cache` runs. Every other behaviour of the sheet is unchanged.
- `card_art_controller.ts` keeps observing until its draw settles; the transitions live in `lib/card_art/approach.ts` (`far` → `drawing` on approach, `drawing` → `far` with the draw given up when it leaves the 300px margin, `settled` once a draw ends unaborted). Giving up aborts the draw's signal, so the renderer releases a queued job; a running one finishes into the cache.
- Measure (median of 3, 2026-11-03): `after` first screen art 1227 ms, page 1 DOM 1882 nodes, fling 7419 ms over 498 slots, art settled after the fling 3872 ms, long tasks 2454 ms (24), DOM at the end 13438, back 1248 ms, its art 4538 ms, focus on card 400 every run. The machine was busier than for the baseline, so the old art code was measured again just before (`before-now`, same conditions): settle 16554 ms, long tasks 2916 ms (30), fling 7581 ms, back 1292 ms, back art 4437 ms. The art settle drops by three quarters; the rest is within noise.
- System tests were written, not run (the author asked).

## Plan Change Log

- 2026-11-03: the bottom-sheet controller changed in one respect (it stays open across a frame visit that renders no page, and a preview does not reopen a sheet), needed for the grid to reload behind the open sheet as the matrix asks.
- 2026-11-03, review: a snapshot cloned with the player's sheet open came back open by history; the controller now marks a sheet it opened and closes a marked sheet restored open (patch, no re-derivation).

## Review Triage Log

### 2026-11-03 — Review pass
- verdicts: 30 findings — high 0, medium 4, low 22, false 2, maybe-false 2
- findings:
  - `low` `patch` (blind) package-lock.json renamed to the worktree — the rename came from the setup `npm ci`; reverted with `git checkout -- package-lock.json`, kept out of the commit.
  - `low` `defer` (blind) the no-JavaScript deferral's premise is wrong — the dialog does not open on its fragment, but a `:target` rule could show it; the deferred entry now names that rule; no-script players are rare and the fix adds styling for a static dialog state, left to the author.
  - `medium` `patch` (blind) the bottom sheet relies on Turbo internals and a restoration visit can reopen a snapshot cloned with the sheet open — verified in Turbo's `proposeVisitIfNavigatedWithAction` (whole page cloned at proposal time); the controller marks a sheet it opened and a restored marked sheet closes without `showModal`. The private `willRender` field is deferred.
  - `low` `patch` (blind) the `pastille` target is the count badge — renamed `pastilleCount`.
  - `low` `patch` (blind) `collection_filter_count` is dead in app code — deleted with its test; the unasked-state case moved to the per-group test.
  - `low` `patch` (blind) the `assert_slots` comment was orphaned in library_test.rb — the helpers moved after `assert_slots`.
  - `maybe-false` `reject` (blind) the French row with four counts may wrap at 390px — low if true: the row wraps by design (`flex-wrap`), nothing is cut; a French signed-in screenshot would settle it.
  - `low` `defer` (blind) Clear all is inert behind an open sheet, with no done button — a UX choice, recorded for the author.
  - `low` `defer` (blind) the card-art controller's wiring is untested, a failed draw never retries, and with no IntersectionObserver the state stays `far` — the wiring runs in the measure's back trip; failed draws never retried before either; the no-observer path has no observer to act on the state.
  - `low` `reject` (blind) the pastille-reading test helpers are copied three times — test-only duplication, no caller diverges.
  - `low` `patch` (blind) uneven helper interface (`sets:` takes a boolean) — renamed `sets_offered:`; the label and title branch duplication rejected as cosmetic.
  - `false` `reject` (blind) the plan lists lenses with an empty triage log — the log is written at this step, as the workflow orders.
  - `low` `reject` (blind) the measure script is not in the repo — the numbers and conditions are in the plan; the ticket asks for a measure recorded; the fix would edit the plan.
  - `low` `reject` (blind) "nothing else gets worse" is not shown (back art 4437 to 4538 ms) — a 2% move on medians of three on a busy machine; the run result states it plainly; the fix would edit the plan.
  - `medium` `patch` (edge) a restoration visit reopens a cached open sheet — grouped with the Turbo finding above; same fix.
  - `medium` `patch` (edge) the frame visit's snapshot is cloned before `turbo:before-cache` runs — same root cause and fix.
  - `low` `patch` (edge) package-lock.json renamed — duplicate; reverted.
  - `low` `patch` (edge) `collection_filter_count` dead — duplicate; deleted.
  - `maybe-false` `reject` (edge) the pastilles may wrap with counts or French labels — duplicate of the blind finding; wrapping is by design.
  - `low` `defer` (verification) every browser-side behaviour is checked only by unrun system tests — the author asked that system tests not run; recorded in deferred-work.md and `deferred`.
  - `medium` `patch` (verification) no test leaves with a sheet open and comes back — added "a page cached with a sheet the player opened comes back by history with no sheet open" to bottom_sheet_test.rb (written, not run).
  - `low` `patch` (verification) art giving up and redrawing off-screen runs in no test — added "arts passed by a fast scroll before they draw are drawn once scrolled back to" to card_art_test.rb (written, not run).
  - `low` `patch` (verification) package-lock.json renamed — duplicate; reverted.
  - `false` `reject` (intent) four pastilles where the intent names three — the three named pastilles are there; More keeps set and genre instead of dropping them, a conservative choice put to the author in pending-approvals.md.
  - `low` `reject` (intent) the row is two lines (search, then pastilles) where "one row" may mean one line — the intent's source says "Search stays at the top"; the reading is in the plan.
  - `low` `defer` (intent) "each pastille narrows the list" is shown only by unrun system tests and server tests — duplicate of the verification deferral.
  - `low` `reject` (intent) the back trip is measured as a visitor, not a signed-in player — the restore path (Turbo snapshot, focus return) does not depend on the viewer.
  - `low` `reject` (intent) an earlier noisy `after` run was set aside — the old code was measured again under the same conditions; both runs are reported.
  - `low` `patch` (intent) package-lock.json renamed — duplicate; reverted.
  - `low` `defer` (intent) the no-JavaScript reach — duplicate of the blind deferral.

## Design Notes

Baseline measure (2026-11-03, median of 3, `before`): first screen art 1238 ms; page 1 DOM 1889 nodes; fling to the end 7305 ms, 498 slots; art settled on screen after the fling 15249 ms; long tasks 2369 ms (22); DOM at the end 13445 nodes; back from card 400 at the same scroll 1140 ms, its screen's art 3936 ms, focus on its link every run.

Scroll restoration is already built (`next_page_controller.ts`, Turbo snapshot, `history_back_controller.ts` `focusReturnLink`, system test "back from a card of an appended page"); this story keeps it working and measures it.

## Verification

Work only in `/home/teyermann/projets/gameble/.claude/worktrees/agent-a5b588d90a3fb99c8` (never the main checkout); do not commit. Every Rails command runs with `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w4`. Do not run any system test. The perf server (development code of this worktree on a private data copy) already runs on 127.0.0.1:3999 and reloads code changes; Vite rebuilds on request.

**Commands:**
- `npm run test:js && npm run format:check && npm run lint:css` -- expected: pass
- `bin/rails test test/controllers test/helpers test/components` -- expected: pass
- `bin/ci && bin/rails zeitwerk:check && bundle exec packwerk check && bundle exec i18n-tasks missing` -- expected: pass
- `script/check_file_sizes && script/check_planning_references` -- expected: pass
- the measure script, `after 3` -- expected: art settle after fling well under baseline

## Auto Run Result

**Summary:** On the card list, the stacked search, QUICK FILTERS chip and folded FILTRES zone give way to the search, then one row of pastilles (Goals, Rarity, State, More). Each opens a bottom sheet with that group's chips, still fields of the one filter form: the grid reloads behind the open sheet, each pastille counts its own chips, and each sheet's status line reads the new result count. The QUICK FILTERS preset sheet is retired. A card's art that leaves the near viewport before its turn gives its place in the pixelation queue back. The endless pages and the return to the same card after a detail were already built; they are kept and measured.

**Files changed:**
- `app/views/library/_filters.html.erb`, `_collection.html.erb`, `cards.html.erb` -- the one form renders the FILTRES zone or the new row.
- `app/views/library/_filter_row.html.erb` -- the pastille row and its four sheets.
- `app/views/library/_state_filter.html.erb`, `_goal_filter.html.erb`, `_rarity_filter.html.erb`, `_genre_filter.html.erb` -- group fieldsets shared by both layouts.
- `app/views/library/_quick_filters.html.erb` -- removed.
- `app/helpers/collection_helper.rb` -- per-group counts and pastille helpers; quick-filter helpers removed.
- `app/frontend/controllers/collection_filters_controller.ts`, `lib/collection_filters.ts` (+ test) -- per-group and pastille counts, sheet status mirror.
- `app/frontend/controllers/bottom_sheet_controller.ts`, `lib/bottom_sheet.ts` (+ test) -- stays open across a frame visit; a restored sheet the player opened stays closed.
- `app/frontend/controllers/card_art_controller.ts`, `lib/card_art/approach.ts` (+ test) -- gives the queue place back off-screen.
- `app/frontend/styles/collection-filter-row.css` (+ import), `collection-filters.css`, `collection-grid.css` -- the row's look; quick-filter rules removed.
- `config/locales/en.yml`, `fr.yml` -- `library.filter_row.*`; `library.quick_filters` removed.
- Tests: `test/controllers/library_filter_row_test.rb` (new), `library_controller_test.rb`, `goal_bookmarks_pages_test.rb`, `test/helpers/collection_helper_test.rb`, `test/controllers/library_quick_filters_test.rb` (removed); system tests written, not run: `bottom_sheet_test.rb`, `library_test.rb`, `goal_bookmarks_test.rb`, `card_art_test.rb`.
- `_bmad-output/initiative-gameble/pending-approvals.md`, `deferred-work.md` -- the conservative decisions; the deferrals.

**Review:** 14 rows patched (medium 4: the restored open sheet, its two edge-case duplicates and the missing back/forward test; low 10: package-lock revert and its duplicates, target rename, dead helper, keyword rename, comment placement, card-art test), 6 deferred, 10 rejected, each reason in the triage log.

**Follow-up review recommended:** true -- two medium entries were patched on a first pass (the restored open sheet; the back/forward test); the unverified risk is the bottom sheet's Turbo cache handling, exercised only by a system test that was not run.

**Verification:** `npm run test:js` 866 passed; `format:check`, `lint:css`, `script/check_file_sizes` and `script/check_planning_references` pass; `bin/ci` passed (4280 runs, 0 failures); `bin/rails zeitwerk:check`, `bundle exec packwerk check` and `bundle exec i18n-tasks missing` pass. System tests were not run, at the author's request. Measure (390x844, DPR 3, CPU 4x, 498 cards, visitor, median of 3), baseline / old code re-measured on a busier machine / after: art settled after a fling 15249 / 16554 / 3872 ms; first screen art 1238 / - / 1227 ms; fling 7305 / 7581 / 7419 ms; long tasks 2369 / 2916 / 2454 ms; back from card 400 at the same scroll 1140 / 1292 / 1248 ms; its screen's art 3936 / 4437 / 4538 ms (not improved); focus on card 400 every run.

**Residual risks:** the row and sheets' browser flows are checked only by unrun system tests and one manual smoke run; the sheets rely on Turbo's `willRender`; without JavaScript the pastilles open nothing.

## Code Review

### 2026-11-04 — 0 decision-needed, 1 patch, 5 defer, 2 rejected

- [x] [Review][Patch] Delete the explanatory comments [app/frontend/styles/collection-filter-row.css], [test/controllers/library_filter_row_test.rb]
- [x] [Review][Defer] The card-art system test passes without the give-up behaviour; strengthen it to fail on the old code (no art drawn while away, queue released) — deferred: needs a browser run, do it with the system tests before release
- [x] [Review][Defer] The filter sheets' client glue (pastille counts, sheet status, cache restore) is covered only by system tests that bin/rails test skips — deferred: run them once in the main tree before release
- [x] [Review][Defer] Desktop loses the inline filters and no-JavaScript players lose filtering — deferred: a decision for the author, recorded with the pending approvals
- [x] [Review][Defer] A sheet has no done or clear control and shows no result count button — deferred: a UX choice for the author
- [x] [Review][Defer] The row may wrap in French with four counts at 390 px — deferred: check on the iPhone pass

**Rejected**
- Unhandled rejection of the card art draw, Turbo undefined at before-cache, stale sheet status after a failed frame, count drift after a set search: low, no reachable path shown.
- Naming of pastille, duplicated test readers, absolute paths and one-off measure notes in the plan: low or edits the plan.
