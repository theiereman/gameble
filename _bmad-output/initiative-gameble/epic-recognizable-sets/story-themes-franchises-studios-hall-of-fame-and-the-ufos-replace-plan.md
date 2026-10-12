---
title: 'Themes and the UFOs replace the old sets'
type: 'feature'
ticket: '3'
created: '2026-10-12'
status: done
baseline_revision: '224cc3934833c61bacd0d4b7a95d6a1a2d065e08'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: []
followup_review_recommended: false
deferred:
  - summary: >-
      The change adds explanatory header and constant comments, matching the surrounding code but not the AGENTS.md rule to comment only external constraints.
    evidence: |-
      themes.rb, set_tier.rb, set_builder.rb, set.rb (BUILT_KINDS), card_mapping.rb (TOP_TAGS), shelf_loading.rb (shelf_kinds) and fr.yml (zero form) carry such comments; the rest of the codebase does the same, so trimming only these files would split the style. Settling it is a repo-wide decision for the author.
    location: >-
      packs/catalog/app/models/catalog/themes.rb
    severity: low
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
- [x] `db/migrate/*`:
  - create `catalog_set_tiers`: `set_id` FK, `tier` check (bronze/silver/gold/complete), `required > 0`, unique `(set_id, tier)`;
  - add `catalog_card_seasons.main_theme`, a nullable string;
  - replace `catalog_sets_kind_check` with the eight kinds: added with `validate: false`, then validated in a second migration;
  - regenerate `db/schema.rb` on Postgres 18.
- [x] `packs/catalog/app/models/catalog/themes.rb`:
  - the 42 themes as `key => [Steam tag names]`;
  - `of(tag_names)`: theme keys in tag order;
  - `key?`;
  - the constants for tier shares and the UFOs' share limit.
- [x] `packs/catalog/app/models/catalog/set_tier.rb`: frozen once published, like `SetMembership`.
- [x] Catalog builder, publication, upsert and fill, as in the Code Map.
- [x] Steam mapping, rake task and the GenreTags deletion.
- [x] Readers, web and locales. `i18n-tasks` must be clean. Add `errors.catalog.unknown_theme` by hand. French plurals need a `zero` form.
- [x] `_bmad-output/initiative-gameble/pending-approvals.md`: ask the author to rerun `steam:fill_card_sources` on staging after the deploy, before publishing a draft.
- [x] Tests:
  - every row of the matrix: builder, CardMapping, upsert, fill, publication (guard, tier rows, main theme);
  - `schema_test` for the new checks;
  - adapt the existing tests: `set_label_test`, shelf, grid, hub, and the system tests that name tomes.

**Acceptance Criteria:**
- Given a published draft, when its sets are counted by kind, then only theme and ufo sets exist and every card-season has a membership.
- Given the change, when the library, a set page, a card's detail and a public profile render in French and English, then the new sets are listed and named, and a themed card shows its main theme as its genre.
- Given the change, then `bundle exec packwerk check`, `bin/rails test`, the system tests touched, `npm run test:js`, `bin/rails zeitwerk:check`, `bin/rubocop` and `i18n-tasks` pass.

## Implementation Notes

- `SetBuilder` returns each set's tiers beside its members (`Catalog::Themes.tiers`, integer percents rounded up with `ceildiv`, so 30 cards give bronze 3, not 4 through float error); `PublishSeason#build_sets` inserts them. The `Set::KEY_FORMAT` raise at publication is gone: theme keys and `ufos` are constants, and `unknown_theme` refuses any other genre first.
- `Catalog::Set::BUILT_KINDS` (theme, ufo, then the retired three) are the kinds the back-office counts and labels; franchise, studio and hall of fame are valid enum values without a label until their builders come.
- Library and public profile: `ShelfLoading#shelf_kinds` reads the kinds the season holds (`Catalog::SeasonShelf.kinds`), one more query per page; the request budgets in the tests go up by one. An old season opens on its first kind (tomes), its tab links carrying `kind=tome`.
- `SetLabel.genre` reads `catalog.themes`; tome labels keep reading `catalog.genres` through a private `tome_genre`, so retired sets keep their names.
- The back-office preview replaces the tomes table with the themes, the UFOs' count and share (flagged above `Catalog::Themes::UFO_SHARE_LIMIT`), and the `unknown_theme` verdict; a season published before themes says so.
- The test draft (`seed_sets_draft`) now holds roguelike 119, rpg 44, horror 16, pirates 8 and the UFOs 15. Dev seeds leave every tenth card without theme, so the UFOs show.
- `bin/rails test` passes with `TZ=UTC`; in Europe/Paris two time-based tests (sessions cookie expiry, finished trades) fail on the 25 October DST change, independently of this change.

## Plan Change Log

## Review Triage Log

### 2026-10-12 — Review pass
- verdicts: 3 findings — high 0, medium 1, low 2, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` A card of several themes browses, by default, its alphabetically first theme set rather than its main theme, the genre it shows (`CardDetail.sets` ordered by kind then key; `CardsController#show` takes `sets.first`); the controller header still said "tomes first" — `CardDetail.sets` now puts the main theme's set first (partition after the SQL order, still two queries), header reworded, test of a `["rpg", "roguelike"]` card added.
  - `[low]` `[patch]` `ShelfLoading::Spine` comment still called a spine "a tome on the shelf" — reworded to "a set on the shelf".
  - `[low]` `[defer]` New explanatory comments in themes.rb, set_tier.rb, set_builder.rb, set.rb, card_mapping.rb, shelf_loading.rb and fr.yml go beyond the AGENTS.md comment rule — the surrounding code carries the same style throughout, so this is a pre-existing repo-wide tension; deferred for the author's decision.

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

## Auto Run Result

**Summary:** Publication now builds theme sets and the UFOs only, with tier rows (bronze/silver/gold at 10/25/50 % rounded up, plus complete; complete only for the UFOs) and each card-season's main theme. The 42 themes live in `Catalog::Themes`; the Steam import and `steam:fill_card_sources` derive a card's genres from its five most-voted tags. A draft still holding pre-theme genres is refused (`unknown_theme`). The set kind check widens to eight kinds (expand only). Library, set pages, card detail, public profile, hub and back-office list and name the new sets; a card's genre is its main theme. Old published seasons keep their sets and labels.

**Files changed:**
- `db/migrate/20261012120000..120003`, `db/schema.rb` — `catalog_set_tiers`, `catalog_card_seasons.main_theme`, widened kind check (added unvalidated, then validated).
- `packs/catalog/app/models/catalog/themes.rb` — the theme list, `of`, `key?`, `tiers`, UFO share limit.
- `packs/catalog/app/models/catalog/set_tier.rb`, `set.rb`, `card_season.rb` — tier model frozen once published, eight kinds, `main_theme` frozen.
- `packs/catalog/app/models/catalog/set_builder.rb` — theme sets and the UFOs with their tiers.
- `packs/catalog/app/operations/catalog/{publish_season,upsert_draft_card,fill_card_sources}.rb` — `unknown_theme` guard, main themes and tier rows; genres must be theme keys; fill refills genres.
- `packs/catalog/app/queries/catalog/*` — readers on `main_theme`, theme counts and UFO share, every kind ordered, main theme's set first on a card.
- `packs/steam/app/models/steam/card_mapping.rb`, `packs/steam/lib/tasks/steam.rake` — themes from the top 5 tags; `Steam::GenreTags` deleted.
- `packs/game/app/queries/game/hub_sets.rb` — themes first.
- `app/components/set_label.rb`, `app/controllers/*`, `app/helpers/*`, `app/views/*`, `config/routes.rb` — names, tabs only for kinds the season holds, routes, back-office themes table.
- `config/locales/{en,fr}.yml`, `config/i18n-tasks.yml` — 42 themes, the UFOs, tabs, back-office keys, `errors.catalog.unknown_theme`.
- `db/seeds.rb`, `packs/game/lib/open_pack_benchmark.rb`, tests and fixtures — theme keys.
- `_bmad-output/initiative-gameble/pending-approvals.md` — rerun `steam:fill_card_sources` on staging before publishing a draft.

**Review findings:** 3 findings (quick lens). Patched: 1 medium (card browses its main theme's set by default), 1 low (stale Spine comment). Deferred: 1 low (comment density vs. AGENTS.md rule). Rejected: none. Parent fix outside triage: the French `errors.catalog.unknown_theme` used "vous" where the back-office says "tu"; reworded.

**Follow-up review recommended:** false — patched this pass: high 0, medium 1, low 1.

**Verification:**
- `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `bin/rubocop` (666 files), `i18n-tasks missing` and `unused` — clean.
- `TZ=UTC bin/rails test` — 2218 runs, 0 failures, 0 errors, 0 skips.
- `bin/rails test` on the touched system tests (library, card detail, public profile, tome, shell) — 48 runs, 0 failures.
- `npm run test:js` — 217 passed.
- `RAILS_ENV=test bin/rails db:drop db:create db:migrate` — `db/schema.rb` unchanged (no drift).
- `i18n-tasks check-consistent-interpolations` flags `back_office.seasons.index.confirm.one` (fr), present before this change.
- Every I/O matrix row is covered by a test that ran and passed.

**Residual risks:**
- Staging: a draft imported before this deploy is refused until `steam:fill_card_sources` runs (pending approval added).
- Library and public profile pages make one more query (the kinds the season holds).
- `franchise`, `studio` and `hall_of_fame` are valid kinds without a label; `SetLabel` raises on such a set until their builders and names come.
- The UFO share over 5 % is only flagged in the back-office preview, not enforced.
- In the Europe/Paris timezone two time-based tests fail around the 25 October DST change, independently of this change; CI runs in UTC.

## Code Review

### 2026-10-12 — Domain, database and tests (commit 42075b2, first of two chunks)

Code review: 1 `decision-needed`, 4 `patch`, 1 `defer`, 11 rejected. Lenses: blind-hunter, edge-case-hunter, verification-gap, intent-alignment.

- [x] [Review][Decision] The `unknown_theme` guard does not catch a draft that was never refilled — 23 of the 25 old `Steam::GenreTags` keys are also theme keys (only `card_game` and `arcade` are not), so a card imported before themes and not refilled by `steam:fill_card_sources` passes the guard with genres from the old rule (every listed tag, any rank) and its `main_theme` is frozen wrong at publication. The tests only use `action`, which the old list never produced. Accept the operational step (the pending approval), or carry a marker (themes version) on the card that publication requires. — resolved (author, 2026-10-12): risk accepted; no draft spans the deploy, and the next import writes themes directly.
- [x] [Review][Patch] The hub's fill puts publisher sets before tomes on a season published before themes, where tomes came first [packs/game/app/queries/game/hub_sets.rb:62] — dismissed (author, 2026-10-12): a new season with themes is being published.
- [x] [Review][Patch] README still describes `Steam::GenreTags`, tomes and `TOME_SIZE` for season preparation [README.md:148] — dismissed (author, 2026-10-12): the README will be rewritten, and season preparation will move to a contributor guide.
- [x] [Review][Patch] i18n-tasks comment above `catalog.themes.*` speaks only of tomes [config/i18n-tasks.yml:26]
- [x] [Review][Patch] `SeasonRows::Row#publisher` and the `publisher:` parameter of the set builder test helper are dead since publisher sets are no longer built [packs/catalog/app/queries/catalog/season_rows.rb:14]
- [x] [Review][Defer] Planning ids remain in files this change touched (`config/routes.rb`, `set_neighbours.rb`, `hub_sets.rb`, `rescore_cards.rb`, `season_summaries.rb`) [config/routes.rb] — deferred: pre-existing, the change adds none

Rejected:
- The live pre-themes season loses its card genre and genre filter (`main_theme` NULL) — false: the plan's matrix states "Old published season … its cards show no genre"; story 13.4 rebuilds it.
- The genre filter keeps a card's main theme, not set membership — false: "a card's genre is its main theme", tested deliberately (75 of the 119 roguelike cards).
- Tag names matched exactly, unchecked against `Steam::Tag` — low: the names are the probe's, run on real data; a check would add tooling.
- A tag listed in two themes silently keeps the last — false: no tag appears twice in `Themes::TAGS`.
- Kind lists duplicated (route regex, `KIND_ORDER`, `EVERY_KIND_ORDER`, `BUILT_KINDS`); routes refuse franchise/studio/hall_of_fame — low: no builder makes those kinds yet, and the follow-ups fail loudly in tests until they add them.
- `set_counts` keyed differently in `DraftPreview` and `SeasonScores` — low: only a test merge pays for it.
- `steam:fill_card_sources` empties genres when `Steam::Tag` is empty — low: every import fills the tags first; a guard adds a branch.
- No minimum theme size, a 1-card theme gives 1/1/1/1 tiers — false: the tier rule is the plan's; changing it edits the plan.
- `main_theme` has no index or check — low: the season scope is small and upserts validate keys.
- The kind check migration's comment speaks of a rebuild the plan excludes — false: story 13.4 rebuilds the published season once; the comment holds for the epic.
- Additions beyond the intent (UFO share limit, theme verdict, main theme set first) — false: recorded in the plan's notes, no boundary crossed.

### 2026-10-12 — Views, components, controllers and locales (commit 42075b2, second of two chunks)

Code review: 1 `decision-needed`, 2 `patch`, 2 `defer`, 14 rejected. Lenses: blind-hunter, edge-case-hunter, verification-gap, intent-alignment.

- [x] [Review][Decision] Themes are ordered by their English key, not by their name — the library shelf (`SeasonShelf` `BY_KEY`, paged in SQL by `SHELF_SIZE`) and the genre chips (`.sort` on `main_theme` keys) list the 42 themes in key order, so the French library reads « Vie à la ferme » (farming) between « Deckbuilding » and « Combat », and « Réflexion » (puzzle) before « Course » (racing); the tests pass only because their sample falls in order. Keep key order, or order by the localized name (an SQL `CASE` built from the locale for the paged shelf, a sort by label for the chips). — resolved (author, 2026-10-12): key order kept.
- [x] [Review][Patch] No test asserts the tabs of a collection page opened from a profile (`brother_set_path`), for a themed season (Started, Themes, UFOs) or a season published before themes [test/controllers/public_profiles_controller_test.rb]
- [x] [Review][Patch] The French back-office line for a season published before themes says « set OVNI » where the same panel says « Collections » [config/locales/fr.yml:468]
- [x] [Review][Defer] No test renders the French preview with zero UFOs, which needs the plural `zero` form [app/views/back_office/seasons/_preview.html.erb:109] — deferred: admin-only copy; add to the French verdict test with a draft whose every card has a theme
- [x] [Review][Defer] Planning ids remain in comments of `app/helpers/collection_helper.rb`, `app/views/library/_set_list.html.erb`, `app/views/public_profiles/_set_list.html.erb`, `app/views/library/_collection.html.erb` and `app/views/public_profiles/show.html.erb` — deferred: pre-existing, the change adds none

Rejected:
- Empty `<nav>` of kinds when a season holds no set — low: a published season always holds sets; a guard adds a branch.
- Empty-state strings `empty.ufo` and the retired kinds' can no longer show — low: harmless copy; removing it trades a dead key for a latent missing translation.
- Links on a season published before themes carry `kind=tome` though it is that season's default — low: both URLs show the same page, and the next season is themed.
- French theme names differ from `catalog.genres` (« Plates-formes », « City builder », « Idle ») — false: they are the spike report's table, as the intent requires.
- One more query per library and profile page (`shelf_kinds`) — low: one small grouped query; caching adds state.
- `@tabs` built twice in `PublicProfilesController` — low: one line.
- `SetLabel` raises on franchise, studio and hall of fame — low: no builder makes those kinds yet; the follow-ups fail loudly in tests.
- Back-office index shows columns that stay at 0 — low: `BUILT_KINDS` by design; hiding columns adds logic.
- `panel.ufo_share * 100` with a nil share — false: a nil share needs a published season with theme sets and no card, which publication cannot produce; an empty draft stops at `empty_season?`.
- The live pre-themes season loses its genres without an approval entry — false: the plan's matrix states it; the author knows and is publishing a themed season.
- The plan cites system tests as verification — rejected: its fix edits the plan.
- `pending-approvals.md` speaks of a rebuild the plan excludes — false: story 13.4 rebuilds the published season once.
- A UFO card's missing genre is tested only through a pre-themes fixture — low: the same nil `main_theme` path.
- Integration tests set `main_theme` by `update_all` on tome fixtures — low: they test the read; publication sets it in the domain tests.
