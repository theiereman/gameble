---
title: 'Every edition counts in the collection'
type: 'feature'
ticket: '15'
created: '2026-10-18'
status: 'built'
baseline_revision: '4057fc00e053cb26e23aea280e5a8c6f74942dd8'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
context:
  - '{project-root}/AGENTS.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A season is a reprint, and a copy keeps the edition (season and rarity) it was minted in. Yet the grid, the "Cartes uniques" counter, the RAPPORT, the top bar's rarity counter, the opening's counts before opening, the card detail's copies and the profiles' figures read only the published season's editions. Publishing a season empties a player's grid and drops every counter to zero, while the albums and set progress already count any edition.

**Approach:** Every collection read uses one of the two measures AD-5 names, with no season filter. The **games** measure (`Game::HeldGames`) gives one tile per game at its best minted rarity owned, and also drives the total counter, the RAPPORT's per-rarity rows and the profiles' figures. The **copies** measure (quantities per minted rarity across editions) drives the rarity counter, the opening's counts before opening and the RAPPORT's copies. The tile shows "2 éd." when several editions are held, and the card detail gains an ÉDITIONS row.

## Boundaries & Constraints

**Always:**
- Grid tiles: one per game, over the published season's rated games plus every game the player holds in any edition. A game that left the catalog still shows; nothing owned disappears.
  - A held game's tile shows the edition `HeldGames.editions` picks: best rarity, then the published season's edition, then the highest id.
  - A game not held shows its published edition. A visitor sees the published season, as today.
  - The tile's copies are summed over editions. "Nouveau" shows when any edition is new.
  - When two or more editions are held, an edition count ("2 éd." / "2 ed.") goes under the copies badge, in the same box style (DESIGN.md, Copy badge). The grid never shows a season number.
- Filters and order across editions:
  - States: owned = any edition held; missing = none held; new = any edition gained since the watermark (or since `seen_up_to`); duplicates = copies across editions ≥ 2.
  - Rarity filters the tile's rarity, i.e. the best owned rarity, or the published rarity for a missing game.
  - Genre and set filters match a game whose published edition or shown edition carries the genre, or that is a member of the chosen published-season set (any edition counts, AD-5).
  - The text search matches as today. Newest first orders by the latest gain across editions.
  - The `seen_up_to` watermark is the latest gain among the new tiles shown.
- Card detail walk (◀ ▶ from a grid, `CardsController#grid_browse`) walks the same tiles in the same order.
- Counters:
  - "Cartes uniques n / N": n = distinct games held across editions; N = the published season's card count, unchanged. The bar is capped at full.
  - The hub's COLLECTION meta, the public profile summary (distinct cards; complete sets = published-season sets whose every member is held in any edition) and the friend profile's figure read the same.
- RAPPORT:
  - COPIES = copies across editions; DOUBLONS = copies − distinct games, floored at 0.
  - Each rarity row = distinct games at that best owned rarity (the five rows add up to the unique count).
  - The fold line keeps "n cartes · n doublons" with copies.
- `Game::TierCounts.call` and `.before_opening` sum quantities per minted rarity over every edition, with no season filter. The top bar's counter therefore no longer drops to 0 at publication.
- Card detail (signed in):
  - COPIES counts every edition of the game.
  - A new ÉDITIONS row after COPIES (en "Editions", fr "Éditions") lists the editions owned, one line per rarity, best rarity first, seasons ascending: "Rare : S1, S4" (fr) / "Rare: S1, S4" (en). Lines beyond the third fold into a native `<details>`.
  - With no copy, the row is absent. A visitor never sees it.
  - "Faded" and the share link follow copies across editions.
- Fixed query counts, independent of the number of seasons or editions. Every GET writes nothing. No database id in HTML or URLs. Every string in `en.yml` and `fr.yml` (French plurals with `zero`). No `style` attribute, no planning ids, no new explanatory comments. Rewrite any header comment that says "in the season" for a read this changes.

**Never:**
- No change to trades (`Game::HeldCopies`, the picker stays per edition), to draws, to the album, to set progress or the tier pass (already across editions), or to the friend profile's `ShowcaseCards`.
- No season selector, no season shown on a tile, no migration, no new route.
- No season marks on tiers (epic-seasons-carry-over).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Two editions | Hades S1 Rare x1, S4 Épique x1; S4 published | one Hades tile, the S4 Épique face, "x2", "2 éd."; unique counts 1; RAPPORT Épique 1, Rare 0, copies 2, duplicates 1 | — |
| Publication | player holds 30 S3 games, S4 published, none held in S4 | grid shows 30 owned tiles; unique 30; top-bar counter unchanged | — |
| Left the catalog | game held only in S2, absent from S4 | one tile at its S2 face, filter "owned" keeps it | — |
| Same rarity twice | S1 Rare and S4 Rare | tile shows the S4 (published) edition | — |
| Rarity filter | `rarity[]=rare`, Hades as row 1 | Hades absent (best is Épique) | — |
| Duplicates | S1 x1 + S4 x1 | matches `state[]=duplicates` | — |
| New | only the S1 edition gained after the watermark | tile shows "Nouveau" | — |
| Card detail | open Hades | COPIES "2 copies"; ÉDITIONS "Épique: S4" then "Rare: S1" | — |
| Visitor | signed out on `/library/cards` or a card | published season tiles, no copies or editions rows | — |
| Opening | pack of 1 Rare after S1 Rare x3 held, S2 published | `tierCountsBefore.rare` = 3 | — |

</frozen-after-approval>

## Code Map

- `packs/game/app/queries/game/held_games.rb`:
  - Extract the edition order (`rarity DESC NULLS LAST, (season_id = :season_id) DESC, id DESC`) into one constant shared by `EDITIONS` and the new tile query.
  - Add `editions` (a count of held editions) and `gained_at` (the latest gain, `MAX OVER games`) to `Edition`. Update the `Edition.new` callers and tests.
  - Add `by_rarity(player)` → `{tier => games}`, every tier present, zeros for nil with no query.
  - Add `count(player)` for the hub, the friend profile and the status, or derive it from `by_rarity` where that is already loaded.
- New `packs/game/app/queries/game/collection_tiles.rb`: `Game::CollectionTiles.call(player, season)` returns a lazy `Catalog::CardSeason` relation of the tile card-seasons. For a visitor it is the season's rated card-seasons. Shape: `id IN (SELECT DISTINCT ON (cs.card_id) cs.id FROM catalog_card_seasons cs LEFT JOIN game_holdings h ON h.card_season_id = cs.id AND h.player_id = :p AND h.quantity > 0 WHERE cs.rarity IS NOT NULL AND (cs.season_id = :s OR h.id IS NOT NULL) ORDER BY cs.card_id, h.id IS NULL, <edition order>)`. Packwerk allows Game → Catalog.
- `packs/catalog/app/queries/catalog/collection_grid.rb`:
  - `call` takes `cards:` (the base relation, defaulting to the season's rated card-seasons). `genres` stays the published season's list.
  - The genre and set filters move to a `card_id IN (…)` match: the season's editions with that main theme or membership, OR the row's own `main_theme` for genres.
  - Rewrite the header comment.
- `packs/game/app/queries/game/collection_states.rb`:
  - Join a per-card aggregate (`LEFT JOIN (SELECT card_id, SUM(quantity) copies, MAX(last_gained_at) gained_at, BOOL_OR(<NEW>) new FROM holdings ⋈ card_seasons ⋈ player_states WHERE player … GROUP BY card_id) held ON held.card_id = catalog_card_seasons.card_id`) instead of the per-edition holding.
  - The conditions move onto `held.*` (`NEW_SINCE` becomes `held.gained_at > ?`), and so does the newest-first order. The visitor path is unchanged.
- `app/controllers/concerns/collection_grid_loading.rb` -- `collection_grid` passes `cards: Game::CollectionTiles.call(current_player, season)`; this is the shared path for the library and `CardsController#grid_browse`.
- `app/controllers/library_controller.rb`:
  - `load_grid` reads slots with `Game::HeldGames.editions(current_player, card_ids:, season: @season)`, keyed back to each tile's `CardView`. This replaces `CollectionSlots` in the grid; `CollectionSlots` stays for trades.
  - `@seen_up_to` comes from the new tiles' `gained_at`.
  - `load_summary`/`load_unique_cards`: `@games_by_rarity = HeldGames.by_rarity`, `@unique` = its sum, `@tier_counts` = `TierCounts`.
- `app/views/library/_grid.html.erb` -- the edition count element (e.g. `span.collection-slot__editions`, `aria-hidden`, plus visually hidden text `library.grid.editions`). Update the `slots` local doc.
- `app/views/library/_report.html.erb` -- per-tier rows from games and copies from `TierCounts`; new local `games`. Callers: `_collection.html.erb`.
- `app/views/library/_status.html.erb` -- clamp the bar's fill when n > N, if it computes a share.
- `packs/game/app/queries/game/tier_counts.rb` -- drop `PUBLISHED_SEASON` from `SQL` and `PACK_SQL`. Rewrite the test "only the newest published season counts" into "every edition counts".
- `packs/game/app/queries/game/collection_summary.rb` -- `distinct_cards` counts HeldGames rows, with no season. `complete_sets` joins members by `card_id` to the held games. Callers: `pages_controller.rb:61`, `friend_profiles_controller.rb:17`, `public_profiles_controller.rb:26`, `library_controller.rb:96`. Keep the signatures or simplify them.
- Card detail:
  - `packs/catalog/app/queries/catalog/card_detail.rb`: expose `card_id` on `Detail`.
  - New `Game::HeldEditions.call(player, card_id:)`, one query: `[[rarity, season_number, quantity], …]`; `[]` for nil with no query.
  - `cards_controller.rb#show`: `@editions`, and `@copies` = the sum of their quantities, replacing `Quantities` (the repost check in `RepostCard` stays per edition).
  - `app/views/cards/_detail.html.erb`: the ÉDITIONS row after COPIES (local `editions`, update the locals doc); `cards/show.html.erb` passes it.
  - Locales `card_details.facts.editions` and `card_details.editions_line` (`%{rarity} : %{seasons}` in fr).
  - Styles in `app/frontend/styles/card-detail.css`, with the fold as a `<details>` like `.report--fold`.
- `app/frontend/styles/collection.css` -- `.collection-slot__editions` under `__copies` (l.605).
- Tests to update or add:
  - `test/packs/game/{held_games,tier_counts,collection_states,collection_summary}_test.rb`, new `collection_tiles_test.rb` and `held_editions_test.rb`, `test/packs/catalog/collection_grid_test.rb`.
  - `test/controllers/library_controller_test.rb` (query counts 13 / 7 at l.595-601, 14 at l.173, banned 1+7 at l.239), `cards_controller_test.rb` (facts arrays l.102, 204, 406; query counts l.744-782), `public_profiles_controller_test.rb` (l.469-481), `pages_controller_test.rb` (`PLAYER_HUB_QUERIES`), `packs_controller_test.rb` (`tierCountsBefore`), `test/helpers/shell_helper_test.rb`.
  - Helpers: `test/support/library_requests.rb` (`hold`, `assert_request_queries`).
  - System tests: selector updates only, never run.

## Tasks & Acceptance

**Execution:**
- [x] `held_games.rb`, `collection_tiles.rb` (new), `collection_states.rb`, `collection_grid.rb` (+ tests) -- the across-editions tile relation, its filters and states.
- [x] `collection_grid_loading.rb`, `library_controller.rb`, `_grid.html.erb`, `collection.css` -- the tiles, their slots, the edition count, the watermark.
- [x] `tier_counts.rb`, `collection_summary.rb`, `HeldGames.by_rarity`, `_report.html.erb`, `_status.html.erb`, `pages_controller.rb`, `friend_profiles_controller.rb`, `public_profiles_controller.rb` -- the counters and the RAPPORT.
- [x] `card_detail.rb`, `held_editions.rb` (new), `cards_controller.rb`, `_detail.html.erb`, `show.html.erb`, `card-detail.css` -- copies across editions and the ÉDITIONS row.
- [x] Locales en/fr: `library.grid.editions` (visible "%{count} éd." / "%{count} ed." and an accessible form, with zero/one/other), `card_details.facts.editions`, `card_details.editions_line`, the fold summary.
- [x] Request and unit tests for every matrix row, both locales, exact query counts, no `[style]`, no ids, GETs write nothing.

**Acceptance Criteria:**
- Given seasons 1 to 4 published and a player holding Hades in S1 Rare and S4 Épique, when they open "Toutes les cartes", then one Hades tile shows at Épique with "2 éd." and the card detail lists both editions.
- Given a player's collection, when a new season is published, then the "Cartes uniques" count, the RAPPORT and the top bar's rarity counter keep their values.
- Given the change, when `bin/ci`, `npm run test:js`, `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bundle exec i18n-tasks missing` and `unused` run, then they pass (`unused` lists only the pre-existing `rate_limit.*`).

## Implementation Notes

- `Game::CollectionSummary.distinct_cards` is gone: the hub, the friend profile and the library's status read `Game::HeldGames.count`; `CollectionSummary.call` keeps its signature.
- `CardsController#grid_browse` no longer requires the published season's card-season: a tile of an earlier edition walks the grid it shows.
- The card detail's share sheet follows copies across editions, but the REPOSTER button shows only on the page of an edition held, since `RepostCard` checks that edition.
- The visitor's tile relation keeps the condition order of `Catalog::CardCount`, so the grid's count is still served from the query cache (seven queries).

## Plan Change Log

## Review Triage Log

### 2026-10-18 — Review pass
- verdicts: 3 findings — high 0, medium 0, low 2, false 0, maybe-false 1
- findings:
  - `[low]` `[patch]` New explanatory comments on new constants and methods (`EDITION_ORDER`, `HELD_GAMES`, `genre_match`, `card_detail_edition_lines`), on the new CSS blocks, on new test helpers and in two tests, against AGENTS.md and the plan. Deleted; the module headers of the new query files and the rewritten pre-existing headers are kept, as the repo puts a header on every query.
  - `[low]` `[patch]` Stale header comments. `CardsController`'s header still said a card not held shows faded and a holder can share it, while both now follow any edition of the game; `_detail`'s `faded` local doc said the same; and the rewraps in `cards_controller.rb` and `library_controller.rb` left broken lines. Rewritten and rewrapped.
  - `[maybe-false]` `[reject]` Holdings of an unrated card-season (`rarity IS NULL`) would count in `HeldGames.count`, `editions` and `CollectionStates`, but not in `by_rarity`, `CollectionTiles`, `TierCounts` or `HeldEditions`, so `/library` and `/library/cards` could read different unique counts. It is reachable only if a player holds a card-season without a rarity, which draws from rated cards never give. At most a low miscount, so rejected. A count of holdings on unrated card-seasons on staging would settle it.

## Design Notes

- **Tiles as card-seasons:** the grid stays a relation of `Catalog::CardSeason`, one per game, so paging, `CardViews`, links to the shown edition's detail page and the detail walk keep working unchanged. Only the base relation and the state join change.
- **Games that left the catalog** stay in the grid and the count (spec: "Nothing a player owns is removed"). So n can exceed the published season's N, and the bar caps at full.
- **Genre on old editions:** season 1 has no main themes. Matching the published edition's genre too keeps an S1-only best edition in the RPG filter when the game is an RPG today.

## Verification

**Commands:**
- `bin/ci` -- expected: green (revert any stray `package-lock.json` "license" line it writes)
- `npm run test:js`, `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bundle exec i18n-tasks missing`, `bundle exec i18n-tasks unused` -- expected: green (`unused`: only the pre-existing `rate_limit.*`)

**Manual checks (if no CLI):**
- Staging, after deploy: the ticket's verify line (Hades S1 Rare + S4 Épique); the author's check is queued in `pending-approvals.md`.
