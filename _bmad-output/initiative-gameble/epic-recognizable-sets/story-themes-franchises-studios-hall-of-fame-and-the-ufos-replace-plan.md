---
title: 'Themes and the UFOs replace the old sets'
type: 'feature'
ticket: '3'
created: '2026-10-12'
status: 'ready-for-dev'
baseline_revision: '224cc3934833c61bacd0d4b7a95d6a1a2d065e08'
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Publishing a season still builds tomes, publisher sets and best-of-year sets, and a card's genre comes from its tome. Players should get sets they recognize from the name.

**Approach:** The 42 themes of `spike-sets-on-real-data-probes/probe-3.rb` live in `Catalog`. Each theme has a key, its Steam tag names, and its English and French names from the spike report's table. The import stores as a card's `genres` the themes found among its 5 most-voted Steam tags, most-voted first. This replaces `Steam::GenreTags`, and `steam:fill_card_sources` refills `genres` for cards already imported. At publication, `SetBuilder` builds theme sets and the UFOs only, and `PublishSeason` records each card-season's main theme and writes each set's tier requirements as rows. The set kind check widens to every new kind (expand only). The current screens list and name the new sets, and a card's genre is its main theme.

**Decision (author, 2026-10-12):** franchise, studio and hall of fame sets are split out to follow-up work (`deferred-work.md`).

## Boundaries & Constraints

**Always:**
- A game joins every theme that one of its 5 most-voted tags belongs to. A game with none joins the UFOs (key `ufos`). The main theme is the first theme in vote order.
- Tier rows:
  - theme sets get bronze 10 %, silver 25 % and gold 50 % of their distinct cards, rounded up, plus `complete` at 100 %;
  - the UFOs get `complete` only.
- A theme's key comes from the theme list. Theme and UFO names come from `en.yml` and `fr.yml`.
- Once a season is published, its main themes, tier rows, sets and memberships never change.
- Every card of a published season belongs to at least one set.
- Schema changes are expand-only. Catalog receives plain values only.

**Never:**
- No franchise, studio or hall of fame sets (deferred).
- No player tier rows, events or celebration.
- No rebuild of a published season, and no narrowing of the kind check.
- No new collection, album or hub design. No back-office curation of themes.
- Old kinds stay valid and keep their labels.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Themes of a game | top tags `[Indie, Roguelite, Deckbuilding, Pixel Graphics, Horror, RPG]` | `genres = ["roguelike","deckbuilder","horror"]`; RPG is 6th and does not count | — |
| Unknown tagid in the top 5 | the 2nd tagid is missing from `steam_tags` | it keeps its slot, and the 6th tag is not promoted | — |
| No theme in the top 5 | broad tags only | `genres = []`; the card is in `ufos`, with no main theme and no genre shown | — |
| Publication | draft holding themed and theme-less cards | only theme and `ufos` sets; tier rows for each set; `main_theme = genres.first` | — |
| Draft card with a pre-theme genre (`action`) | card not refilled | publication refused, nothing written | `Failure(:unknown_theme)` |
| Upsert with a genre outside the list | `genres: ["action"]` | card refused | `Failure(:invalid_card)` |
| A theme of 7 cards | — | bronze 1, silver 2, gold 4, complete 7 | — |
| Old published season | retired kinds, no `main_theme` | its sets are still listed and named; its cards show no genre | — |

</frozen-after-approval>

## Code Map

- `packs/catalog/app/models/catalog/set_builder.rb`:
  - replace the three builders with `themes` and `ufos`, keeping `by_release` order;
  - DraftPreview's calls follow.
- `packs/catalog/app/operations/catalog/publish_season.rb`:
  - `build_sets` also inserts the tier rows;
  - `write_season_data` sets `main_theme`;
  - a guard returns `Failure(:unknown_theme)` before any write.
- `packs/catalog/app/models/catalog/set.rb`:
  - the enum adds `theme franchise studio hall_of_fame ufo` and keeps the old three;
  - add `has_many :tiers`.
- `card_season.rb`: `SEASON_DATA` gains `main_theme`.
- `upsert_draft_card.rb`: every genre must be a theme key. This replaces the KEY_FORMAT check.
- `fill_card_sources.rb`:
  - rows gain `genres:`;
  - cards whose genres differ are updated;
  - it stays idempotent and publishes one event.
- `packs/steam/app/models/steam/card_mapping.rb`:
  - `genres` comes from `app.tag_ids.first(5)`, mapped through `tag_names` and then `Catalog::Themes.of`;
  - `sources(app, tag_names:)` returns genres as well.
- `packs/steam/lib/tasks/steam.rake`: load the batch's `tag_names` the way `import_cards_page.rb:91` does.
- Delete `steam/genre_tags.rb` and its test.
- Readers:
  - `card_views.rb:10-14`: `GENRE` reads `catalog_card_seasons.main_theme`. `card_detail.rb` reuses it, and its `KIND_ORDER` puts theme first.
  - `collection_grid.rb:32-63`: the genre chips come from `main_theme`.
  - `season_shelf.rb:16-35`: an order for every kind, with no `KeyError`.
  - `draft_preview.rb`, `season_scores.rb`, `score_panel.rb`: theme counts and the UFOs' share instead of tomes.
  - `game/queries/hub_sets.rb:62`: themes first.
- Web:
  - `app/components/set_label.rb`: names theme and ufo. `genre(key)` reads `catalog.themes`.
  - `concerns/shelf_loading.rb:16` `KINDS`: theme and ufo first, then the old three. A tab appears only when the season has sets of that kind.
  - `config/routes.rb:25,39`: the kind constraints.
  - `library/_filters.html.erb`, `back_office/seasons/{index,_preview}.html.erb`: labels, and a themes table in place of the tomes table.
- Locales:
  - `catalog.themes.*` (42 entries) and `catalog.sets.ufos`;
  - the theme and ufo entries of `library.show.{tabs,empty}`, `public_profiles.show.empty` and `back_office.seasons.index.sets`;
  - `errors.catalog.unknown_theme`.
- Tests and seeds: `test/support/catalog_seeds.rb`, `test/fixtures/catalog/{cards,sets}.yml`, `db/seeds.rb`, `open_pack_benchmark.rb:165`. Use theme keys; `fps`, `rpg` and `strategy` stay valid.
- Don't touch: `Game::SetCompletion` (it reads set ids only), the React island, `tags`/`tag_keys`.

## Tasks & Acceptance

**Execution:**
- [ ] `db/migrate/*`:
  - create `catalog_set_tiers`: `set_id` FK, `tier` check (bronze/silver/gold/complete), `required > 0`, unique `(set_id, tier)`;
  - add `catalog_card_seasons.main_theme`, a nullable string;
  - replace `catalog_sets_kind_check` with the eight kinds: added with `validate: false`, then validated in a second migration;
  - regenerate `db/schema.rb` on Postgres 18.
- [ ] `packs/catalog/app/models/catalog/themes.rb`:
  - the 42 themes as `key => [Steam tag names]`;
  - `of(tag_names)`: theme keys in tag order;
  - `key?`;
  - the constants for tier shares and the UFOs' share limit.
- [ ] `packs/catalog/app/models/catalog/set_tier.rb`: frozen once published, like `SetMembership`.
- [ ] Catalog builder, publication, upsert and fill, as in the Code Map.
- [ ] Steam mapping, rake task and the GenreTags deletion.
- [ ] Readers, web and locales. `i18n-tasks` must be clean. Add `errors.catalog.unknown_theme` by hand. French plurals need a `zero` form.
- [ ] `_bmad-output/initiative-gameble/pending-approvals.md`: ask the author to rerun `steam:fill_card_sources` on staging after the deploy, before publishing a draft.
- [ ] Tests:
  - every row of the matrix: builder, CardMapping, upsert, fill, publication (guard, tier rows, main theme);
  - `schema_test` for the new checks;
  - adapt the existing tests: `set_label_test`, shelf, grid, hub, and the system tests that name tomes.

**Acceptance Criteria:**
- Given a published draft, when its sets are counted by kind, then only theme and ufo sets exist and every card-season has a membership.
- Given the change, when the library, a set page, a card's detail and a public profile render in French and English, then the new sets are listed and named, and a themed card shows its main theme as its genre.
- Given the change, then `bundle exec packwerk check`, `bin/rails test`, the system tests touched, `npm run test:js`, `bin/rails zeitwerk:check`, `bin/rubocop` and `i18n-tasks` pass.

## Implementation Notes

## Plan Change Log

## Review Triage Log

## Design Notes

- **Top 5:** `catalog_cards.tags` drops and merges tags, which shifts positions. So the top 5 is read from `app.tag_ids.first(5)` in Steam. `CardMapping` calls the Catalog theme list, since Steam → Catalog is allowed.
- **Old season on staging:** until a later entry rebuilds it, its tomes stay listed and named, and its cards show no genre because `main_theme` is NULL.
- **`unknown_theme` guard:** stops a draft that still holds pre-theme genres from silently publishing those cards into the UFOs.
- **Kind check:** widened to all five new kinds now, so the franchise, studio and hall of fame follow-ups need no migration on `catalog_sets`.

## Verification

**Commands:**
- `bin/rails test`, `bin/rails test:system` (library, card detail, public profile, tome), `npm run test:js` -- pass
- `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `bin/rubocop`, `bundle exec i18n-tasks health` -- clean
- `RAILS_ENV=test bin/rails db:drop db:create db:migrate` -- the `db/schema.rb` diff holds only the new table, the new column and the check
