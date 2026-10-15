---
title: 'Tiers and the celebration at opening'
type: 'feature'
ticket: '5'
created: '2026-10-15'
status: 'built'
baseline_revision: 'bac8e2dac9ba292460870f3c9a272853e3985529'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: [multiple-goals, oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** A set is only "complete or not" (`game_set_completions`, matched on the exact card-season), so theme and hall of fame sets have no bronze/silver/gold, an earlier edition counts for nothing, the opening's answer says nothing about sets, and the booster never celebrates.

**Approach:** A new `game_set_tiers` table (one row per player, set and tier, recording how it was reached) is filled by one tier pass in `Game::OpenPack` and `Game::AcceptTrade`, reading `catalog_set_tiers` and counting games held in any edition through a new `Game::HeldGames`; each new row publishes one event. The opening's JSON gains `setTiers`, and the booster island shows and announces a celebration after the reveal.

## Boundaries & Constraints

**Always:**
- Only sets of the published season earn tiers; they are found through each credited card's card-season in the published season (`card_id` match), so an earlier edition received by trade counts. A member counts when the player holds any card-season of its card with `quantity > 0`, in any season.
- Tier rows: unique `(player_id, set_id, tier)`, inserted in one `INSERT … SELECT … ON CONFLICT DO NOTHING RETURNING`, ordered by set id then bronze, silver, gold, complete. `reached_by` is `pack` (with `pack_id`) or `trade` (no `pack_id`). A reached tier stays reached when cards leave.
- Each new row publishes exactly one event after the operation's primary event, on the player's stream, ids only: bronze/silver/gold → `Game::SetTierReached {player_id, set_id, tier}`; complete → `Game::SetCompleted {player_id, set_id}`.
- `OpenPack` reads `Catalog::PublishedSeason` once, right after its bank lock, and passes it to the redraw, the draw pool, the top-up and the tier pass. `AcceptTrade` reads it once after its bank locks. No published season: no tier pass.
- The opening stays a fixed handful of statements (no per-card or per-set loop). A replay publishes nothing and answers the same `setTiers` (read by `pack_id`).
- `setTiers` carries no database id; counts come from `catalog_set_tiers` (`required` of the tier, `total` = the complete row's `required`).
- Set achievements count distinct set kind and key across seasons (`complete` rows); card-counting achievements (first Épique, first Légendaire) count distinct games.
- Celebration: one result per set (its highest tier reached by this opening: complete > gold > silver > bronze), ordered highest tier first, then set name. Starts when the hand is complete (`complete()`) and no result banner is showing; never takes focus, never blocks "RANGER" or "OUVRIR LA SUIVANTE", never changes on a timer; stays until the next capsule opens (cleared in `open()`/`retract()`). Announced once in the existing live region. More than three results become one folded line. Every string in `en.yml` and `fr.yml` (French plural keys with `zero`).

**Never:**
- No backfill of tiers from old completions, no tier rows for sets of earlier seasons, no seasonal allocation (`ReceiveSeasonAllocation`), no feed or LIVE ticker lines (entry 6), no collection, hub or album change (entries 7, 8, 15), no change to `Game::TierCounts`.
- No drop of `game_set_completions` in this change (expand/contract: the old container may still write it during the deploy); nothing writes or reads it any more except `ReleasePlayer`'s delete.
- No celebration on a restored `?pack=` hand or on the server-rendered `/packs/:token` page.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Bronze crossed | theme of 20 (bronze 2), player holds 1 member, pack gives a 2nd | one `bronze` row (`pack`, pack_id), one SetTierReached; answer `setTiers` = [{kind theme, key, name, tier bronze, required 2, total 20}] | — |
| Crossed again | same theme, another member pulled, still below silver | no row, no event, `setTiers` [] | DO NOTHING |
| Several tiers at once | small theme tiers 1/1/2/3, first member pulled | bronze and silver rows, two SetTierReached; celebration shows one result: PALIER ARGENT | — |
| Franchise completed | last member of a franchise (complete only) | one `complete` row, one SetCompleted; SET COMPLET | — |
| Theme at 100 % | gold already reached, last member pulled | one `complete` row, SetCompleted; SET COMPLET | — |
| Earlier edition | player holds card X only in season 1; published season 2's theme counts X | X counts toward season 2's bronze; no row on any season 1 set | — |
| Trade | accepted trade gives an earlier-season copy that crosses a published theme's bronze | `bronze` row `reached_by trade`, pack_id null, event for that player | — |
| Replay | same idempotency key | same `setTiers`, no event | — |
| Set without tier rows | published set with no `catalog_set_tiers` | nothing | — |
| > 3 results | 4 sets reach tiers | desktop and phone show "4 PALIERS ATTEINTS"; live region "4 paliers atteints : Roguelike, argent ; …" | — |

</intent-contract>

## Code Map

- `db/migrate/` -- one migration `create_game_set_tiers`: `player` (FK accounts_players, no own index), `set_id` bigint NN (no FK, as completions), `tier` string NN, `reached_by` string NN, `pack` (FK game_packs, nullable, indexed), `reached_at`, timestamps; unique `[player_id, set_id, tier]`; checks: tier in the four, reached_by in (pack, trade), `(reached_by = 'pack') = (pack_id IS NOT NULL)`. Pattern: `20261012140000_create_game_achievement_unlocks.rb`, check style of `20261012120000_create_catalog_set_tiers.rb`. Regenerate `db/schema.rb`.
- `packs/game/app/queries/game/held_games.rb` -- new `Game::HeldGames`: an SQL constant (per `card_id`, `MAX(rarity)`, holdings with `quantity > 0`, joined to `catalog_card_seasons`, bound `:player_id`) and `call(player_id, card_ids: nil)` → `{ card_id => rarity }`. The tier pass embeds the same constant.
- `packs/game/app/models/game/set_tier.rb` -- new `Game::SetTier` (`TIERS = %w[bronze silver gold complete]`) with `record(player_id:, card_season_ids:, season_id:, reached_by:, pack_id:, now:)` → inserted `[set_id, tier]` pairs. Replaces `Game::SetCompletion::RECORD_SQL` (`set_completion.rb:13-29`); candidate sets via `catalog_card_seasons.card_id` of the credited ids → published-season card-seasons → `catalog_set_memberships`; progress = members whose `card_id` is in HeldGames; join `catalog_set_tiers` where held ≥ `required`.
- `packs/game/app/models/game/set_completion.rb` -- keep the class, drop `record`/`RECORD_SQL`; only `ReleasePlayer` deletes through it.
- `packs/game/app/events/game/set_tier_reached.rb` -- new event, same style as `set_completed.rb`.
- `packs/game/app/operations/game/operation.rb:27-32` -- `publish_completions` → `publish_tiers(player_id, rows)`.
- `packs/game/app/operations/game/open_pack.rb` -- season read after `lock_bank`; `drawn_in_published_season`, `TopUpBank.call` take the pool/season instead of calling `DrawPool.current` again; tier pass replaces `SetCompletion.record`; rewrite the header comment without planning ids.
- `packs/game/app/models/game/draw_pool.rb` -- add a way to get the snapshot for a given season (the snapshot is keyed by id and `published_at`); `current` keeps working for other callers. `packs/game/app/models/game/top_up_bank.rb:27,44` -- accept the pool.
- `packs/game/app/operations/game/accept_trade.rb:25-29,45-48` -- published season after `lock_trade`; tier pass per player (`trade`), events after TradeAccepted, ascending player.
- `packs/game/app/operations/game/release_player.rb` -- delete the player's `SetTier` rows before `Pack` rows; keep the `SetCompletion` delete.
- `packs/game/app/queries/game/achievement_progress.rb:16` -- `sets_completed` = distinct `(kind, key)` of `complete` tier rows joined to `catalog_sets`; `OBTAINED_SQL` counts distinct `card_id`.
- `packs/game/app/queries/game/export_of.rb:6,32,62-70`, `app/models/player_export.rb:29-30` -- export set tiers (season, kind, key, tier, reachedBy, reachedAt) in place of `setCompletions`; adjust the delete note in `en.yml:1182`/`fr.yml:1227` if it names completed sets.
- `packs/game/app/queries/game/pack_set_tiers.rb` -- new: the tier rows of a pack with the set's kind, key, params, `required` and `total`, in the record order.
- `app/helpers/packs_helper.rb:24-39` -- add `setTiers` after `tierCountsBefore` (`name` from `SetLabel.for`).
- `app/frontend/lib/opening.ts` -- `OpeningSetTier`, `setTiers` in `OpeningAnswer` and `isAnswer` (absent field = invalid, as other fields).
- `app/frontend/lib/celebration.ts` (+ `.test.ts`) -- pure: results from `setTiers` (one per set by kind+key, ordering), fold above three, phone index cycling, the announcement text.
- `app/frontend/components/Booster.tsx` -- `celebrating` state set in `complete()`, cleared in `open()` and `retract()`; shown once `banner === null`; one `announce` when first shown; `applyLayout` keeps it.
- `app/frontend/components/BoosterCelebration.tsx` (new), `BoosterPanel.tsx` (desktop stack after the counter), `BoosterPlate.tsx`/`BoosterView.tsx` (phone: in the plate band in place of the done hint, "i / n" and the 44 × 44 "▸" button named "Résultat suivant", wrapping to the first).
- `app/frontend/lib/booster_props.ts:18-79` -- `BoosterStrings.celebration`.
- `app/frontend/styles/tokens.css` -- `--color-tier-bronze #c4945e`, `--color-tier-silver #bcc8d4`. `styles/booster.css` / `booster-layouts.css` -- results (tier colour name in VT323 with outline, 1–3 filled notches ≥ 4 × 8 with 2px gaps, lime with a small 3px COMPLET frame and the word set straight), names wrap, phone row grows to ≥ 60px (`.booster__shake` grid row is 52px; `.booster-plate__line` is nowrap), `1 1 100%` under 1260px, reduced motion: 200ms opacity crossfade only (both CSS patterns at `booster-layouts.css:597-660`).
- `config/locales/{fr,en}.yml` `boosters.island.celebration` -- titles ("PALIER %{tier}", "SET COMPLET"), count "%{owned}/%{total}", tier names (BRONZE/ARGENT/OR), folded (plural) "%{count} PALIERS ATTEINTS", position "%{index} / %{count}", next "Résultat suivant", announcements: "Palier %{tier} atteint : %{set}, %{owned} cartes sur %{total}.", "Set complet : %{set}, %{owned} cartes sur %{total}.", folded (plural) "%{count} paliers atteints : %{list}." with items "%{set}, %{tier}" joined by " ; " and lowercase tier names (bronze, argent, or, complet). English: "SILVER TIER", "SET COMPLETE", "n TIERS REACHED", "Next result", "Silver tier reached: Roguelike, 16 cards of 62.", "Set complete: …", "4 tiers reached: Roguelike, silver; …".
- `packs/game/lib/open_pack_benchmark.rb` -- seed `catalog_set_tiers` (themes with four rows, studios complete) and some cards in an earlier season held by players.
- Tests and fixtures: `test/fixtures/catalog/set_tiers.yml` (`valve_one` complete, required 1, so portal_one still completes it); replace `SetCompletion` in the files the review listed (`first_discovery_and_set_completion_test.rb` incl. the statement budget at 114-132, the concurrency teardowns, `achievements_test.rb`, `export_of_test.rb`, `player_export_test.rb`, `delete_player_test.rb`, `accounts_controller_test.rb` `ERASED_OR_CANCELLED`; `delete_retired_set_kinds_migration_test.rb` uses raw SQL for completions); `packs_controller_test.rb:383,410,439` (keys, integer paths, replay); `opening.test.ts` fixture; `boosters_controller_test.rb` (strings follow the locale).
- Don't touch: `Game::TierCounts`, `Catalog::PublishSeason`/`SetBuilder`, the feed handlers, `app/views/packs/show.html.erb`, `game_set_completions`' schema.

## Tasks & Acceptance

**Execution:**
- [x] `db/migrate/…_create_game_set_tiers.rb`, `db/schema.rb` -- the table.
- [x] `held_games.rb`, `set_tier.rb`, `set_tier_reached.rb`, `set_completion.rb`, `operation.rb` -- measure, tier pass, events.
- [x] `open_pack.rb`, `draw_pool.rb`, `top_up_bank.rb`, `accept_trade.rb`, `release_player.rb` -- one season read, tier pass, publish, delete.
- [x] `achievement_progress.rb`, `export_of.rb`, `player_export.rb` -- read the new rows.
- [x] `pack_set_tiers.rb`, `packs_helper.rb` -- `setTiers` in the answer and its replay.
- [x] Frontend: `opening.ts`, `celebration.ts`, `booster_props.ts`, `Booster.tsx`, `BoosterCelebration.tsx`, `BoosterPanel.tsx`, `BoosterPlate.tsx`/`BoosterView.tsx`, CSS, locales.
- [x] Benchmark seeding.
- [x] Tests: a `set_tier_test.rb` covering every matrix row (incl. earlier edition and trade), `held_games_test.rb` (best rarity across editions, quantity 0 ignored), achievements by kind and key across seasons, packs controller `setTiers` shape/replay/no ids, `celebration.test.ts` (one per set, order, fold, announcements fr), statement budget updated, existing tests adapted.

**Acceptance Criteria:**
- Given a player whose opening crosses a theme's bronze, when the booster's hand completes, then one result "PALIER BRONZE · <theme> n/N" shows after any result banner, the live region gains one message, and nothing else is announced for it.
- Given a player who completed two seasons' sets of the same kind and key, when their achievements are granted, then `first_complete_set` counts it once and `three_complete_sets` is not advanced by the duplicate.
- Given the change, when the checks run, then `TZ=UTC bin/rails test`, `npm run test:js`, `npm run typecheck`, `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `bin/rubocop`, `bundle exec i18n-tasks missing` and `unused` pass, and grepping `app packs config test` finds no `SetCompletion.record`.

## Implementation Notes

- Decision (author, 2026-10-15): the plan, written unattended, is approved as built: the tier table and its `reached_by`, earlier editions counting, `game_set_completions` kept with no backfill, the one-result-per-set celebration and its copy, no celebration on a restored hand, achievements by set kind and key and by distinct games, the export's `setTiers`. The staging p95 of `POST /packs` with seasons 1 to 4 is the author's check outside the ticket.
- `DrawPool.of(season)` reads the season it is given (`Catalog::PublishedCardSeasonsByTier` takes an optional season), so the three-try loop is gone; `current` delegates to it.

## Plan Change Log

## Review Triage Log

### Pass 1 (quick, 2026-10-15) — high 0, medium 1, low 4, false 1, maybe-false 0

- `false` — "PALIER BRONZE · <theme> n/N" not rendered on one line: the key-screen mockup (`ux-gameble/mockups/key-collection-sets.html`, 4a and 4b) draws the title between hazard ticks with the name and count on a second line, as built; the "·" is the copy deck's notation.
- `medium` patch — `game_set_tiers.pack_id`'s foreign key has no ON DELETE, so the old container's `ReleasePlayer` fails during the deploy for a player who opened a pack on the new one; the foreign key cascades.
- `low` reject — no backfill: existing completions leave the achievement progress and a set already complete is celebrated again at its next card; the approved intent says no backfill, and production has no player yet.
- `low` reject — on a switch to the phone layout with the top card still on the plate, the celebration is announced before it shows; the normal phone flow completes only once every card is stored, and the fix adds a branch for a rare resize.
- `low` patch — planning ids left in comment blocks the diff rewrites (`packs_helper.rb`, `BoosterPanel.tsx`); removed.
- `low` patch — `DrawPool.of(season)` had no test; cases added for the season served and the rebuild on a new key.

## Design Notes

- **One result per set:** the response carries every row (the feed of entry 6 counts them); the celebration keeps each set's highest new row, which also gives "SET COMPLET after its gold": gold reached earlier shows nothing now, gold and complete reached together show SET COMPLET. This is how this story spreads the near-simultaneous crossings the spike foresaw.
- **Counts from the tier rows:** "16/62" is the tier's `required` over the set's total, so the answer and its replay are stable and need no count at answer time.
- **`game_set_completions` stays:** dropping it in the same deploy would fail the old container's openings; the drop is deferred to a contract change.

## Verification

**Commands:**
- `RAILS_ENV=test bin/rails db:drop db:create db:migrate` (DB_PORT of the lane's Postgres 18) -- expected: `db/schema.rb` diff holds only `game_set_tiers` and its FKs
- `TZ=UTC bin/rails test`, `npm run test:js`, `npm run typecheck`, `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `bin/rubocop`, `bundle exec i18n-tasks missing`, `bundle exec i18n-tasks unused` -- expected: green (unused: the pre-existing `rate_limit.*` only)
- `RAILS_ENV=test bin/rails game:benchmark_open_pack` -- expected: POST p95 under 200 ms locally (staging's seasons 1 to 4 measure is the author's)

**Manual checks (if no CLI):**
- System tests are disabled; the island's timing is covered by `celebration.test.ts` and read in `Booster.tsx`.
