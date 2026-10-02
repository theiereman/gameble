---
title: 'Catalog schema and draft season'
type: 'feature'
ticket: '2'
created: '2026-10-02'
status: 'built'
baseline_revision: 'a9ee53a4be4d60612337ebc04e66ca417defc8a8'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: ['{project-root}/_bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md', '{project-root}/_bmad-output/initiative-gameble/spec-gameble/catalog-and-rarity.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** `Catalog` is an empty pack: there is nowhere to put a card, its texts, its season, its rarity or its sets, and no way for `Steam` to write a card without knowing `Catalog`'s tables (epic 2, R4, R5, R6).

**Approach:** Add the `Catalog` models of the spine's ER diagram with generic, Steam-free fields, the rarity tiers and dust levels defined once, and one operation, `Catalog::UpsertDraftCard`, through which any source writes a card into the draft season idempotently, keyed by an opaque source key.

## Boundaries & Constraints

**Always:**
- Tables prefixed `catalog_`; nothing in `packs/catalog` names Steam (AD-4): the source key is an opaque string built by the caller.
- `Catalog::Rarity::TIERS = { 1 => :steel, 2 => :emerald, 3 => :sapphire, 4 => :amethyst, 5 => :gold }` and `Catalog::Dust::LEVELS = { 0 => :none, 1 => :light, 2 => :marked, 3 => :thick, 4 => :buried }` (DESIGN.md, Dust), keys only; labels belong to locale files, age thresholds to story 2.6, odds to `Game`. Migrations hard-code `rarity BETWEEN 1 AND 5`, `dust_tier BETWEEN 0 AND 4`.
- Card fields — required: `source_key`, `release_date`, `image_url`, `store_url`, `en` and `fr` titles, `prestige_score` (double, NOT NULL), `rating` (numeric(5,2), NOT NULL, 0–100); optional: `publisher`, `credit`, `short_description` (plain text, the caller strips HTML); `genres` and `tags` are `string[]` NOT NULL default `[]` (genres ordered, primary first; a card with no genre gets no tome in 2.7). Scores must be `Numeric`, never coerced from strings. Locales are `Catalog::CardText::LOCALES = %w[en fr]`, with a check constraint.
- Cards are addressed by a FriendlyId slug (AD-15, FriendlyId 5.7.0, no history module, no `friendly_id_slugs` table). Candidates: English title, then title + release year, then a random suffix when the title parameterizes empty (non-Latin titles). The slug is set once and never changes, so card URLs and share links (CAP-7, CAP-9) stay stable.
- Seasons: `number` unique, `status` string enum `draft`/`published` with a check constraint, `published_at`; one draft at most (partial unique index on `(true) WHERE status = 'draft'`, like `steam_import_runs`); a new draft takes `MAX(number) + 1`. "The published season" for later stories is the highest-numbered published one.
- Card fields and texts are card identity, updated in place by every upsert, published season included. Season data — `rarity`, `dust_tier` and set memberships — is frozen once its season is published (AD-5). A card-season is never deleted or recreated; `rarity` and `dust_tier` stay NULL until publish.
- The operation locks the draft season row `FOR SHARE`, so story 2.6's `PublishSeason` (`FOR UPDATE`, status re-checked) cannot publish under an upsert in flight.
- Every unique index the operation can meet (draft, number, source key, card + season, card + locale) is handled with a `requires_new` savepoint and a re-read, as `Steam::StartImport` does; no `upsert_all` (it bypasses FriendlyId and validations).
- One event per call, even when nothing changed: `Catalog::DraftCardUpserted`, data `{ card_id:, season_id:, card_season_id: }`, stream `"Catalog::Season$#{season_id}"` (AD-10).
- Sets: `kind` string enum `publisher`/`tome`/`best_of_year` with a check constraint; `key` URL-safe (parameterized), unique per season + kind; `position` on the membership (order within a set); a membership's card-season and set share a season (model validation).

**Never:** no publishing, tier cutting, dust computation or set building (stories 2.6, 2.7); no removal of a card from the draft (a later operation, if 2.5 needs it); no call from `Steam` yet (2.5); no web page; no reference from `Catalog` to another pack.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| New card, no draft | valid attributes, no draft season | draft season created (next number), card with slug, both texts and card-season created, one event | — |
| Same source key again | changed title, score or rating | same card, texts, card-season updated in place; slug unchanged; row counts unchanged; one more event | — |
| Card known in a published season | source key known, season 1 published | card and texts updated; a new card-season in the draft; the published card-season row unchanged | — |
| Non-Latin or taken title | title parameterizes empty, or slug taken | slug falls back (title + year, then random suffix) | — |
| Missing locale | `fr` or `en` text absent or blank title | nothing written | `Failure(:missing_text)` |
| Bad attributes | blank source key, image or store URL; no release date; score or rating nil, non-Numeric, or rating outside 0–100; a locale other than `en`/`fr` | nothing written | `Failure(:invalid_card)` |
| Races | two first upserts at once, or the same source key twice at once | one draft, one card, one card-season | savepoint + re-read on the unique index |

</frozen-after-approval>

## Code Map

- `lib/application_operation.rb`, `lib/application_record.rb` -- bases for operations and models.
- `packs/steam/app/operations/steam/start_import.rb` -- golden example of a savepoint around a create that meets a unique index.
- `db/migrate/20261002200000_create_steam_import_runs_and_apps.rb` -- golden example of a status check constraint written with `OR` (the `IN (...)` form dumped unstably) and a partial unique index on `(true)`.
- `packs/accounts/app/events/accounts/player_registered.rb` -- event shape (identifiers only).
- `packs/catalog/package.yml` -- depends on `lib` only; keep it so.
- `config/locales/{en,fr}.yml` -- failure messages under `errors.catalog.<code>`.
- `test/packs/steam/import_operations_test.rb` -- operation test style (success, each failure, events read from the store).

## Tasks & Acceptance

**Execution:**
- [x] `Gemfile` -- add `friendly_id ~> 5.7.0`.
- [x] `db/migrate/*_create_catalog.rb` -- `catalog_cards`, `catalog_card_texts`, `catalog_seasons`, `catalog_card_seasons`, `catalog_sets`, `catalog_set_memberships` with the columns, nullability, checks and indexes of the Boundaries.
- [x] `packs/catalog/app/models/catalog/{card,card_text,season,card_season,set,set_membership,rarity,dust}.rb` -- associations, validations, enums, slug candidates.
- [x] `packs/catalog/app/operations/catalog/upsert_draft_card.rb`, `app/events/catalog/draft_card_upserted.rb` -- the operation of the matrix; returns `Success(card_season)`. Texts are built before the card is saved, so the slug sees the English title.
- [x] `packs/catalog/app/queries/catalog/{draft_season,published_season}.rb` -- the draft or nil; the highest published or nil.
- [x] `config/locales/{en,fr}.yml` -- `errors.catalog.missing_text`, `errors.catalog.invalid_card`.
- [x] `test/fixtures/catalog/*.yml`, `test/packs/catalog/*_test.rb` -- every matrix row, the database constraints (tiers, dust, rating, locale, one draft), the published card-season left untouched.

**Acceptance Criteria:**
- Given the operation called twice with the same source key, when the second call changes the English title, then there is one card with its first slug, one card-season in the draft, and the new title.
- Given `grep -riw steam packs/catalog`, when run, then nothing matches.
- Given `bin/rails test` and `bundle exec packwerk check`, when run, then both pass.

## Implementation Notes

- `prestige_score` and `rating` live on `catalog_card_seasons`, not `catalog_cards`: the matrix updates "the card-season in place" on a changed score or rating, leaves the published card-season unchanged, and rating is "kept per season". They are frozen with rarity and dust tier once the season is published (`CardSeason::SEASON_DATA`).
- Freezing is a model validation (`CardSeason`, `SetMembership`, `:frozen_once_published`): story 2.6's `PublishSeason` must write rarity, dust tier and memberships before it flips the season to `published`.
- Slug candidates: English title, title + year, title + year + 6 random characters; a title that parameterizes empty goes straight to year + random characters (`2011-x7k2qp`). `attr_readonly :slug` makes the slug unchangeable. A slug taken by a concurrent writer meets the slug index and is retried with the next candidate.
- Texts accept only `title` and `short_description`; any other key, a non-String description, or a non-Hash text is `:invalid_card`. A blank `publisher` or `credit` is stored as NULL. Genres and tags must be arrays of non-blank strings.
- Model error messages live under `activerecord.errors.messages` and are ignored by `i18n-tasks unused` (looked up dynamically).
- Races are tested by stubbing the finder seams (`find_draft_season`, `find_card`, `find_text`, `find_card_season`), as the Steam tests do; no multi-connection test.

## Plan Change Log

## Review Triage Log

### Pass 1 (quick) — high 0, medium 2, low 5, false 0, maybe-false 0

| # | Verdict | Route | Finding | Evidence / action |
|---|---|---|---|---|
| 1 | medium | patch | `Set::KEY_FORMAT` rejects the `_` that `parameterize` keeps, so story 2.7's keys would fail | Confirmed (`"Foo_Bar Studio".parameterize` is `foo_bar-studio`). Format allows `_`; test added. |
| 2 | medium | patch | A card-season can be created in a published season; `season_id`/`card_id` changes not caught (AD-5) | Confirmed: validation ran on update only. Now on create too, ids read-only, destroy refused in a published season; tests added. |
| 3 | low | patch | A membership of a published season can be destroyed | Confirmed. Destroy refused for a published season; test added. |
| 4 | low | patch | A non-String title returns `missing_text` | Confirmed. Now `invalid_card`; test cases added. |
| 5 | low | patch | Blank publisher/credit stored as NULL is untested | Test added. |
| 6 | low | rejected | The slug-index race is not tested | Handled by the shared `RecordNotUnique` retry loop; a concurrent slug collision on a new card is unlikely in a single-writer import, and the fix is test-only plumbing. |
| 7 | low | rejected | `"en"` and `:en` both passed: one silently wins | Unlikely (story 2.5 is the only caller and builds string keys); the fix adds a guard branch. |


## Design Notes

The operation's keywords are the contract story 2.5 calls; `Steam` maps its fields onto them without knowing the tables:

```ruby
Catalog::UpsertDraftCard.new.call(
  source_key: "<source>:620", publisher: "…", credit: nil, release_date: Date.new(2011, 4, 18),
  genres: %w[action adventure], tags: %w[puzzle co-op], image_url: "https://…", store_url: "https://…",
  texts: { "en" => { title: "Portal 2", short_description: "…" }, "fr" => { title: "Portal 2", short_description: "…" } },
  prestige_score: 0.97, rating: 98.0
)
```

`rating` is the source's review score in percent, kept per season for the best-rated sets; `prestige_score` is opaque to `Catalog` and only ordered.

## Verification

**Commands:**
- `bin/rails test` -- expected: all green.
- `bundle exec packwerk check && bin/rubocop && bundle exec i18n-tasks missing` -- expected: no offence.
- `grep -riw steam packs/catalog` -- expected: no match.
