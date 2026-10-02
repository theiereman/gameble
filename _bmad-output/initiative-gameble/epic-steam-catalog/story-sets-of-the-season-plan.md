---
title: 'Sets of the season'
type: 'feature'
ticket: '7'
created: '2026-10-02'
status: 'built'
baseline_revision: 'b33e0aafd658850fa02a5f574fe3ef984246bb70'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: ['{project-root}/_bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md', '{project-root}/_bmad-output/initiative-gameble/spec-gameble/catalog-and-rarity.md', '{project-root}/_bmad-output/initiative-gameble/epic-steam-catalog/story-publish-a-season-with-its-tiers-plan.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A published season has rarities and dust but no sets, so a collection has nothing to complete (epic 2, R7; CAP-6).

**Approach:** Fill `PublishSeason`'s `build_sets` step: before the season flips to published, in the same transaction, build the season's publisher sets, genre tomes and best-rated-of-the-year sets from its card-seasons and their cards, with their members in order.

## Boundaries & Constraints

**Always:**
- The row loading moves out of `PublishSeason` into a public `Catalog::SeasonRows.call(season_id)` (no lock of its own; `PublishSeason` calls it inside its transaction and keeps its `empty_season` check), whose single pluck and `Row` gain `card_id`, `publisher`, `genres`, `rating`; the step becomes `build_sets(season, rows)`. Story 2.8's preview reuses `SeasonRows` and the public per-kind `SetBuilder` methods. Pure builders in `Catalog::SetBuilder` (one method per kind) take those rows and return `[{ kind:, key:, params:, members: [card_season_id, …] }]`, unit-tested without the database (including one test on 15,000 synthetic rows). The step writes `Set.insert_all!(rows, returning: %w[id kind key])`, maps ids by `[kind, key]`, then inserts memberships (positions 1..n, contiguous) in slices of 5,000 — all before `flip`, so the freeze validations are not involved. It raises, rolling back the publication, if any key fails `Set::KEY_FORMAT`; genre, volume and year are read from `params`, never parsed back from a key. A draft that yields no set still publishes.
- Publisher sets: one per exact non-nil `publisher` with at least 5 cards. Key: `base = name.parameterize(locale: :en).presence || "publisher"`; publishers taken in byte order (`sort`), each gets the first unused of `base`, `base-2`, `base-3`, …. Members by `release_date`, then `card_id`. `params` `{ "publisher" => name }`.
- Tomes: a card sits in the tome of `genres.first` (none → no tome). A genre's n cards, by `release_date` then `card_id`, split into `v = [(n + TOME_SIZE / 2) / TOME_SIZE, 1].max` volumes with `SetBuilder::TOME_SIZE = 30` (about thirty each, integer arithmetic) of consecutive cards, the first `n % v` volumes one larger. Key `<genre>-<i>`; `params` `{ "genre" => genre, "volume" => i, "volumes" => v }`.
- Best rated of the year: one set per release year with at least one card, holding `min(10, n)` cards ranked by `rating` desc, then `prestige_score` desc, then `card_id` asc; positions follow the rank. Key the year; `params` `{ "year" => year }`.
- `Catalog::Set` gains the freeze rules `SetMembership` has: no change and no destroy once its season is published (tested).
- A `params` jsonb column on `catalog_sets` (NOT NULL, default `{}`) holds what a later screen needs to name a set. Set names and genre labels are rendered by the collection epic, not here.
- `SeasonSummaries` gains `set_counts` (`{ "publisher" => n, "tome" => n, "best_of_year" => n }` for a published season, nil for a draft) from one grouped count; the seasons page shows them in three columns with `data-season-sets-*` attributes; headers in `fr` and `en`.
- `seed_card_seasons` (test support) takes optional `publishers:`, `genres:`, `ratings:` and release dates, and writes an `en` and `fr` title per card (`"Seed <i>"`).

**Never:** no sets from tags (later); no set outside publication; no set labels or genre labels (collection epic); no change to a published season's sets; no Steam name in `Catalog`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Publisher threshold | A with 5 cards, B with 4, others nil | a set for A only, by release date then card id | — |
| Publisher keys | `Foo Bar`, `Foo Bar 2`, `foo-bar` (5 cards each); `株式会社`; `株式会社X` | `foo-bar`, `foo-bar-2`, `foo-bar-3` in byte order; `publisher`; `x` | — |
| Tome sizes | n = 10, 44, 45, 75, 89 | 1×10; 1×44; 23/22; 25/25/25; 30/30/29 | — |
| Tome keys | genre `free_to_play`, 12 cards | `free_to_play-1` | key not matching `KEY_FORMAT` → raise, rollback |
| No genre / first genre | `[]`; `[rpg, action]` | no tome; an `rpg` tome only | — |
| Best of year | 2011 with 12 cards, 2012 with 9, 2013 with exactly 10 | 10, 9 and 10 members | — |
| Ties | 2011: ranks 10 and 11 share a rating; another pair shares rating and prestige | the higher prestige gets in; the lower card id ranks first | — |
| One card, three sets | a card of publisher A, genre `action`, best of 2011 | member of all three | — |
| No set at all | 21 cards, no publisher ≥ 5, no genre | published, years' best-of sets only | — |
| Failure | the builder raises | nothing published | transaction rollback |
| Frozen | update or destroy a set of a published season | refused | validation |

</frozen-after-approval>

## Code Map

- `packs/catalog/app/operations/catalog/publish_season.rb` -- `card_seasons_of` and `Row`, `build_sets` before `flip`.
- `packs/catalog/app/models/catalog/{set,set_membership}.rb` -- `KEY_FORMAT`; copy `SetMembership`'s freeze rules onto `Set`.
- `packs/catalog/app/queries/catalog/season_summaries.rb`, `app/views/back_office/seasons/index.html.erb`, `config/locales/{en,fr}.yml`.
- `test/support/catalog_seeds.rb`, `test/packs/catalog/publish_season_test.rb`, `test/controllers/back_office/seasons_controller_test.rb`.

## Tasks & Acceptance

**Execution:**
- [x] `db/migrate/*_add_params_to_catalog_sets.rb`.
- [x] `packs/catalog/app/models/catalog/{set_builder,set}.rb`.
- [x] `packs/catalog/app/operations/catalog/publish_season.rb` -- rows and `build_sets`.
- [x] `SeasonSummaries#set_counts`, seasons page columns, locales; seeds options.
- [x] `test/` -- every matrix row; the 15,000-row builder test; publish end to end.

**Acceptance Criteria:**
- Given a draft of 150 card-seasons with scores `distinct_scores(150)` and varied ratings — publisher P with 5 cards and Q with 4 (the rest nil); genre `action` 75, `rpg` 44, none 31; release years 2011 × 12, 2012 × 9, 2015 × 129 — when an administrator publishes it, then it has 1 publisher set, 4 tomes (25/25/25 and 44) and 3 best-of-year sets (10, 9, 10), members in order, and the seasons page shows 1 / 4 / 3.
- Given `bin/rails test`, `bundle exec packwerk check`, `bin/rubocop` and `bundle exec i18n-tasks missing`, when run, then all pass.

## Implementation Notes

- `Catalog::SeasonRows` (`packs/catalog/app/queries/catalog/season_rows.rb`) returns `Row(id, card_id, prestige_score, rating, release_date, publisher, genres)` ordered by id; `PublishSeason#rows_of` wraps it with the `empty_season` check.
- `Catalog::SetBuilder.call(rows)` concatenates `publishers`, `tomes` and `best_of_year` (each public); kinds are the enum strings. `PUBLISHER_MIN_CARDS = 5`, `TOME_SIZE = 30`, `BEST_OF_YEAR_SIZE = 10`.
- `build_sets` raises `ArgumentError` on a key outside `Set::KEY_FORMAT`; the exception leaves the transaction and rolls the publication back (tested with the genre `Free To Play`).
- Matrix row "`株式会社X` → `publisher`": the stated rule (`name.parameterize(locale: :en).presence || "publisher"`) gives `x` for `株式会社X`, since the Latin `X` survives; the rule was followed. `publisher` is the key of a name with no Latin letter at all (`株式会社`); both cases are tested.
- `Catalog::Set` now refuses changes and destroys once its season is published, so `schema_test` creates its sets in a draft or with `insert_all!`. The `valve_one` fixture gained `params`.
- `seed_sets_draft` (the acceptance draft) lives in `test/support/catalog_seeds.rb`, shared by the operation and controller tests.

## Plan Change Log

- Review pass 1 (orchestrator, with the author's delegation to approve plans): the matrix row said `株式会社X` → `publisher`, contradicting the plan's own key rule (`parameterize(locale: :en).presence || "publisher"`), which keeps the Latin `X`. The rule stands; the example now reads `株式会社` → `publisher` and `株式会社X` → `x`, matching the code and its tests. KEEP the rule.

## Review Triage Log

### Pass 1 (quick) — high 0, medium 2, low 0, false 0, maybe-false 0, intent fix 1

| # | Verdict | Route | Finding | Evidence / action |
|---|---|---|---|---|
| 1 | — | intent fix | The matrix row `株式会社X` → `publisher` contradicts the plan's key rule; the code followed the rule | The example was wrong, not the rule (see Plan Change Log); row corrected. |
| 2 | medium | patch | A published set (or membership) could be moved to the draft by changing its foreign key, dodging the freeze (AD-5) | Confirmed: the freeze reads the season after the change. `Set#season_id`, `SetMembership#set_id` and `#card_season_id` are now read-only (as `CardSeason`'s); test added. |
| 3 | medium | patch | A genre outside `KEY_FORMAT` written by any non-Steam caller would make every publication raise (a 500) | Confirmed. `UpsertDraftCard` refuses such a genre as `invalid_card`; test row added; `PublishSeason`'s comment names the remaining raise. |


## Verification

**Commands:**
- `bin/rails test` -- expected: all green.
- `bundle exec packwerk check && bin/rubocop && bundle exec i18n-tasks missing` -- expected: no offence.
