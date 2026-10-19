---
title: 'Refactor sweep'
type: 'refactor'
ticket: '10'
created: '2026-10-19'
status: 'built'
baseline_revision: 'cf3e0035d44e9fa6b49c668a8672258c7f19be57'
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

**Problem:** The epic's build records and deferred review findings leave small debts: the five set kinds are spelled out in six places (the `Catalog::Set` enum, `CollectionGridLoading::SET_KINDS`, two route regexes, two SQL `CASE` orders); `Catalog::SetSlots` survives only as a namespace around `SetRef`; `Catalog::SeasonShelf` is named after a shelf the screens no longer have; `Game::SetStanding#tier_reached?` has no caller outside its test; `i18n-tasks unused` reports keys read dynamically (`rate_limit.*`, `date.*`, `time.formats.local_*`); no test renders the French back-office preview with zero UFOs; `FocusWish` restates `StepDirection | null`. The retired kinds (tomes, publisher sets, best-of-year sets) already left app, pack and locale code: only the migration and its tests name them.

**Approach:** One list of kinds in `Catalog::SetKind` feeds the enum, the controllers, the routes and the SQL order; rename `SetSlots::SetRef` to `Catalog::SetRef` and `SeasonShelf` to `Catalog::SeasonSets`; drop the dead method; widen `ignore_unused`; add the missing test; derive `FocusWish`. Planning ids go from the comments of the files touched anyway.

## Boundaries & Constraints

**Always:** Behaviour, URLs, markup, query counts and the rows and order every query returns stay as they are. Rewrite planning-id comments as plain English (no AD-n, CAP-n, R-n, story n.n, epic n) in touched files only. English in the repo.

**Never:** No migration, no schema change, no locale value change, no change to system tests. Do not touch: `Game::SetCompletion` and its table (dropping it changes the account-deletion copy and a query: an author decision); the feed's `COALESCE` fallback in `packs/game/app/models/game/feed_entry.rb` (needs fixture rework); `SetLabel`'s hall of fame default; the collection grid's arrow keys (a feature); the README (awaiting the author's rewrite); planning ids in files this sweep does not otherwise touch (epic-human-readable-codebase owns them).

</intent-contract>

## Code Map

- `packs/catalog/app/models/catalog/set.rb` -- enum literal `{ theme: "theme", … }` in tab order; `Set.kinds.keys` is read by views (back_office/seasons/index), `season_scores.rb`, `season_summaries.rb`, `schema_test.rb:125` -- keep `kinds` identical.
- `app/controllers/concerns/collection_grid_loading.rb:25` -- `SET_KINDS` duplicate; used by `cards_controller.rb:123` and `library_controller.rb:72` (`SET_KINDS & Catalog::SeasonShelf.kinds(...)`, order matters: tab order).
- `config/routes.rb:28,42` -- `kind: /theme|franchise|studio|hall_of_fame|ufo/` constraints; also planning ids at lines 12, 16, 43-44, 57-58, 63, 69, 71, 74, 84, 116, 161, 165.
- `packs/catalog/app/queries/catalog/card_detail.rb:39,68` -- `KIND_ORDER` CASE, ordered with `SeasonShelf::HALL_OF_FAME_ORDER, :key`; `SetSlots::SetRef` at :70.
- `packs/catalog/app/queries/catalog/season_shelf.rb` -- `HALL_OF_FAME_ORDER`, `EVERY_KIND_ORDER` (same CASE plus a redundant `catalog_sets.kind` term), `every_kind`, `kinds`; users `app/models/set_search.rb:14,24`, `library_controller.rb:72`; test `test/packs/catalog/season_shelf_test.rb` (asserts query counts of 0).
- `packs/catalog/app/queries/catalog/set_slots.rb` -- only `SetRef = Data.define(:kind, :key, :params)`; users `set_neighbours.rb:40`, `collection_grid.rb:63`, `card_detail.rb:70`, comment in `app/components/set_label.rb:8`, tests `card_detail_test.rb:29`, `set_neighbours_test.rb:34`.
- `packs/game/app/models/game/set_standing.rb:51` -- `tier_reached?`, called only by `test/packs/game/set_standing_test.rb:8,21,22`.
- `config/i18n-tasks.yml` -- `ignore_unused`; `bundle exec i18n-tasks unused` lists `rate_limit.{reading_throttled,throttled}` (rack_attack.rb:53), `date.{abbr_month_names,day_names}` and `time.formats.local_{time,datetime,weekday_time,date_time_year}` (the `local_time_*` helpers, I18n.l) in en and fr.
- `test/controllers/back_office/seasons_controller_test.rb` -- French preview tests near lines 115-150; `seed_card_seasons(distinct_scores(150), genres: …)` with `[ "rpg" ]` gives every card a theme; `fr.back_office.seasons.preview.ufos.zero` reads "%{formatted} carte dans les OVNI, %{share} de la saison."
- `app/frontend/lib/sub_view_step.ts:17` -- `FocusWish` literal union.

## Tasks & Acceptance

**Execution:**
- [x] `packs/catalog/app/models/catalog/set_kind.rb` -- new plain module `Catalog::SetKind` (no ActiveRecord model load, so routes can read it): `ALL = %w[theme franchise studio hall_of_fame ufo]` (tab order), `ORDER` = `Arel.sql` CASE built from `ALL` giving the same `WHEN 'theme' THEN 0 … ELSE 5 END`, `PATTERN = Regexp.union(ALL)` -- one list of kinds.
- [x] `packs/catalog/app/models/catalog/set.rb` -- build the enum from `SetKind::ALL` (same symbol keys and string values, same order, `validate: true`); comment no longer claims `kinds.keys` as the list's home -- kinds identical.
- [x] `config/routes.rb` -- both `kind:` constraints read `Catalog::SetKind::PATTERN`; rewrite every planning-id comment without the ids -- same routes.
- [x] `app/controllers/concerns/collection_grid_loading.rb`, `app/controllers/cards_controller.rb`, `app/controllers/library_controller.rb` -- drop `SET_KINDS`, read `Catalog::SetKind::ALL`; strip planning ids from `cards_controller.rb`'s header comment.
- [x] `packs/catalog/app/queries/catalog/season_shelf.rb` → `season_sets.rb` (`Catalog::SeasonSets`) -- `every_kind` orders by `SetKind::ORDER, HALL_OF_FAME_ORDER, catalog_sets.key` (redundant kind term dropped); comments speak of sets, not a shelf; rename callers and `test/packs/catalog/season_shelf_test.rb` → `season_sets_test.rb`.
- [x] `packs/catalog/app/queries/catalog/card_detail.rb` -- drop `KIND_ORDER`, order by `SetKind::ORDER, SeasonSets::HALL_OF_FAME_ORDER, :key`; build `Catalog::SetRef`.
- [x] `packs/catalog/app/queries/catalog/set_slots.rb` → `set_ref.rb` (`Catalog::SetRef`) -- update `set_neighbours.rb` (and its planning-id comments), `collection_grid.rb`, `card_detail.rb`, `set_label.rb`'s comment, `card_detail_test.rb`, `set_neighbours_test.rb` (and its planning-id comment).
- [x] `packs/game/app/models/game/set_standing.rb`, `test/packs/game/set_standing_test.rb` -- remove `tier_reached?` and the assertions on it (the tests keep `reached_tier`, `thresholds`, `next_tier`).
- [x] `config/i18n-tasks.yml` -- add `rate_limit.*`, `date.abbr_month_names`, `date.day_names`, `time.formats.local_*` to `ignore_unused`, each with a one-line note of who reads it; drop the AD id in the header.
- [x] `test/controllers/back_office/seasons_controller_test.rb` -- add a French preview test with a draft whose every card has a theme: `p[data-preview-ufo-count='0']` reads "0 carte dans les OVNI"; drop the AD id in its comment.
- [x] `app/frontend/lib/sub_view_step.ts` -- `export type FocusWish = StepDirection | null`.
- [x] `test/packs/catalog/set_kind_test.rb` -- `ALL` equals `Catalog::Set.kinds.keys`, `PATTERN` matches each kind whole and refuses `tome`, `ORDER` sorts the kinds in `ALL`'s order.

**Acceptance Criteria:**
- Given the full suite, when it runs, then every test passes, with the query-count assertions unchanged.
- Given `bin/rails routes`, when compared with the baseline's, then the output is identical.
- Given `bundle exec i18n-tasks unused` and `missing`, when run, then both report nothing.
- Given `grep -rniE 'tome|best_of_year|publisher set' app packs config/locales`, when run, then only the card's publisher field matches (no retired set kind).
- Given the touched files, when grepped for `AD-[0-9]|CAP-[0-9]|\bR[0-9]+\b|story [0-9]|epic [0-9]`, then nothing matches.

## Implementation Notes

- Scope came from the epic's plans (frontmatter `deferred`, triage logs, Implementation Notes) and its entries in `deferred-work.md`, each checked against the code at the baseline. Already resolved by later entries: the retired kinds' code and strings (entry 4), the profile's complete-sets count (entry 15), the set-scoped grid support (entry 9), the album's capsule back (entry 17), the detail column (entry 25). Left out as behaviour changes or author decisions: see Boundaries.
- `Catalog::SetKind` is a plain module so `config/routes.rb` can read it without loading `ApplicationRecord`; `Regexp.union(ALL)` prints as the former `/theme|franchise|studio|hall_of_fame|ufo/` and `bin/rails routes` is byte-identical to the baseline's.
- Verification fix: Brakeman (in `bin/ci`) flagged `SetKind::ORDER`'s interpolated `Arel.sql` as a possible SQL injection; `ORDER` is now an `Arel::Nodes::Case` over `catalog_sets.kind`, the kinds quoted by Arel, producing `CASE "catalog_sets"."kind" WHEN 'theme' THEN 0 … ELSE 5 END`, the same order.
- `npm install` and `bin/setup` rewrite `package-lock.json`'s name to the worktree's; reverted each time, never committed.

## Plan Change Log

## Review Triage Log

### 2026-10-19 — Review pass
- verdicts: 2 findings — high 0, medium 0, low 2, false 0, maybe-false 0
- findings:
  - `[low]` `[patch]` `package-lock.json` carries the worktree's name after `npm install`, outside the reviewed diff; a whole-tree commit would ship it — reverted to the index before the commit.
  - `[low]` `[reject]` The acceptance grep `tome|best_of_year|publisher set` matches `CustomEvent` and never the publisher field, so it cannot be checked literally — its fix is an edit of this plan; with a word boundary (`\btomes?\b|best_of_year|publisher set`) nothing in `app`, `packs` or `config/locales` matches, so no retired kind remains.

## Verification

**Commands:**
- `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w1310 bin/rails test` (through the shared ci-slot wrapper) -- expected: green.
- `bin/rails routes` before and after -- expected: identical.
- `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `npm run test:js`, `npm run typecheck`, `bundle exec i18n-tasks unused`, `bin/ci` -- expected: all pass.

## Auto Run Result

**Summary:** The epic's leftovers swept without changing behaviour, URLs, markup or query counts. The five set kinds now come from one list, `Catalog::SetKind`, which the enum, both route constraints, the controllers and the SQL kind order read. `Catalog::SetSlots::SetRef` became `Catalog::SetRef`, and `Catalog::SeasonShelf` became `Catalog::SeasonSets`. The uncalled `Game::SetStanding#tier_reached?` was removed. `i18n-tasks unused` is clean. The French zero-UFO preview has a test, and `FocusWish` derives from `StepDirection`. The touched files carry no planning ids. The retired kinds (tomes, publisher and best-of-year sets) were already gone from app, pack and locale code; only the migration and its tests name them.

**Files changed:**
- `packs/catalog/app/models/catalog/set_kind.rb` — new: `ALL`, `ORDER` (an Arel CASE), `PATTERN`.
- `packs/catalog/app/models/catalog/set.rb` — enum built from `SetKind::ALL`.
- `config/routes.rb` — `kind:` constraints read `SetKind::PATTERN`; planning ids and design-doc names gone from comments.
- `app/controllers/concerns/collection_grid_loading.rb`, `cards_controller.rb`, `library_controller.rb` — `SET_KINDS` replaced by `SetKind::ALL`.
- `packs/catalog/app/queries/catalog/season_sets.rb` (was `season_shelf.rb`) — renamed; orders by `SetKind::ORDER`.
- `packs/catalog/app/queries/catalog/set_ref.rb` (was `set_slots.rb`) — `Catalog::SetRef`.
- `packs/catalog/app/queries/catalog/card_detail.rb` — its own `KIND_ORDER` gone.
- `packs/catalog/app/queries/catalog/collection_grid.rb`, `set_neighbours.rb`, `app/components/set_label.rb`, `app/models/set_search.rb` — callers renamed.
- `packs/game/app/models/game/set_standing.rb` — `tier_reached?` removed.
- `config/i18n-tasks.yml` — dynamic keys added to `ignore_unused`.
- `app/frontend/lib/sub_view_step.ts` — `FocusWish = StepDirection | null`.
- Tests: new `set_kind_test.rb` and a French zero-UFO preview test; `season_sets_test.rb` renamed; `SetRef` and `set_standing` tests adjusted.
- `_bmad-output/initiative-gameble/deferred-work.md` — two leftovers recorded for the author (`Game::SetCompletion`, the feed's share fallback).

**Review findings:** 1 patch applied (low: `package-lock.json` reverted before commit). 0 deferred. 1 rejected (low: the plan's literal acceptance grep matches `CustomEvent`; fixing it means editing the plan; a word-bounded grep finds no retired kind). Brakeman's SQL warning on the first `SetKind::ORDER` was a verification fix, not a review finding.

**Follow-up review recommended:** false (patched: high 0, medium 0, low 1).

**Verification:**
- `bin/ci` (through the shared slot) passed: rubocop, packwerk, i18n-tasks missing, typecheck, bundler-audit, brakeman, both schema checks, `bin/rails test` (2830 runs, 0 failures), seeds.
- `npm run test:js`: 467 passed.
- `bin/rails zeitwerk:check`: OK.
- `bundle exec i18n-tasks unused`: clean.
- `bin/rails routes`: identical to the baseline's.

**Residual risks:**
- `config/routes.rb` now autoloads `Catalog::SetKind`, a plain module that does not load `ApplicationRecord`. Boot, eager load and the test suite pass; reloading routes in development was not exercised by hand.
