---
title: 'Publish a season with its tiers'
type: 'feature'
ticket: '6'
created: '2026-10-02'
status: done
baseline_revision: '761439ebb03adea85068ec77b3c7ac29205bc159'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: ['{project-root}/_bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md', '{project-root}/_bmad-output/initiative-gameble/spec-gameble/catalog-and-rarity.md', '{project-root}/_bmad-output/initiative-gameble/epic-steam-catalog/story-catalog-schema-and-draft-season-plan.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Cards gather in a draft season with a prestige score but no rarity or dust, and nothing makes a season visible to the game (epic 2, R6).

**Approach:** Add `Catalog::PublishSeason`, started by an administrator from a back-office seasons page: in one transaction it locks the draft, cuts prestige scores into the five tiers by percentile shares held in one place, sets each card-season's dust tier from the game's age on the publication date, then flips the season to published. Add the query the game will draw from: the published season's card-seasons by tier.

## Boundaries & Constraints

**Always:**
- `Catalog::RarityThresholds::SHARES` holds, once, each tier's share of the season's cards from the top, in integer basis points keyed by the `Rarity::TIERS` integers: `{ 5 => 100, 4 => 400, 3 => 1_000, 2 => 2_500 }` (gold 1 %, amethyst 4 %, sapphire 10 %, emerald 25 %); steel takes the rest. Starting values, calibrated by story 2.8; a test asserts they sum below 10,000.
- The cut, a pure function over the scores, integers only: cards ranked 1..N by score descending; for each tier from gold down, `k = ceil(cumulative_bp × N / 10_000)` (`(cum_bp * n + 9_999) / 10_000`), its threshold is the score at rank `k`; a card's tier is the highest whose threshold its score reaches, steel otherwise. Equal scores always share a tier. 21 distinct scores is the smallest season with no empty tier (1/1/2/5/12).
- Dust, a pure function next to `Catalog::Dust`: the age in completed years between `release_date` and the publication date (`pub.year - rel.year`, minus 1 when the publication's month/day precedes the release's; a 29 February release has its anniversary on 1 March in common years; a negative age counts as 0): < 1 none, 1–4 light, 5–9 marked, 10–19 thick, ≥ 20 buried (DESIGN.md, Dust). Computed in Ruby, written with grouped `update_all`; no SQL `age()`.
- `PublishSeason.new.call(number:)`, as named steps so story 2.7 inserts `build_sets` before the flip: (1) lock the draft `FOR UPDATE` (upserts hold `FOR SHARE`, so publishing waits for those in flight) and check its number — `no_draft` when there is no draft, `stale_draft` when the number differs; (2) `empty_season` when it has no card-season; (3) cut — `empty_tier` when a tier would hold no card; (4) write every card-season's `rarity` and `dust_tier` (bulk SQL while still a draft; the freeze validation applies once published); (5) `build_sets` — a no-op left for story 2.7; (6) `status: published`, `published_at = now` (one `now`, its UTC date is the publication date); (7) publish `Catalog::SeasonPublished` (`{ season_id: }`). All guards run before any write. The next upsert opens a new draft (story 2.2's rule).
- `Catalog::PublishedCardSeasonsByTier.call` returns `{ season_id:, tiers: { 1 => [ids], …, 5 => [ids] } }` for the highest published season, all five keys present, or nil when none is published; it uses the current connection (the draw runs in a write transaction).
- Back-office, administrators only (policy tested for visitor, player, moderator): `/<locale>/back-office/seasons` lists seasons (number, status, card count, published at, count per tier once published); the draft has a publish form — `post :publish, on: :collection`, sending the draft's `number` — behind a confirmation. `ButtonComponent` gains a `confirm:` option rendered as `form: { data: { turbo_confirm: } }`. The controller refuses to publish while a Steam import run is active (a `Steam` query; `Catalog` cannot ask), so a run is never split across two seasons. The dashboard shows the link when `policy([:back_office, :seasons]).index?`.
- Locale keys in `fr` and `en`: `catalog.rarity.{steel,emerald,sapphire,amethyst,gold}` (generic, reused by later epics), `back_office.seasons.*`, `errors.catalog.{no_draft,stale_draft,empty_season,empty_tier}`, and the import-active refusal.
- Tests seed card-seasons with `insert_all` (slugs set) in a helper rather than through `UpsertDraftCard`; the 1,000-card cases run on the pure function.

**Never:** no set building (story 2.7); no Steam reference in `Catalog`; no draw (epic 3); no change to a published season.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Cut, round count | 1,000 distinct scores | gold 10, amethyst 40, sapphire 100, emerald 250, steel 600 | — |
| Cut, other count | 150 distinct scores | 2 / 6 / 15 / 37 / 90 | — |
| Ties | 100 scores, ranks 1–3 equal | gold 3, amethyst 2, sapphire 10, emerald 25, steel 60 | — |
| Tie over two cuts | one score covers the gold and amethyst ranks | nothing written | `Failure(:empty_tier)` |
| Too small | 20 distinct scores | nothing written | `Failure(:empty_tier)` |
| Dust (published 2026-10-02) | released 2026-04-02, 2025-10-02, 2025-10-03, 2021-10-03, 2021-10-02, 2016-10-02, 2006-10-03, 2006-10-02, 1996-01-01, 2027-01-01 | none, light, none, light, marked, thick, thick, buried, buried, none | — |
| Publish | draft of 150 card-seasons, number matches | rarities and dust set, season published, one event | — |
| No draft / twice | no draft, or a second publish | nothing changes | `Failure(:no_draft)` |
| Stale page | form number ≠ the draft's | nothing changes | `Failure(:stale_draft)` |
| Empty draft | draft with no card-season | nothing changes | `Failure(:empty_season)` |
| Import running | a Steam run is active | nothing changes | refused by the controller |
| After publish | upsert of a known card | a new draft (next number) | — |
| Query | published 1, draft 2 / nothing published | season 1's ids by tier / nil | — |
| Not admin | visitor / player / moderator | sign-in redirect / 403 / 403 | policy |

</frozen-after-approval>

## Code Map

- `packs/catalog/app/models/catalog/{season,card_season,rarity,dust,card}.rb` -- enums and the freeze validation (write season data before the flip).
- `packs/catalog/app/operations/catalog/upsert_draft_card.rb` -- draft locked `FOR SHARE`; golden example of a Catalog operation and its event.
- `packs/catalog/app/queries/catalog/{draft_season,published_season}.rb` -- reuse.
- `packs/steam/app/models/steam/import_run.rb` (`active` scope) -- add a `Steam` query for "a run is active" for the controller.
- `app/components/button_component.rb` + its test -- add `confirm:`.
- `app/controllers/back_office/import_runs_controller.rb`, `app/policies/back_office/import_runs_policy.rb`, `app/views/back_office/import_runs/index.html.erb`, `app/views/back_office/dashboard/show.html.erb`, `config/routes.rb` -- golden example of an admin page.

## Tasks & Acceptance

**Execution:**
- [x] `packs/catalog/app/models/catalog/{rarity_thresholds,dust}.rb` -- shares, cut, dust age.
- [x] `packs/catalog/app/operations/catalog/publish_season.rb`, `app/events/catalog/season_published.rb`.
- [x] `packs/catalog/app/queries/catalog/{published_card_seasons_by_tier,season_summaries}.rb` -- `SeasonSummaries` is `Season.order(:number)` plus one grouped count.
- [x] `packs/steam/app/queries/steam/active_import_run.rb`.
- [x] `app/components/button_component.rb`, `app/controllers/back_office/seasons_controller.rb`, `app/policies/back_office/seasons_policy.rb`, views, routes, dashboard link, locales.
- [x] `test/` -- every matrix row, the shares sum, the component's `confirm:`, policy and controller per role.

**Acceptance Criteria:**
- Given a draft of 150 card-seasons and no active import, when an administrator publishes it from the seasons page, then the page shows it published with 2 / 6 / 15 / 37 / 90 per tier, and the published-season query returns its card-seasons only.
- Given `bin/rails test`, `bundle exec packwerk check`, `bin/rubocop` and `bundle exec i18n-tasks missing`, when run, then all pass.

## Implementation Notes

- `RarityThresholds` exposes `thresholds(scores)` (gold first), `tier_of(score, thresholds)` and `tiers(scores)` (one tier per score in input order, nil when a tier would be empty); `STEEL` is the one tier not in `SHARES`.
- `Dust.age(release_date, on:)` compares `month * 100 + day`; a 29 February release then naturally has its anniversary on 1 March in common years. `Dust.level_for` maps the age through `MIN_AGES`.
- `PublishSeason` writes season data with one `update_all` per (rarity, dust) pair; `build_sets` is an empty step for story 2.7.
- `SeasonSummaries` returns `Summary` value objects (`number`, `status`, `published_at`, `card_count`, `tier_counts` — nil for the draft).
- `Steam::UnfinishedImportRun.call` returns the latest run (by created_at, id) unless it completed, else nil: a failed run can be resumed, so it blocks publishing too (review fix). The controller parses `number` with `Integer(…, 10, exception: false)`; a non-number is `stale_draft`.
- `ButtonComponent` raises when `confirm:` is given without `method:` (only forms carry it).
- Tests seed through `test/support/catalog_seeds.rb` (`insert_all!`, slugs set).

## Plan Change Log

## Review Triage Log

### Pass 1 (quick) — high 0, medium 1, low 2, false 0, maybe-false 0

| # | Verdict | Route | Finding | Evidence / action |
|---|---|---|---|---|
| 1 | medium | patch | A failed run resumed after a publication is split across two seasons; the guard only checked pending/running runs | Confirmed (`ResumeImport` resumes failed runs at any time). Guard is now `Steam::UnfinishedImportRun`: publishing needs the latest run completed; copy updated; two controller tests. |
| 2 | low | rejected | The import check and the publish lock can race | Needs two administrator actions in the same instant; closing it needs a lock across `Steam` and `Catalog`, which AD-2 forbids. |
| 3 | low | patch | The UTC publication-date test cannot fail | Confirmed (`config.time_zone` is UTC). Test now runs in `Pacific/Honolulu` at an instant whose local date differs. |


## Verification

**Commands:**
- `bin/rails test` -- expected: all green.
- `bundle exec packwerk check && bin/rubocop && bundle exec i18n-tasks missing` -- expected: no offence.
