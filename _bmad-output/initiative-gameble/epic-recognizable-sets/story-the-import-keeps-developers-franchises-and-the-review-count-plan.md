---
title: 'The import keeps developers, franchises and the review count'
type: 'feature'
ticket: '2'
created: '2026-10-09'
status: done
baseline_revision: '0a34aa0aed83af7787797c8569839da7f5d51bc3'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Franchise and studio sets need each card's Steam developers and franchises, and hall of fame sets need each card-season's review count; the import stores neither on the catalog, though every Steam app's raw item already holds developers and franchises (spike 13.1).

**Approach:** Read developers and franchises from the stored raw item, carry them and the review count through the draft upsert onto the card and the card-season (frozen at publication like the other season data), and fill the cards and card-seasons already imported once, from the stored Steam rows, through a rake task, without a new import.

## Boundaries & Constraints

**Always:** Catalog sees only plain values, never a Steam record. Names are HTML-unescaped and stripped, kept in Steam's order, duplicates dropped. Writes go through operations that publish one event. Schema changes are expand-only (column, then check added unvalidated, validated in a second migration). Every new string in `en.yml` and `fr.yml`.

**Never:** No filtering of franchises or studios (story 3's builder does it). No new Steam call. No change to the published season's other data. No set kind, theme or builder change.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Import writes a card | app whose `details.basic_info` names developers `["Valve"]` and franchises `["Half-Life"]`, 1,000 reviews | card has `developers ["Valve"]`, `franchises ["Half-Life"]`; draft card-season `review_count 1000` | — |
| Entities and blanks | names `"Command &amp; Conquer"`, `" "`, a non-Hash entry, a duplicate | `["Command & Conquer"]` | malformed entries dropped |
| No basic_info / no franchises key | details without them | `[]` | — |
| Re-import of a published card | card in published season 1, draft season 2 | card's developers/franchises updated; season 1's card-season untouched; season 2's gets the new count | — |
| Upsert given bad values | developers not an Array of present Strings, or review_count 0 / non-Integer | `Failure(:invalid_card)` | card refused, as today |
| Backfill | cards and card-seasons imported before this story | developers, franchises filled; every card-season with a NULL review count gets the app's stored count, published ones included | idempotent; a card-season that has a count is left alone |
| Backfill, unknown source key | Steam app with no card | ignored | — |

</frozen-after-approval>

## Code Map

- `packs/steam/app/models/steam/details_policy.rb` -- `publishers(item)` reads `basic_info` names (strip only); add public `developers(item)` and `franchises(item)` over a shared name reader that also unescapes (`CGI.unescapeHTML`) and dedupes. `details` stores the whole English item.
- `packs/steam/app/models/steam/app.rb` -- add `developers` / `franchises` readers over `details` via `DetailsPolicy`.
- `packs/steam/app/models/steam/card_mapping.rb` -- the keyword hash for the upsert; add `developers:`, `franchises:`, `review_count: app.review_count` (already validated ≥ 1 there).
- `packs/catalog/app/operations/catalog/upsert_draft_card.rb` -- `validate_card` / `validate_scores` / `upsert_card_season`; add the three keywords (`developers: [], franchises: [], review_count: nil` so `db/seeds.rb` keeps working).
- `packs/catalog/app/models/catalog/card_season.rb` -- `SEASON_DATA` gains `review_count`; validate integer ≥ 1, nil allowed.
- `packs/catalog/app/models/catalog/card.rb` -- doc of identity fields.
- `packs/catalog/app/operations/catalog/publish_season.rb` -- `number_published` is the precedent for a one-off fill of published card-seasons with `update_all`.
- `packs/catalog/lib/tasks/catalog.rake`, `packs/game/lib/tasks/game.rake` -- rake precedents (idempotent, `abort` on failure, "Meant for production: run once after the deploy").
- `test/packs/catalog/upsert_draft_card_test.rb`, `test/packs/steam/cards_test.rb`, `test/packs/catalog/schema_test.rb` -- extend.
- Don't touch: `Steam::GenreTags`, `Catalog::SetBuilder`, `ImportCardsPage` flow.

## Tasks & Acceptance

**Execution:**
- [x] `db/migrate/*_add_developers_and_franchises_to_catalog_cards.rb` -- string arrays, default `[]`, NOT NULL.
- [x] `db/migrate/*_add_review_count_to_catalog_card_seasons.rb` then `*_validate_…` -- integer, nullable; check `review_count IS NULL OR review_count >= 1` added `validate: false`, validated in the second migration; regenerate `db/schema.rb` on Postgres 18.
- [x] `packs/steam/app/models/steam/details_policy.rb`, `app.rb`, `card_mapping.rb` -- read and pass the three values.
- [x] `packs/catalog/app/operations/catalog/upsert_draft_card.rb`, `models/catalog/card_season.rb`, `card.rb` -- accept, validate, store; review count frozen with the season data.
- [x] `packs/catalog/app/operations/catalog/fill_card_sources.rb` + event `Catalog::CardSourcesFilled` -- given rows `{ source_key:, developers:, franchises:, review_count: }`, in one transaction: set each existing card's developers and franchises, and the review count of its card-seasons where NULL (`update_all`, the documented one-off exception to frozen season data); one event with the counts; idempotent.
- [x] `packs/steam/lib/tasks/steam.rake` -- `steam:fill_card_sources`: walks `Steam::App` rows holding details and a review count in appid batches, builds the rows with `CardMapping`, calls the operation per batch, prints the counts, aborts on a Failure; check the task is loaded like the other packs' tasks.
- [x] Tests -- DetailsPolicy readers (entities, blanks, malformed, missing keys), CardMapping, upsert (stored, invalid values refused, published card-season untouched), fill operation (fills, idempotent, unknown key ignored, published card-season gets its NULL count once), the import end to end, schema test for the check.

**Acceptance Criteria:**
- Given a fresh import run, when its cards pass ends, then every card whose stored item names developers or franchises has them, and every draft card-season has its review count.
- Given a database imported before this story, when `bin/rails steam:fill_card_sources` runs twice, then the first run fills the cards and card-seasons and the second changes nothing.
- Given the change, then `bundle exec packwerk check`, `bin/rails test`, `bin/rails zeitwerk:check` and `bin/rubocop` pass.

## Implementation Notes

- `Steam::DetailsPolicy.publishers` is unchanged (strip only); `developers` and `franchises` share a private `names` reader that unescapes, strips and dedupes. They read either a raw item or the stored `details` (whose `basic_info` is the English item's).
- `Steam::CardMapping.sources(app)` builds the fill's row; a stored review count below 1 maps to nil, so the row fills the names but no card-season.
- The review count's bounds (`Catalog::CardSeason::REVIEW_COUNTS`, the integer column) are shared by the model, the upsert and the fill.
- `Catalog::FillCardSources` refuses a malformed row with the existing `:invalid_card` code (no new string); duplicate source keys in one call keep the last row. It writes in two `update_all` joined to `jsonb_to_recordset`, touching only cards whose names differ and card-seasons whose count is NULL, so a second run changes no row. Its event goes on the stream `Catalog::CardSources`, once per call, counts only.
- `steam:fill_card_sources` walks apps holding details and a review count, 1,000 by appid, one operation call (and one event) per batch; queued in `pending-approvals.md` for staging and production.
- Two suite failures are pre-existing and date-dependent (they fail on the baseline too, on 2026-10-12, across the end of daylight saving time): `SessionsControllerTest` "signing in keeps the player signed in for 30 days" and `Game::TradesOfTest` "finished trades are recent ... for 14 days".

## Plan Change Log

## Review Triage Log

### 2026-10-12 — Review pass
- verdicts: 2 findings — high 0, medium 1, low 1, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` (quick) `steam:fill_card_sources` walked only apps holding a review count, so an app a later reviews run marked unavailable (`ImportReviewsPage` writes `review_count` NULL and keeps `details`) never gave its existing card developers and franchises, against the matrix's Backfill row — the task now filters on `details` only; a NULL count fills the names and no card-season.
  - `[low]` `[patch]` (quick) `FillCardSources#valid_row?` sorted the row's keys, so a row mixing String and Symbol keys raised `ArgumentError` instead of `Failure(:invalid_card)` — keys compared as sets.

## Design Notes

The backfill gives a published card-season the review count of the latest import, not the one at its publication, which no stored row keeps; for the hall of fame's thresholds the gap is small. On staging the author runs `steam:fill_card_sources` after the deploy (queued in `pending-approvals.md`), since this session cannot reach staging.

## Verification

**Commands:**
- `bin/rails test test/packs/catalog test/packs/steam` -- pass
- `bin/rails test` and `bin/rails zeitwerk:check` -- pass
- `bundle exec packwerk check` and `bin/rubocop` -- no offenses
- `RAILS_ENV=test bin/rails db:drop db:create db:migrate` -- `db/schema.rb` diff holds only the new columns and check
