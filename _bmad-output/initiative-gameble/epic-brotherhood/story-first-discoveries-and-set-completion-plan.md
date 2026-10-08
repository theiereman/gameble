---
title: 'First discoveries and set completion'
type: 'feature'
ticket: '7'
created: '2026-10-07'
status: done
baseline_revision: 'aa1bffb533170a4246f2cb325c883286b5bbf6ef'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: [oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** Nothing records who pulled a card first in a season, no `Game::SetCompleted` is published when a player completes a set (AD-10; the card backs epic unlocks on it, and story 5.5's review deferred it for accepted trades), and the feed's DÉCOUVERTES filter stays empty.

**Approach:** `Game::OpenPack` inserts one first-discovery row per new card-season of the opened pack (unique per card-season, `ON CONFLICT DO NOTHING RETURNING`) and one set-completion row per set the opener now completes (unique per player and set, same pattern), then publishes `Game::CardDiscovered` and `Game::SetCompleted` for the rows it inserted, after `Game::PackOpened`. `Game::AcceptTrade` does the set-completion part for both players. The feed handler turns the discovered card's entry into a `discovery` entry, shown with the gold "PREMIÈRE DÉCOUVERTE" chip.

## Boundaries & Constraints

**Always:** AD-9: uniqueness left to the database (one discovery row per card-season, one completion row per player and set); no row written by every player. AD-10: events published by the operation inside its transaction, identifiers only, on the player's stream; handlers publish nothing; a duplicate never fails an operation; rows inserted in ascending card-season / set order. The opening stays a fixed handful of statements, with no per-card or per-set query loop (AD-7's 200 ms p95). Visibility asked at render only (AD-13). GET writes nothing (AD-11). French and English copy.

**Never:** The LIVE ticker or broadcasts (story 6.4, not built: discovery entries are feed rows of kind `discovery` it will read); achievements (6.10); card back unlocks (epic 9); discoveries from trades (pulls only); a backfill of sets completed before this ships; changes to `Game::Visibility` or to the feed's paging.

**Decisions (author away):**
- D1: a first discovery of any rarity enters the feed. The pack's entry for that card (its first position) is written with kind `discovery` and `notable` true instead of a pull, so it shows once: under TOUT and DÉCOUVERTES, not under TIRAGES. A pack with a discovery gets no filler.
- D2: sentence "%{card}, trouvée par %{name} pour la première fois dans la communauté" after the chip (the mockup's wording); rarity tag as for pulls.
- D3: completion = every card-season of the set held with `quantity > 0`; only sets holding a card the operation credited are checked. A set completed before this ships publishes its event the next time a credit touches it.
- D4: an accepted trade publishes SetCompleted too (AD-10: any operation that raises quantities; closes story 5.5's deferred finding, as the orchestrator asked); first discoveries come from pulls only.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| New card | pack with an undiscovered Commune | one discovery row (player, pack), one CardDiscovered, a `discovery` feed entry | No error expected |
| Known card | card already discovered | no row, no event, feed as before | DO NOTHING |
| Same card twice in pack | undiscovered card at positions 0 and 3 | one discovery row and event; entry at position 0 is `discovery` | No error expected |
| Race | two players open packs with the same new card at once | one discovery row, one event in total; both openings succeed | second insert waits, then DO NOTHING |
| Set completed by opening | last missing card of a set pulled | one completion row, one SetCompleted after PackOpened | No error expected |
| Set already completed | completion row exists, card pulled again | no row, no event | DO NOTHING |
| Set completed by trade | accepted trade gives the last card of a set | SetCompleted for the receiving player, once | No error expected |
| Card traded away then regained | completion row exists | no second SetCompleted | DO NOTHING |

</intent-contract>

## Code Map

- `db/migrate/` -- two migrations after 20261007140602: `create_game_first_discoveries` (card_season_id bigint unique, player_id FK accounts_players, pack_id FK game_packs indexed, discovered_at, timestamps; index player_id) and `create_game_set_completions` (player_id FK, set_id bigint, completed_at, timestamps; unique [player_id, set_id]). Pattern: `20261007130400_create_game_feed_entries.rb`. `db/schema.rb` dumped from `gameble_dev_6_7`.
- `packs/game/app/models/game/first_discovery.rb` -- new; `record(pack, now)` -> discovered card-season ids (insert_all sorted, `unique_by: :card_season_id`, `returning`).
- `packs/game/app/models/game/set_completion.rb` -- new; `record(player_id, card_season_ids, now)` -> completed set ids: one `INSERT … SELECT … GROUP BY set_id HAVING count(holding) = count(*) … ON CONFLICT DO NOTHING RETURNING set_id` joining `catalog_set_memberships` to `game_holdings` (Game reads Catalog, AD-2; see `Game::SetProgress`, `Game::HubSets`).
- `packs/game/app/events/game/card_discovered.rb`, `set_completed.rb` -- new; data `{ player_id:, card_season_id:, pack_id: }` / `{ player_id:, set_id: }`.
- `packs/game/app/operations/game/open_pack.rb` -- after `credit`: record discoveries and completions; after PackOpened publish the extra events (replay publishes nothing, unchanged).
- `packs/game/app/operations/game/accept_trade.rb` -- after both `move`s, completions for proposer (request cards) then recipient (offer cards), ascending player id; SetCompleted after TradeAccepted on each player's stream.
- `packs/game/app/handlers/game/handlers/pack_opened_feed.rb` + `packs/game/app/models/game/feed_entry.rb` (`record_pack(..., discovered:)`) -- one extra read of the pack's discoveries.
- `app/views/feeds/show.html.erb`, `app/frontend/styles/feed.css`, `config/locales/{fr,en}.yml` (`feeds.show.discovered_html`, `first_discovery`) -- chip on `{colors.gold}` / `--color-on-gold`.
- `test/fixtures/game/` -- fixture discoveries of the five fixture card-seasons (with a fixture opened pack of `administrator`) so existing pull tests stay pulls; discovery tests delete the row they need.
- `packs/game/lib/tasks/game_benchmark.rake` -- seed publisher sets so the benchmark exercises the completion query.
- Do not change: `Game::Visibility`, `Game::FeedEntries`, `FeedsController::FILTERS`.

## Tasks & Acceptance

**Execution:**
- [x] migrations, `db/schema.rb` -- the two tables.
- [x] `first_discovery.rb`, `set_completion.rb`, the two events.
- [x] `open_pack.rb`, `accept_trade.rb` -- record and publish.
- [x] `feed_entry.rb`, `pack_opened_feed.rb`, feed view, css, locales -- discovery entries.
- [x] fixtures; adjust existing tests whose event counts now include SetCompleted (fixture set `valve_one` holds only `portal_one`).
- [x] `test/packs/game/first_discovery_and_set_completion_test.rb`, `first_discovery_concurrency_test.rb` (matrix rows, feed entry kind, filter), concurrency test with two players on their own connections, set completion tests (opening, trade, once), feeds controller test for the chip in fr and en.
- [x] benchmark seeding of sets.

**Acceptance Criteria:**
- Given two players open packs holding the same undiscovered card at the same moment, when both commit, then exactly one first-discovery row and one CardDiscovered exist, naming the player whose insert won.
- Given a player completes a set by an opening or an accepted trade, then SetCompleted is published once for that player and set, and never again for it.
- Given a discovery entry, when a signed-out visitor opens the feed under TOUT or DÉCOUVERTES, then the entry shows with the "PREMIÈRE DÉCOUVERTE" chip; under TIRAGES it does not show.
- Given the opening, then it adds at most three statements when nothing is discovered or completed.

## Implementation Notes

- Subagents unavailable (no Agent tool in this lane), done in-session.
- Lane branch fast-forwarded to develop at story 5.5's merge (aa1bffb) before any change, as the orchestrator asked; D4 (SetCompleted from accepted trades) is the 5.5 deferred finding.
- Discoveries are recorded by `Game::OpenPack` (an operation, since the event has to be published there, AD-10), before `PackOpened`, so the feed handler reads them by `pack_id` (one indexed read) and the choice of what enters the feed stays in that one handler (AD-13). Discovery inserts run in ascending card-season: two openings racing on the same new cards wait in one order, never in a cycle.
- `Game::SetCompletion.record` is one `INSERT … SELECT … GROUP BY … HAVING … ON CONFLICT DO NOTHING RETURNING`; sets already completed are skipped in SQL (`NOT EXISTS`). `Game::Operation#publish_completions` is shared by OpenPack and AcceptTrade.
- Test fixtures: every fixture card-season is already discovered by a fixture opened pack of the banned player (`test/fixtures/game/{packs,first_discoveries}.yml`), so the 6.1/6.2 pull tests stay pulls; the banned player is hidden and never healed. Four assertions of "no pack written" now count unopened packs, and two concurrency teardowns delete set completions. The fixture set `valve_one` holds only portal_one, so any opening of portal_one completes it: the feed test that counts events opens a legendary card instead.
- The benchmark now seeds one set per publisher (900 sets of about 17 cards) so the completion query runs as in play; discoveries happen naturally on its fresh season.
- No ticker work: story 6.4 is not built (the layout only has its slot); discovery entries are feed rows of kind `discovery` for it to read.
- Merge of develop (a05d0eb: 7.6, 6.5, 5.3, 7.8, 5.10), as the orchestrator asked:
  - `db/schema.rb`: develop's 20261007170810 is newer than this story's two migrations, so loading its schema would mark them as run. The schema was regenerated on an empty lane database with schema.rb moved aside (every migration ran, 150000 and 150100 included); the dump matched develop's plus the two tables, so develop's file was kept with only those tables added (no churn in check-constraint formatting between PostgreSQL versions).
  - Account deletion (7.8, `Game::ReleasePlayer`): set completions are deleted with the player's other derived rows; first discoveries stay with `pack_id` set to null before the packs go, so a card is never discovered twice in its season (AD-9). `game_first_discoveries.pack_id` is therefore nullable (the create migration edited: it was never on develop). Test in `test/packs/accounts/delete_player_test.rb`.
  - Fixture design changed: the fixture discoveries no longer reference a fixture pack (`test/fixtures/game/packs.yml` removed, `pack_id` null, as a deletion leaves it). Non-transactional cleanups that delete every pack (7.6's `bank_races_test.rb`) no longer hit the foreign key; the six test tweaks that counted the fixture pack were reverted to develop's. `bank_races_test.rb`, `delete_player_concurrency_test.rb` and `open_pack_concurrency_test.rb` teardowns also delete the set completions and the discoveries of their own packs, so each leaves the database as it found it.
  - 7.8's `lock_bank` is kept in `Game::OpenPack`; it touches neither new table. The budget test failed once on a schema introspection query of a new table counted in a fresh worker: it now warms the schema cache and skips `SCHEMA` queries.
- Lane mistake, recorded: while stopping a hung test run of this lane, a `pkill -f "rails test"` was issued, which may also have stopped test runs of other lanes on the shared machine.

## Plan Change Log

## Review Triage Log

### 2026-10-07 — Review pass
- verdicts: 3 findings — high 0, medium 0, low 3, false 0, maybe-false 0 (quick lens run in-session, subagents unavailable)
- findings:
  - `[low]` `[patch]` `FeedsController`'s header comment still said only pulls exist — patched to name first discoveries.
  - `[low]` `[patch]` `feed_test.rb`'s `add_entries` comment said only pulls have a handler — patched (trades and reposts have none yet).
  - `[low]` `[reject]` Every opening's discovery insert spends sequence values on conflicting rows (5 per opening) — bigint ids, no user or developer meets it; avoiding it needs an extra read before the insert.

## Verification

**Commands:**
- `bin/rails test test/packs/game test/controllers/feeds_controller_test.rb test/controllers/packs_controller_test.rb` -- expected: green
- `bin/rails test` (PARALLEL_WORKERS=2) -- expected: green
- `bin/rails test:system TEST=test/system/booster_test.rb` (PARALLEL_WORKERS=1) -- expected: green
- `bin/rubocop` (changed files), `bundle exec packwerk check`, `bundle exec i18n-tasks missing`, `bundle exec i18n-tasks unused`, `npm run typecheck`, `npx vitest run` -- expected: clean

## Auto Run Result

Status: built.

**Summary:** An opening records the first pull of each card-season (`game_first_discoveries`, unique per card-season, `ON CONFLICT DO NOTHING RETURNING`) and every set the opener now holds whole for the first time (`game_set_completions`, unique per player and set, one `INSERT … SELECT … HAVING`), then publishes `Game::CardDiscovered` and `Game::SetCompleted` after `Game::PackOpened`. An accepted trade records and publishes set completions for both players (story 5.5's deferred finding). The feed handler writes a discovered card's entry as kind `discovery` (any rarity, notable); the feed shows it with the gold "PREMIÈRE DÉCOUVERTE" chip under TOUT and DÉCOUVERTES.

**Files:**
- `db/migrate/20261007150000_create_game_first_discoveries.rb`, `20261007150100_create_game_set_completions.rb`, `db/schema.rb` -- the two tables.
- `packs/game/app/models/game/first_discovery.rb`, `set_completion.rb` -- record and answer the new rows.
- `packs/game/app/events/game/card_discovered.rb`, `set_completed.rb` -- the events.
- `packs/game/app/operations/game/{open_pack,accept_trade,operation}.rb` -- record and publish.
- `packs/game/app/handlers/game/handlers/pack_opened_feed.rb`, `packs/game/app/models/game/feed_entry.rb` -- discovery entries.
- `app/views/feeds/show.html.erb`, `app/frontend/styles/feed.css`, `config/locales/{fr,en}.yml`, `app/controllers/feeds_controller.rb` -- chip and sentence.
- `packs/game/lib/tasks/game_benchmark.rake` -- seeds one set per publisher.
- `test/fixtures/game/{packs,first_discoveries}.yml` and tests (new: `first_discovery_and_set_completion_test.rb`, `first_discovery_concurrency_test.rb`; adjusted: feed, feeds controller, fill/top-up/heal banks, daily bonus, concurrency teardowns, two catalog tests that wipe seasons).

**Review:** 2 patches (low), 0 deferred, 1 rejected (reason in the triage log). Follow-up review recommended: false (patched: high 0, medium 0, low 2).

**Verification:** `bin/rails test` (PARALLEL_WORKERS=2): 1479 runs, the two catalog tests that wipe seasons then fixed and the shell test's countdown delta (timing under load) green on rerun of those files (100 runs, 0 failures); game, feed and packs tests 319 runs green; the race test green three times; `test/system/booster_test.rb` 33 runs green; rubocop, packwerk, i18n-tasks missing/unused clean; `npm run typecheck` and `npx vitest run` (132) green. The statement budget is covered by a test (three statements more per opening); the benchmark task was not run (author's quota; its database name is shared between lanes).

**Residual risks:** the timed benchmark (`RAILS_ENV=test bin/rails game:benchmark_open_pack`) is still to run; at a season's launch most cards are first discoveries, so DÉCOUVERTES entries dominate TOUT (D1, tuned in play); sets completed before this ships publish their event at the next credit touching them (D3); the LIVE ticker (6.4) must read `discovery` entries; `db/schema.rb` version will conflict with other lanes adding migrations (keep the highest version and every table).

**After the merge of develop (a05d0eb):** `bin/rails test` (PARALLEL_WORKERS=2) twice, 1585 runs, 0 failures both times; game, accounts, feed and packs tests 492 runs green; `test/system/booster_test.rb` 33 runs green; rubocop on changed files, packwerk, i18n-tasks missing/unused clean.
