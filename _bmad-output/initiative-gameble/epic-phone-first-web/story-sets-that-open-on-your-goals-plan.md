---
title: 'Sets that open on your goals'
type: 'feature'
ticket: '5'
created: '2026-11-03'
status: done
baseline_revision: '7339ea8efe1beb012b274b658d0e012f5f53abb6'
route: 'full'
route_source: 'auto'
review: 'thorough'
review_source: 'pinned'
lenses_ran: [blind-hunter, edge-case-hunter, verification-gap, intent-alignment]
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: [oversized]
deferred:
  - summary: >-
      Back from a goal's album, nothing on the Sets tab carries the last-opened mark any more.
    evidence: |-
      last_album_controller.ts marks only `a.set-row, a.set-tile`; a goal set used to be marked through its EN COURS tile, which this change leaves out of EN COURS, and `a.goal-tile__link` has no mark nor a style for one. A visual cue for the author to want back on the goal tile (selector plus an aria-current style).
    location: >-
      app/frontend/controllers/last_album_controller.ts
    severity: low
  - summary: >-
      No test renders the Hall of fame or UFO group headings of EN COURS.
    evidence: |-
      The heading is the same `library.entry.kinds.<kind>` call tested for themes, franchises and studios; the keys exist in both locales and `raise_on_missing_translations` would fail a render, but no test seeds a set of those kinds into EN COURS (verification-gap lens).
    location: >-
      app/views/library/in_progress.html.erb
    severity: low
---

<intent-contract>

## Intent

**Problem:** The Sets tab (`/<locale>/library`) opens on the set search, shows goals as wide rows that only lead to an album, offers nothing to a player without a goal, and lists EN COURS as one flat list led by the sets just progressed in.

**Approach:** The entry opens on OBJECTIFS as compact goal tiles (bookmark, name, kind, held / total, gauge, next-tier line) whose missing cards show as small thumbnails, each opening that card's detail; with no goal, OBJECTIFS suggests the three started game sets closest to complete, each with a one-tap MARK AS GOAL that returns to the Sets tab. Under it the search (with ALL CARDS ▸ as today), MES SETS and the Steam library, then EN COURS split into one group per set kind, each sorted by the cards missing to completion, goal sets left out, COMPLÉTÉS unchanged.

## Boundaries & Constraints

**Always:** server-rendered ERB, no `style` attribute, no markup built in script; strings in `en.yml` and `fr.yml` (French plural keys with `zero`); writes only through `Game::AddGoal`; the GETs write nothing; no database id in HTML (cards by slug, sets by kind and key, custom sets by token); constant query counts whatever the number of sets or goals; tap targets at least 44px; colour never the only cue; files under the size limits (`collection-goals.css` is at 396 of 500: new rules go in a new stylesheet imported after it); keep `id="goals"` (the album refusal's "VOIR MES OBJECTIFS ▸" links to it).

**Decisions (conservative, recorded under Open in `pending-approvals.md`):** ALL CARDS ▸ stays the switch to the all-cards view (the two-segment switch was removed on 2026-11-02); goals lead, then the search, MES SETS and the Steam library keep their place before the grouped sets; a typed search no longer hides OBJECTIFS (it sits above the search) but still replaces everything below it; "closeness to completion" is the fewest cards missing to complete, then the larger share held, then set id; EN COURS keeps today's membership (`Game::SetBoard#in_progress`) minus the goal sets, and the gold frame stays on the set closest to its next tier of the whole list; a goal tile shows at most five missing thumbnails, then a "+N" link to the album filtered on missing cards; suggestions only when the player has no goal, at most three, game sets only (started, not complete); a player with neither goal nor started set sees today's empty line.

**Never:** the hub, the public profile's goals (`goals/_row` stays for it), the album pages and their goal button, the card list, the card detail (entry 9 adds its Trade button), new routes or tables, a trade action on the tile itself.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Goals | player with goals 1 and 3 | OBJECTIFS first: two tiles in number order, each linking its album, its missing cards as thumbnails linking `/<locale>/cards/<slug>/seasons/<n>`, the free-slot line | none |
| Many missing | a goal with 30 cards missing | five thumbnails then "+25" linking the album with `state[]=missing` | none |
| Custom set goal | goal on a custom set | tile with owned / total, no ticks, its missing games as thumbnails | a game with no published edition is skipped |
| No goal | three started incomplete sets and more | OBJECTIFS lists the three with fewest cards missing to complete, each with MARK AS GOAL | none |
| One tap | press MARK AS GOAL on a suggestion | goal 1 created, redirected (303) to the Sets tab, its tile shown first | refusal or alert: back to Sets with the alert toast |
| Nothing | no goal, no started set | the empty line as today | none |
| Groups | sets in progress of theme and studio, one a goal | EN COURS: a Themes group then a Studios group (kind order), fewest missing first, the goal set absent | none |
| Load more | a kind with nine sets in progress | six tiles then Load more adding the next three of that kind | an unknown section answers the first page |
| Search | typed query | OBJECTIFS stays, RÉSULTATS replaces MES SETS, the Steam library and the groups | none |

</intent-contract>

## Code Map

- `app/controllers/library_controller.rb` -- `show` sets `@goals = goal_marks.needs`; add goal tiles (missing views) and, with no goal, suggestions. `in_progress` validates `params[:section]` against `BOARD_SECTIONS`; make the sections the kinds (`Catalog::SetKind::ALL`) plus `completed`, pass the goal targets so goal sets are left out. Keep it under 400 lines; put new loading in a concern.
- `app/controllers/concerns/set_board_loading.rb` (91 lines) -- `load_set_tiles` builds `@in_progress_page`/`@completed_page` six at a time, `closest_to_next_tier` for the gold frame, `set_tiles` for showcases (one `Game::SetShowcases` call for all shown rows). Rework it to group in-progress rows by `set.kind` in `SetKind::ALL` order, sorted by `[total - held, -share, set_id]`, goal sets rejected, each group paged on its own (`section` = kind); expose e.g. `@group_pages` (kind => TilePage) and `@completed_page`; `more_tiles` picks the page by section.
- New concern (e.g. `app/controllers/concerns/goal_tile_loading.rb`) -- missing views for every goal in one go: `Catalog::LatestPublishedCardSeasons.call(card_ids)` then `Catalog::CardViews.call(ids, locale:)` over the first five `need.missing_card_ids` of each goal (album order), plus the missing count; suggestions from `Game::SetsInProgress.call(player, season:)` (started, not complete), sorted as above, first three, `Catalog::SetsById` for their sets. No new domain code needed; if a domain query is added, keep packwerk's direction (web layer → Game, Catalog).
- `app/views/library/_entry.html.erb` -- order becomes goals, search, results, custom sets, Steam library, the lazy `set-entry-in-progress` frame.
- `app/views/library/_goals.html.erb` -- keep the section, head, count and free/empty lines; replace `goals/row` with a new `library/_goal_tile` partial; render suggestions (new `library/_goal_suggestion`) when there is no goal and some candidate.
- `app/views/goals/_row.html.erb` -- read only (public profile still uses it); reuse its pieces: `goal_bookmark`, `goal_set_name`, `goal_kind_name`, `set_tier_ticks`, `set_goal_line`, `goal_row_sentence`, `goal_album_path` (`app/helpers/goals_helper.rb`, `set_rows_helper.rb`).
- Thumbnails -- `link_to_card_detail(view, strings: CardStrings.new, owned: false)` around `CardComponent.new(card: view, size: :s, owned: false)`, scaled to half like `.feed__thumb` (`app/frontend/styles/feed.css:255-270`).
- Suggestion button -- `button_to library_goals_path, method: :post, params: { kind:, key:, from: "sets" }` like `app/views/goals/_control.html.erb`; accessible name naming the set.
- `app/controllers/goals_controller.rb` -- with `params[:from] == "sets"` both formats redirect (303) to `library_path` (flash alert on failure, `goal_refused` ignored), and the throttle path is `library_path`; without it, behaviour unchanged.
- `app/views/library/in_progress.html.erb`, `more_tiles.html.erb`, `_set_tile_section.html.erb` -- EN COURS h2 with one h3 group per kind (heading ids from the kind, never ids), each through `set_tile_page` with `next_frame "set-more-<kind>-<offset>"`; the no-progress line when no group; COMPLÉTÉS as today.
- CSS -- new `app/frontend/styles/collection-goal-tiles.css` imported after `collection-goals.css` in `app/frontend/entrypoints/application.css`; drop the rule hiding `.goals` during a search (`collection-goals.css:78`); group heading style near `.set-entry__title`.
- Locales -- `library.entry.goals.*` (missing label, "+N" more, suggestions line and button, accessible names), `library.entry.kinds.<kind>` plural headings (en Themes, Franchises, Studios, Hall of fame, UFOs; fr Thèmes, Franchises, Studios, Palmarès, OVNI); `library.entry.loading` wording may stay.
- Tests to update: `test/controllers/library_controller_test.rb` 1048-1520 (EN COURS order, gold frame, load more, sections, query budgets 769/1408), `test/controllers/goal_bookmarks_pages_test.rb:247` (goal tile in EN COURS: move to search results), `test/controllers/library_own_sets_test.rb`, `test/controllers/library_set_test.rb:285,550`, `test/controllers/goals_controller_test.rb`; system: `test/system/goals_test.rb`, `test/system/library_test.rb:54`.

## Tasks & Acceptance

**Execution:**
- [x] `app/controllers/concerns/goal_tile_loading.rb`, `set_board_loading.rb`, `library_controller.rb` -- goal tiles, suggestions, grouped and sorted EN COURS without goal sets.
- [x] `app/controllers/goals_controller.rb` -- `from: "sets"` returns to the Sets tab.
- [x] `app/views/library/_entry.html.erb`, `_goals.html.erb`, new `_goal_tile.html.erb`, `_goal_suggestion.html.erb`, `in_progress.html.erb`, `more_tiles.html.erb`, `_set_tile_section.html.erb` -- the new order and pieces.
- [x] `app/helpers/goals_helper.rb` (or a new helper) -- tile sentence, missing-path, suggestion label helpers.
- [x] `app/frontend/styles/collection-goal-tiles.css` + import, `collection-goals.css` -- compact tiles, thumbnails, suggestion button, phone layout.
- [x] `config/locales/en.yml`, `fr.yml` -- new strings.
- [x] Tests -- controller tests for every matrix row (thumbnail links by slug and season, "+N", custom set goal, suggestions and their order, empty line, groups order and membership, goal set absent, per-kind Load more and bad section, OBJECTIFS kept on a search, GET writes nothing, no ids, constant query counts with 1 or 5 goals and 3 or 40 sets); goals controller tests for `from: "sets"` (success, refusal, alert, throttle); update the broken assertions; system tests in `goals_test.rb` (suggestion one tap, thumbnail opens the card) and `library_test.rb:54` adjusted.
- [x] `_bmad-output/initiative-gameble/pending-approvals.md` -- one Open entry with the decisions above.

**Acceptance Criteria:**
- Given a signed-in player with goals on a 390x844 phone, when the Sets tab loads, then the first section is OBJECTIFS with a tile per goal and its missing thumbnails, and tapping a thumbnail opens that card's detail.
- Given a player without a goal, when they press MARK AS GOAL on a suggestion, then they are back on the Sets tab with that set as goal 1 shown first.
- Given sets in progress of several kinds, when EN COURS loads, then it shows one group per kind in kind order, each sorted by cards missing to completion.

## Implementation Notes

- `GoalTileLoading` (new concern) builds the goal tiles in two queries for every goal (`LatestPublishedCardSeasons`, `CardViews`) and the suggestions from `Game::SetsInProgress` and `Catalog::SetsById`; `SetBoardLoading#load_set_tiles` groups EN COURS by kind (`@group_pages`, kind => page) with `completion_order` `[total - held, -share, set_id]`, goal sets left out through `Target#aims_at?`; sections are the five kinds plus `completed`, so the former `in_progress` section answers the first page.
- `GoalsController`: with `from=sets` both formats answer 303 to `library_path`, a failure (the five-goal refusal included) as the alert flash; the throttle goes back there too.
- Query budgets moved: the entry with a search 16 to 17, without 10 to 13 (the suggestions' standings, sets and labels); constant in the number of goals and sets (`library_goal_tiles_test.rb`).
- `test/controllers/library_goals_test.rb`, outside the plan's list, needed its assertions updated too.
- On a 390px phone, five thumbnails and "+N" wrap to two rows; thumbnails stay 56px wide for the 44px tap size.
- The setup `npm ci` renamed `package-lock.json` to the worktree; reverted, kept out of the commit.

## Plan Change Log

## Review Triage Log

### 2026-11-03 — Review pass
- verdicts: 7 findings — high 0, medium 2, low 5, false 0, maybe-false 0
- findings:
  - `medium` `patch` (quick) with every set in progress a goal, the frame said "No set in progress yet" while those sets show in OBJECTIFS — the line now shows only to a player with no goal; a controller assertion covers it.
  - `low` `defer` (quick) back from a goal's album nothing carries the last-opened mark — `last-album` marks set rows and tiles only, and goal sets left EN COURS; the fix adds a selector and a new style, recorded in `deferred`.
  - `medium` `patch` (quick) the suggestion button's accessible name "Mark Halo as a goal" did not contain its visible "Mark as goal" (label in name) — now "Mark as goal: Halo" / "Marquer comme objectif : Halo"; tests follow.
  - `low` `patch` (quick) each keystroke of the live set search loaded and rendered the goal tiles and suggestions, discarded by Turbo — skipped on a Turbo frame request, `@goals` kept for the result tiles.
  - `low` `patch` (quick) `goal-tile__link--tiered` was styled nowhere — removed with its assertion.
  - `low` `reject` (quick) the goal tile's gauge, kind and count rules copy the goal row's — the goal row stays only for the public profile; merging selectors across two stylesheets is more than a direct correction for a cosmetic drift risk.
  - `low` `patch` (quick) two test header comments badly re-wrapped — re-wrapped.

### 2026-11-03 — Review pass (follow-up, thorough)
- verdicts: 26 findings — high 0, medium 3, low 20, false 3, maybe-false 0
- findings:
  - `medium` `patch` (blind) EN COURS blank for a player with goals and no other set in progress — when no group shows, the frame now always has a line: `no_progress` without a goal, the new `no_other_progress` ("No other set in progress. Find one above.") with one; a test with an unstarted goal and nothing in progress, and the all-goals test, assert it.
  - `low` `reject` (blind) `_goals` reads "No goal" on a frame request whose tiles are skipped — Turbo keeps only the results frame, so no player sees it; the fix adds a branch for invisible markup.
  - `low` `patch` (blind) "+N" undercounted against the tile's count when a missing card has no published edition — `more_missing` is now all missing cards minus those shown; the list shows when there is a thumbnail or a "+N".
  - `low` `reject` (blind) a Load more of a page opened before the deploy asks the retired `in_progress` section and gets a mismatched frame — only a page kept open across the deploy and pressed then; a reload mends it; mapping the old section adds a branch.
  - `false` `reject` (blind) marking a suggestion gives no confirmation — the 303 lands on the Sets tab whose first section, OBJECTIFS, now holds the new goal 1 tile, as the album's redrawn control is its confirmation there.
  - `low` `reject` (blind) up to 35 tab stops before the search with five goals — the order is the intent's (goals first, thumbnails each opening a card); a skip link is new surface.
  - `low` `reject` (blind) a player without a goal reads the season's standings twice per visit (suggestions, then the lazy frame) — two separate requests, constant queries; sharing them is a refactor.
  - `low` `reject` (blind) `total - held` spelled in several places and `GoalTileLoading` including `SetBoardLoading` for `completion_order` — no caller diverges today; a domain method is new public surface.
  - `low` `reject` (blind) `_set_tile_section` infers the group layout from the heading level — two callers, both right.
  - `low` `reject` (blind) no test of a custom-set goal's "+N", a Steam-library goal tile, or a lone goal — the "+N" path is the same helper tested on game sets; the Steam library has no goal button; the empty EN COURS case is now tested (above).
  - `low` `reject` (blind) `count_queries` copied into the new test file — test-only duplication.
  - `low` `patch` (blind) "Plus que 1 carte pour compléter" — now "Plus qu'une carte pour compléter".
  - `low` `reject` (blind) bare 6px and 18px literals in the goal tile CSS — the same literals as the goal row it mirrors; cosmetic.
  - `low` `reject` (blind) the thumbnails keep the card's tilt wiring under a scale — the feed's thumbnails do the same; no visible effect.
  - `medium` `patch` (edge) EN COURS blank when the goals are unstarted or custom — same root cause and fix as the first row.
  - `low` `patch` (edge) "+N" hidden when none of the first five missing cards could be drawn — fixed with the "+N" row above.
  - `low` `reject` (edge) fewer than five thumbnails when a missing card has an edition but no text in the locale — every published card carries both locales' texts; filling from later cards adds a second lookup.
  - `low` `reject` (edge) a Steam-library goal plucks thousands of editions — no goal button reaches the Steam library; a forged request costs one query.
  - `false` `reject` (edge) a set kind outside `Catalog::SetKind::ALL` drops out of EN COURS — `catalog_sets_kind_check` allows only those five kinds.
  - `low` `reject` (edge) the stale `set-more-in_progress-N` frame after the deploy — same as the blind row; same reason.
  - `low` `patch` (verification) no test shows the gold frame skips goal sets — the "EN COURS groups its sets by kind" test now makes the goal set the closest and asserts the frame is on the closest shown set alone.
  - `low` `defer` (verification) no test renders the Hall of fame or UFO headings — recorded in `deferred`, the lens's own disposition.
  - `medium` `patch` (intent) the EN COURS empty line missing for a player with goals — same fix as the first row.
  - `false` `reject` (intent) suggestions may include a one-card set EN COURS does not list — the intent's decisions name suggestions as started, not complete, sets; EN COURS keeps its own membership.
  - `low` `patch` (intent) "+N" excludes unpublished cards — same fix as the "+N" row.
  - `low` `reject` (intent) the toast, 44px targets, the "+N" click and several groups are never seen in a browser — server tests and the CSS cover them; the author limits system tests.

## Verification

Work only in `/home/teyermann/projets/gameble/.claude/worktrees/agent-ad35a3254dc8f81d1`; never touch the main checkout. Every Rails command runs with `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w33_5` and `CHROME_BIN=/usr/bin/chromium`. Never run the whole system suite; run only the files below. Do not commit.

**Commands:**
- `bin/rails test test/controllers/library_controller_test.rb test/controllers/goals_controller_test.rb test/controllers/goal_bookmarks_pages_test.rb test/controllers/library_own_sets_test.rb test/controllers/library_set_test.rb` -- expected: pass
- `bin/rails test test/system/goals_test.rb test/system/library_test.rb` -- expected: pass
- `bin/ci && npm run test:js && bin/rails zeitwerk:check && bundle exec packwerk check && bundle exec i18n-tasks missing` -- expected: pass
- `npm run format:check && npm run lint:css && script/check_planning_references && script/check_file_sizes` -- expected: pass

## Auto Run Result

**Summary:** The Sets tab opens on OBJECTIFS as compact goal tiles: bookmark, name, kind, owned / total, gauge and next-tier line linking the album, then up to five missing cards as half-size thumbnails each opening the card's detail, and "+N" to the album filtered on the missing cards. A player with no goal sees the three started game sets fewest cards from complete, each with MARK AS GOAL, which returns (303) to the Sets tab with that set as goal 1. Then the set search with ALL CARDS ▸, MES SETS and the Steam library, then EN COURS split into one group per set kind (kind order, fewest cards missing to completion first, goal sets left out, six per group with Load more per kind), COMPLÉTÉS unchanged. A typed search keeps OBJECTIFS above its results.

**Files changed:**
- `app/controllers/concerns/goal_tile_loading.rb` (new) -- goal tiles' missing cards and the suggestions.
- `app/controllers/concerns/set_board_loading.rb`, `library_controller.rb` -- EN COURS grouped by kind and sorted by completion, sections per kind, goal tiles loaded (not on frame requests).
- `app/controllers/goals_controller.rb` -- `from=sets` returns to the Sets tab, the throttle too.
- `app/helpers/goals_helper.rb` -- album path with a query, missing-cards path, suggestion sentence.
- `app/views/library/_goal_tile.html.erb`, `_goal_suggestion.html.erb` (new), `_goals.html.erb`, `_entry.html.erb`, `show.html.erb`, `in_progress.html.erb`, `more_tiles.html.erb`, `_set_tile_section.html.erb` -- the new order and pieces.
- `app/frontend/styles/collection-goal-tiles.css` (new, imported), `collection-goals.css`, `collection.css` -- tiles, thumbnails, suggestions, groups; OBJECTIFS no longer hidden by a search.
- `config/locales/en.yml`, `fr.yml` -- `library.entry.goals.*`, `library.entry.kinds.*`.
- Tests: `test/controllers/library_goal_tiles_test.rb` (new), `library_controller_test.rb`, `goals_controller_test.rb`, `goal_bookmarks_pages_test.rb`, `library_goals_test.rb`; system `goals_test.rb` (phone one-tap and thumbnail), `library_test.rb`.
- `_bmad-output/initiative-gameble/pending-approvals.md` -- the conservative decisions, Open.

**Review:** quick lens, 7 findings: 5 patched (medium 2: the false no-progress line, the label in name; low 3: search keystroke work, dead class, comment wrap), 1 deferred (low: last-opened mark on goal tiles), 1 rejected (low: gauge rules duplicated with the goal row, merging is more than a direct correction).

**Follow-up review recommended:** true -- two medium entries were patched on a first pass. Unverified risk: a player whose goals are not started and who has no other set in progress now sees nothing where EN COURS was (the no-progress line hides whenever a goal exists), a case no design names.

**Verification:** `bin/ci` passed (4309 runs, 0 failures, seeds); system `goals_test.rb`, `library_test.rb`, `collection_set_test.rb`, `custom_sets_test.rb` 15 runs, 0 failures; `npm run test:js` 866 passed; `format:check`, `lint:css`, `check_planning_references`, `check_file_sizes`, `packwerk check`, `zeitwerk:check`, `i18n-tasks missing` pass. Query budgets: the entry 10 to 13 queries without a search, 16 to 17 with one, constant in goals and sets.

**Residual risks:** the conservative readings in `pending-approvals.md` (grouping membership, the order of sections, "closest" as fewest missing); five thumbnails and "+N" wrap to two rows at 390px.

### Follow-up pass (2026-11-03, thorough)

**Summary:** EN COURS now always shows a line when no group remains: today's for a player with no goal, "No other set in progress. Find one above." / "Aucun autre set en cours. Cherchez-en un ci-dessus." for one with goals. A goal tile's "+N" counts every missing card, so it matches the tile's own count, and shows even when no thumbnail could be drawn. The French one-card suggestion line reads "Plus qu'une carte pour compléter". A test pins the gold frame to the closest shown set when a goal set is closer.

**Files changed:** `app/views/library/in_progress.html.erb`, `app/views/library/_goal_tile.html.erb`, `app/controllers/concerns/goal_tile_loading.rb`, `config/locales/en.yml`, `fr.yml`, `test/controllers/library_goal_tiles_test.rb`.

**Review:** four lenses, 26 findings: 9 rows patched in 4 entries (medium 1: the blank EN COURS, with its edge and intent duplicates; low 3: "+N", the French line, the gold-frame test), 1 deferred (low: the Hall of fame and UFO headings untested), 16 rejected with their reasons in the triage log.

**Follow-up review recommended:** false -- a follow-up pass that patched no high; the work has converged.

**Verification:** `bin/ci` passed; the seven touched controller test files 143 runs, 0 failures; system `goals_test.rb` and `library_test.rb` 9 runs, 0 failures; `npm run test:js` 866 passed; `format:check`, `lint:css`, `check_planning_references`, `check_file_sizes`, `packwerk check`, `zeitwerk:check`, `i18n-tasks missing` pass.

**Residual risks:** a Load more pressed on a page opened before the deploy shows Turbo's missing-content frame until reloaded; the conservative readings in `pending-approvals.md` still wait on the author.

## Code Review

### 2026-11-04 — 0 decision-needed, 1 patch, 3 defer, 5 rejected

- [x] [Review][Patch] Pin that Load more pages past the goal sets with none returning, skipped or repeated [test/controllers/library_goal_suggestions_test.rb]
- [x] [Review][Defer] The edition lookup behind the goal thumbnails scales with the missing cards of every goal — deferred: low until a goal on the Steam library or a very large set is slow
- [x] [Review][Defer] The last-opened mark is lost after returning from a goal's album — deferred: already recorded, goal sets left EN COURS
- [x] [Review][Defer] Nothing announces a successful Mark as goal and focus does not move to the new tile — deferred: accessibility polish, settle with the author

**Rejected**
- Gold frame excludes goal sets: by design, a plan note only.
- Suggested set the operation then refuses, failure message missing, from=sets on other actions: low, same behaviour as the album path.
- French colon: false, the narrow no-break space is already used.
- Kinds outside the known list, negative missing counts, stale Load more link, empty group frame: low, unreachable today.
- Absolute worktree paths in the plan, plan status: edits the plan.
