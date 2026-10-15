---
title: 'The retired set kinds removed'
type: 'refactor'
ticket: '4'
created: '2026-10-15'
status: done
baseline_revision: '747c7f2b4e7d4d3d73b2d86d0979553e5a3a6484'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Staging's season 1 still holds tomes, publisher sets and best-of-year sets, with their completions. Because of them, the set kind check keeps the three retired kinds, and their code lives on in the model, the labels, the routes, the shelf, the back-office and about 20 tests. Season 2 is themed and published, so those sets earn no tier and show only on season 1's own card pages.

**Approach:** One migration deletes the retired sets in every season, together with their memberships, tiers and completion rows. A second migration narrows the kind check to the five kinds, unvalidated, and a third validates it. The retired-kind code, fixtures and tests go.

**Decision (author, 2026-10-15):** no rebuild of season 1. Its card-seasons keep no set and no main theme. AD-5 and AD-10 are amended.

## Boundaries & Constraints

**Always:**
- The delete touches only sets whose kind is `tome`, `publisher` or `best_of_year`, and only the rows hanging off those sets. Every other set, membership, tier and completion is unchanged. So are holdings, card-seasons, feed entries and achievement unlocks.
- Rows are deleted in foreign-key order: memberships, tiers, sets. Completions are deleted by set id; they have no foreign key.
- The delete migration is irreversible (`down` raises). The narrowing is reversible. The check is written as equalities (OR), as `20261013090000` did, so it round-trips in `db/schema.rb`.
- A season-1 card page renders with no set list and no genre. It never raises.
- The published season's screens, tabs and routes are unchanged for the five kinds.

**Never:**
- No `RebuildSeasonSets`, no event, no rake task, no manual step.
- No change to `PublishSeason`, `SetBuilder` or the set rules.
- No player tier rows (entry 5).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Retired season | season 1 with tome, publisher and best-of-year sets, memberships and completions; season 2 themed, with completions | season 1 has no set, membership or tier; its completions are gone; season 2's sets and completions are untouched | — |
| Fresh database | no retired kind | nothing deleted; check narrowed | — |
| Insert a tome | after migrating | — | the check refuses it |
| Season-1 card page | `/cards/:slug/seasons/1` | 200, no sets listed, no genre | — |
| Old library URL | `/library/tome/action-1` | 404 (the route no longer matches) | — |

</frozen-after-approval>

## Code Map

- `db/migrate/` -- three migrations:
  1. delete the retired kinds' rows in SQL (`execute`);
  2. replace `catalog_sets_kind_check` with the five kinds, unvalidated: `remove_check_constraint` with the current expression from `db/schema.rb:164`, then `add_check_constraint ... validate: false`, as `20261012120002` did;
  3. `validate_check_constraint`.

  Regenerate `db/schema.rb` on Postgres 18.
- `packs/catalog/app/models/catalog/set.rb` -- the enum keeps the five kinds. `BUILT_KINDS` becomes the five, or goes if the enum's keys serve; it is read by `season_summaries.rb:25`, `season_scores.rb:37` and `back_office/seasons/index.html.erb:26,45`. Rewrite the header comment.
- `app/components/set_label.rb` -- drop the `publisher`, `tome` and `best_of_year` branches, `tome_genre` and the tome `heading` years. Keep `heading` only if a caller still needs it, otherwise inline its callers to `for`.
- `packs/catalog/app/queries/catalog/season_shelf.rb:6-44` -- drop the retired orders and CASE branches.
- `packs/catalog/app/queries/catalog/card_detail.rb:15,39-40` -- `KIND_ORDER` keeps the five. The card's `publisher` field stays: it is the card's identity, not a kind.
- `app/controllers/concerns/shelf_loading.rb:18` `KINDS`, and `config/routes.rb:26,40` -- the five kinds.
- Locales, in en and fr:
  - drop `catalog.sets.tome`, `best_of_year` and `with_years`, and the `catalog.genres` block (`en.yml:1354`);
  - drop the retired entries of `library.show.tabs` and `empty`, `public_profiles.show.empty` and `back_office.seasons.index.sets`;
  - drop `"catalog.genres.*"` from `config/i18n-tasks.yml:27`;
  - grep the other uses before removing anything.
- `packs/game/lib/open_pack_benchmark.rb:180-184` -- its sets become theme sets (key from `Catalog::Themes`) or studio sets.
- Fixtures and tests:
  - `test/fixtures/catalog/sets.yml` (`valve_one`) and `set_memberships.yml` move to a five-kind set;
  - adapt or delete the retired-kind cases in the ~20 files that name them: `set_label_test`, `season_shelf_test`, `card_detail_test`, `schema_test:117-127,164-168`, `collection_summary_test`, `export_of_test`, `player_export_test`, the library, profile, cards, pages and back-office controller tests, `set_slots_test`, `set_neighbours_test`, `collection_grid_test`, `draft_preview_test`, `season_scores_test`, `card_preview_tags_test`, the system tests `card_detail_test` and `public_profile_test`, and `app/frontend/lib/history_trail.test.ts`;
  - a case that tested a retired kind only for its own sake goes, and its five-kind twin stays.
- Don't touch: `PublishSeason`, `SetBuilder`, `SetCompletion`, `catalog_cards.publisher`.

## Tasks & Acceptance

**Execution:**
- [x] Migrations and `db/schema.rb`.
- [x] Model, label, queries, controller concern, routes, back-office view, benchmark: the five kinds only.
- [x] Locales and `i18n-tasks.yml`: `missing` and `unused` stay clean.
- [x] Fixtures and tests:
  - adapt them;
  - add a migration test with retired and themed seasons and completions (matrix rows 1–2), driven by the migration class's `up` on seeded rows;
  - `schema_test` refuses a tome;
  - a cards controller test renders a card-season with no set and no genre.

**Acceptance Criteria:**
- Given the code base, when grepping `app`, `packs`, `config` and `test` for `tome`, `best_of_year` or `kind: "publisher"`, then nothing refers to a set kind.
- Given the change, then `bundle exec packwerk check`, `TZ=UTC bin/rails test`, `npm run test:js`, `bin/rails zeitwerk:check`, `bin/rubocop` and `bundle exec i18n-tasks missing`/`unused` pass.

## Implementation Notes

- `Catalog::Set::BUILT_KINDS` is gone; `Set.kinds.keys` (the enum, in tab order) feeds `SeasonSummaries`, `SeasonScores` and the back-office index.
- `SetLabel.heading` is gone with the tome's year range; its one caller (`public_profiles/set.html.erb`) reads `SetLabel.for`.
- The fixture `valve_one` is a studio set (`{ "studio": "Valve" }`), so tests keep its label "Valve"; the benchmark seeds studio sets.
- `test/system/tome_test.rb` became `collection_set_test.rb`: it tested no tome, only carried the name.
- The migration test validates the check by SQL: strong_migrations refuses `validate_check_constraint` inside the test's transaction; the validation migration itself runs in `db:migrate`.
- Verification: `TZ=UTC bin/rails test` 2598 runs, 0 failures; `npm run test:js` 328 passed; packwerk, zeitwerk, rubocop (758 files), `i18n-tasks missing` clean; `i18n-tasks unused` reports the pre-existing `rate_limit.*` keys only (deferred).

## Review Triage Log

### 2026-10-15 — Review pass (quick)
- verdicts: 4 findings — high 0, medium 0, low 3, false 0, maybe-false 0, pre-existing 1
- findings:
  - `[low]` `[patch]` `delete_retired_set_kinds_migration_test.rb`: `untouched_counts` compared holdings, feed entries and achievement unlocks that the test never created (no game fixtures), so "every other row stays" checked nothing for them — the test now creates one of each before counting.
  - `[low]` `[patch]` The fresh-database test ran only the delete; the tome refusal came from the test schema, not the migrations — it now widens the check and runs the three migrations.
  - `[low]` `[patch]` AD-5 still said sets are identified "across seasons and rebuilds" while its amended rule says nothing rebuilds a published season's sets — "and rebuilds" removed.
  - `[defer]` `bundle exec i18n-tasks unused` reports `rate_limit.reading_throttled` and `rate_limit.throttled` (en, fr), read dynamically in `config/initializers/rack_attack.rb:53` — pre-existing at the baseline, untouched by this change.

## Design Notes

- **Data in a migration:** production never held the retired kinds, and staging and dev databases converge in one deploy. AD-5 now names this migration.
- **Order:** the delete runs before the narrowing, so the validation passes on staging in the same deploy. The old container never inserts sets: only a back-office publication does.

## Verification

**Commands:**
- `RAILS_ENV=test bin/rails db:drop db:create db:migrate` -- expected: the `db/schema.rb` diff holds only the narrowed check
- `TZ=UTC bin/rails test`, `npm run test:js`, `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `bin/rubocop`, `bundle exec i18n-tasks missing`, `bundle exec i18n-tasks unused` -- expected: green
