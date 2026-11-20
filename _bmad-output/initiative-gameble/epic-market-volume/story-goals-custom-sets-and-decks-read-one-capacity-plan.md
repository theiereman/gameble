---
title: 'Goals, custom sets and decks read one capacity'
type: 'feature'
ticket: '4'
created: '2026-11-20'
status: 'built'
baseline_revision: '392e76600b0e8b71c66729156a27a3323e2ffb7e'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context: ['{project-root}/AGENTS.md']
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Three separate hard limits (`Game::Goal::POSITIONS` 1..5, `Game::CustomSet::PER_PLAYER` 10, `Game::Deck::PER_PLAYER` 5) are read in operations and screens; the market-volume epic needs one per-player capacity, free count plus bought slots, so later stories can sell slots.

**Approach:** Add `game_capacity_slots` (bought count per player and kind) and `Game::Capacity` (free 5/5/3, ceilings 10/10/5, `limit(player, kind)` = free + bought); every operation and screen reads it. Widen the goal position check to 1..10 expand/contract, add goal colours 6 to 10, and grant at deploy, by data migration, the custom-set and deck slots players already use above the new free counts.

## Boundaries & Constraints

**Always:** `Game::Capacity.limit` is the only limit read by `AddGoal`, `CreateCustomSet`, `CreateDeck`, `PlayerDecks.room_left?`, `DeckList`, the custom sets section, the OBJECTIFS count and free slot line, the duels deck heading and Comment ça marche's deck line. Limits are checked under the player's bank lock as today. Migrations are expand/contract (strong_migrations); the grant writes no ledger entry and hardcodes the free counts 5 and 3 (a migration does not load app constants). Every string in `en.yml` and `fr.yml`. No planning ids in code.

**Never:** No `BuySlot`, no purchase dialog, no slot prices, no export rows (later stories). Do not touch the market ledger, orders, settings or tied-account code (other lanes). Do not hand-edit `db/schema.rb`. No new refusal codes: at a free limit and at the ceiling the operations still answer `:too_many_goals`, `:too_many_sets`, `:too_many_decks`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Limit, no slot | player with no `game_capacity_slots` row | `limit(player, :goal)` 5, `:custom_set` 5, `:deck` 3 | — |
| Limit, bought | row custom_set bought 1 | `limit(player, :custom_set)` 6 | — |
| Limit, nil player | `limit(nil, :deck)` | 3 (the free count) | — |
| Sixth goal, free limit | five goals, no slot | refused | `:too_many_goals`, nothing written |
| Sixth goal, one bought | five goals, goal bought 1 | added at position 6 | — |
| Goal 10 | goal bought 5, nine goals | added at position 10, stored by the DB check | — |
| Sixth custom set / fourth deck | at free limit, no slot | refused | `:too_many_sets` / `:too_many_decks` |
| Grant | player A 7 custom sets, 4 decks; player B 5 sets, 3 decks; steam_library set not counted | A gets custom_set 2 and deck 1 rows; B gets no row | — |
| DB bounds | bought 0, goal/custom_set 6, deck 3 | refused by the check | `ActiveRecord::StatementInvalid` |

</intent-contract>

## Code Map

- `app/domains/game/app/models/game/goal.rb` -- `POSITIONS = (1..5)`: remove; its callers read `Capacity`.
- `app/domains/game/app/models/game/custom_set.rb:10`, `deck.rb:7` -- `PER_PLAYER`: remove.
- `app/domains/game/app/operations/game/add_goal.rb:24` -- `free_position`: lowest of `1..Capacity.limit(player, :goal)` not taken.
- `app/domains/game/app/operations/game/create_custom_set.rb:24`, `create_deck.rb:30` -- `room_left` count against `Capacity.limit`.
- `app/domains/game/app/queries/game/player_decks.rb:9` -- `room_left?`.
- `app/models/deck_list.rb:22` -- `room_left?`; add `limit` for the heading.
- `app/views/duels/_decks.html.erb` + `config/locales/*.yml` `duels.decks.count` / `heading_spoken` -- hardcode "/ 5": take `max:`.
- `app/controllers/library_controller.rb#show` -- load `@goal_slots`, `@custom_set_slots` via `Game::Capacity.limit`; pass through `app/views/library/show.html.erb` → `library/_entry` → `library/_goals` (`slots:` local) and `library/_custom_sets` (`slots:` local, replacing every `PER_PLAYER`).
- `app/helpers/goals_helper.rb:50` -- `goal_free_slot(goals)` takes the slot count.
- `app/views/pages/how_it_works.html.erb:97` + `pages.how_it_works.duels.decks` copy (en ~3967, fr ~657).
- `app/domains/game/app/operations/game/release_player.rb` -- deletion erases per-table rows; add `CapacitySlot`.
- `test/controllers/accounts_controller_test.rb` `ERASED_OR_CANCELLED` -- asserts every table with an FK to `accounts_players` is named in the Delete dialog (`accounts...note`, en.yml:60, fr.yml:3626); privacy deletion copy at fr.yml:528 and its en twins.
- `app/frontend/styles/tokens.css:43-47`, `app/frontend/styles/collection-goals.css:3-21,332-350` -- goal tones 1..5; extend to 10.
- Pattern refs: `db/migrate/20261119100000_*` / `20261119100001_*` (check replaced unvalidated, validated next), `db/migrate/20261015120000_welcome_every_existing_player.rb` (data migration with `safety_assured`), `db/migrate/*create_game_decks*` (table style).
- Tests touched: `test/domains/game/goal_operations_test.rb:58`, `deck_operations_test.rb` (first test makes four decks; "a sixth deck"), `custom_set_operations_test.rb:104`, `test/controllers/goals_controller_test.rb:102`, `test/controllers/how_it_works_test.rb:108`, `test/controllers/duels_controller_test.rb:45,64`, `test/system/duels_test.rb:63`, any other test making more than 3 decks or 5 custom sets for one player.

## Tasks & Acceptance

**Execution:**
- [x] `db/migrate/20261120160000_create_game_capacity_slots.rb` -- `player` FK to `accounts_players` (no index of its own), `kind` string, `bought` integer, timestamps; unique index `[player_id, kind]`; check kind is goal, custom_set or deck written as `kind::text = '...'::text OR ...`; check bought 1..5, and 1..2 for decks.
- [x] `db/migrate/20261120160001_widen_game_goals_position_check.rb` + `20261120160002_validate_game_goals_position_check.rb` -- replace `game_goals_position_check` by `position BETWEEN 1 AND 10`, `validate: false`, then validate.
- [x] `db/migrate/20261120160003_grant_capacity_slots_already_used.rb` -- `up` inserts per player `custom_set` `count(custom sets of kind custom) - 5` and `deck` `count(decks) - 3` where above zero, `ON CONFLICT (player_id, kind) DO NOTHING`; `down` empty.
- [x] `app/domains/game/app/models/game/capacity_slot.rb` -- model on `game_capacity_slots`.
- [x] `app/domains/game/app/queries/game/capacity.rb` -- `FREE`, `CEILING` hashes keyed `:goal, :custom_set, :deck`; `limit(player, kind)`.
- [x] Operations, queries, `DeckList`, controller, views, helper per Code Map; remove the three constants.
- [x] `config/locales/en.yml`, `fr.yml` -- `errors.game.too_many_goals` and `goals.full.limit` say 10 (fr "10 objectifs au plus. Retirez un objectif pour en ajouter un autre." / "10 objectifs au plus"; en "10 goals at most. …" / "10 goals at most"); `duels.decks.count` "%{count} / %{max}", `heading_spoken` "…, %{count} sur %{max}" / "… %{count} of %{max}"; how-it-works deck line "…et vous pouvez garder %{free} decks, jusqu'à %{ceiling} avec des emplacements achetés." / "…and you can keep %{free} decks, up to %{ceiling} with bought slots."; Delete dialog and privacy deletion text add "vos emplacements achetés" / "your bought slots" after the decks.
- [x] `release_player.rb` -- `CapacitySlot.where(player_id:).delete_all`; add the table to `ERASED_OR_CANCELLED`.
- [x] `tokens.css` `--color-goal-6..10` (#b8b000, #00b4bc, #fca8b0, #ff775c, #9cc474); `collection-goals.css` `.goal-tone--6..10` and `.set-album__header:has(.goal-control--set.goal-tone--N)` for 6..10.
- [x] `test/domains/game/capacity_test.rb` -- limit rows of the matrix, DB bounds, and the grant (require the migration file, run `migrate(:up)` under `suppress_messages`; insert sets/decks with `create!`).
- [x] `test/domains/game/goal_operations_test.rb` -- sixth goal refused at free limit, accepted with one bought slot, goal stored at position 10.
- [x] Fix every other broken test (decks over 3, sets over 5, "/ 5" deck headings, refusal copy).
- [x] `test/system/library_test.rb` (or `custom_sets_test.rb`) -- one test: a player with five goals and no slot sees OBJECTIFS "5 / 5" and MES SETS "n / 5"; a player with six custom sets and a custom_set bought 1 sees "6 / 6".

**Acceptance Criteria:**
- Given a player with no slot, when they open the Collection, then OBJECTIFS reads "n / 5" and MES SETS "n / 5"; with one bought custom-set slot and six sets, MES SETS reads "6 / 6".
- Given a player with three decks and no slot, when they open Duels, then MES DECKS reads "3 / 3" and "+ NOUVEAU DECK" is absent.
- Given a goal at position 6 to 10, when its bookmark, row, set tile or album header renders, then it carries that goal's colour.
- Given Comment ça marche, when it renders, then the deck line names 3 and 5 in both locales.

## Implementation Notes

- Implemented on the full route by one coding subagent; `Game::Capacity` lives in `queries/game/capacity.rb`, `Game::CapacitySlot` in models. `LibraryController#show` loads `@goal_slots` and `@custom_set_slots` and passes them down as `slots:` locals; `DeckList#limit` feeds the duels heading.
- The library page's query-count test rose from 26 to 28 (two capacity reads).
- The system test went into `test/system/custom_sets_test.rb`.
- Review patch: the account deletion test now proves bought slots are erased with the player.

## Plan Change Log

## Review Triage Log

### 2026-11-20 — Review pass
- verdicts: 4 findings — high 0, medium 0, low 4, false 0, maybe-false 0
- findings:
  - `[low]` `[reject]` At a free limit the refusals name the ceiling while the counter shows the free limit (3 / 3 with "Five decks at most", "5 sets at most" tile vs "10 SETS AT MOST") — the intent keeps the existing refusals at a free limit and leaves that press to the slot-purchase story; the epic ships whole in one release, so no player meets the interim copy.
  - `[low]` `[reject]` A set or deck created between the grant migration and the new code switching in leaves a player above their limit with no slot — the window is the deploy overlap only, no data is lost, the player can still delete; closing it needs a second grant pass, more than a direct fix.
  - `[low]` `[patch]` No test exercises erasing capacity slots on deletion — added a CapacitySlot for both players in the decks deletion test of `test/domains/accounts/delete_player_test.rb`, asserting the deleted player's is gone and the other's stays (18 runs, 0 failures).
  - `[low]` `[reject]` Goal colours 6 to 10 are untested — the classes are interpolated from the goal's position by the unchanged helpers and views (`goal-tone--#{position}`), and the new CSS rules are present; a test would only assert the CSS file's text.

## Design Notes

The Delete-dialog test fails for any new FK to players, so this story erases capacity rows on deletion and names them in the dialog and privacy text; the export of bought slots stays with the removal story. At a free limit the refusal copy now reads the ceiling's ("10 objectifs au plus"): the epic ships whole, and the slot-purchase story replaces that press at a free limit. `Game::Capacity` reads one row per call; no caching.

## Verification

Run every Rails command from the worktree with `export DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w46_4 CHROME_BIN=/usr/bin/chromium`.

**Commands:**
- `RAILS_ENV=test SCHEMA=tmp/migrated_schema.rb bin/rails db:drop db:create db:migrate db:schema:dump && cp tmp/migrated_schema.rb db/schema.rb` -- expected: schema diff limited to the new table and the goal check.
- `bin/rails test` -- expected: green.
- `bin/rails test test/system/<touched files>` (library or custom sets, goals, duels) -- expected: green; never the whole system suite.
- `bin/ci`, `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check` -- expected: pass.

## Auto Run Result

Status: built

**Summary:** `game_capacity_slots` and `Game::Capacity` (free 5 goals, 5 custom sets, 3 decks; ceilings 10, 10, 5) replace `Goal::POSITIONS`, `CustomSet::PER_PLAYER` and `Deck::PER_PLAYER` in `AddGoal`, `CreateCustomSet`, `CreateDeck`, `PlayerDecks`, `DeckList`, OBJECTIFS, MES SETS, MES DECKS and Comment ça marche. The goal position check widens to 1 to 10 (expand then validate), goal colours 6 to 10 join the tokens and tones, and a deploy data migration grants the custom-set and deck slots players already use above the free counts.

**Files changed:**
- `db/migrate/20261120160000_create_game_capacity_slots.rb` -- the table, its unique index and checks.
- `db/migrate/20261120160001_widen_game_goals_position_check.rb`, `20261120160002_validate_game_goals_position_check.rb` -- goal positions 1 to 10.
- `db/migrate/20261120160003_grant_capacity_slots_already_used.rb` -- the slot grant.
- `db/schema.rb` -- regenerated from migrations.
- `app/domains/game/app/models/game/capacity_slot.rb`, `app/domains/game/app/queries/game/capacity.rb` -- new.
- `goal.rb`, `custom_set.rb`, `deck.rb` -- constants removed; `add_goal.rb`, `create_custom_set.rb`, `create_deck.rb`, `player_decks.rb`, `deck_list.rb` -- read the capacity; `release_player.rb` -- erases capacity rows.
- `library_controller.rb`, `library/show`, `_entry`, `_goals`, `_custom_sets`, `duels/_decks`, `pages/how_it_works`, `goals_helper.rb` -- screens read the limit.
- `tokens.css`, `collection-goals.css` -- goal colours 6 to 10.
- `config/locales/en.yml`, `fr.yml` -- ten-goal refusal, deck heading max, deck line, bought slots in the Delete dialog and privacy text.
- Tests: new `capacity_test.rb`; goal, deck and custom-set operations; accounts, custom sets, decks, duels, goals, how-it-works, library controllers; delete player; system custom sets and duels.

**Review:** 1 patch (low), 0 deferred, 3 rejected (see triage log).

**Follow-up review recommended:** false (no high or medium patched).

**Verification:** `bin/rails test` 6184 runs, 0 failures (3 lock-race tests errored on "too many clients" under shared Postgres load and passed rerun alone); system `custom_sets_test.rb`, `duels_test.rb`, `goals_test.rb` 15 runs green; `bin/ci` steps run one by one (rubocop, packwerk validate/check, i18n-tasks, typecheck, markup APIs, format, CSS lint, planning references, file sizes, brakeman) pass; `zeitwerk:check` and `npm run test:js` (1517) pass; schema rebuilt from migrations matches and round-trips.

**Residual risks:** free-limit refusal copy names the ceiling until the slot-purchase story; bought slots not yet in the data export (removal story); a two-digit 10 in the small goal bookmark not checked visually.
