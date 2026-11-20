---
title: 'The practice bot plays skilled with a named archetype deck'
type: 'feature'
ticket: '4'
created: '2026-11-20'
status: 'built'
baseline_revision: '6ef4f5df7967f31a1f1d81407bfe64d94a20c50a'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The practice bot plays the automatic move half the time and a random one otherwise, with a random deck, so beating it teaches nothing and its deck says nothing about which recipes hold.

**Approach:** A pure object computes the bot's call and answer from its own seat's `Game::DuelView` alone, valuing point and margin against the answer a reader of the shown card would give from every hand the other seat may hold. One archetype object defines the nine bot decks (coverage, one per stat, two stats, trump sort, random), builds them from the catalog and classifies any deck; each practice duel deals one, never the previous one, stores it in `game_duels.bot_archetype` and names it under the opponent's name.

## Boundaries & Constraints

**Always:** the bot reads only `DuelView.for(duel, bot_seat)` (its hand, both decks, both `played` lists, both `stats_left`, `current_call.card`); payoff of a round for the caller = point (+1 / -1 / 0) × (1 + margin / 100), from `DuelRules.outcome`; a bot deck is 12 editions with 12 distinct `card_id`s; strings in `en.yml` and `fr.yml`; migrations expand/contract; `db/schema.rb` edited by hand to match the migrations exactly.

**Never:** read `duel` rows, draw orders or the other seat's hand inside the strategy; touch the automatic move (`DuelRules#automatic_call/answer`); a back-office page (a later entry); run tests, linters or migrations in this build (the coordinator runs them).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Skill | 300 seeded in-memory duels, bot vs automatic move, first caller alternating | bot wins at least 60 % | No error expected |
| Hidden call | same view, other seat's locked stat or draw order differ | identical bot call and answer | No error expected |
| Duplicate game | pool holds two editions of one game | deck holds that game once | No error expected |
| Coverage gap | no card at 90+ for a direction | strongest card left for that direction | No error expected |
| Thin catalog | pool under 12 distinct games | deck under 12 cards | existing `:deck_not_ready` failure |
| Repeat | player's previous practice duel had archetype A | next archetype is not A | No error expected |
| Live duel | `bot_archetype` nil | no archetype line | No error expected |

</intent-contract>

## Code Map

- `app/domains/game/app/models/game/practice_bot.rb` -- module: `player_for`, `deck_cards` (random), `thinking_time`, `call_move`/`answer_card` (to remove, with `SMART_SHARE`, `CANDIDATES`).
- `app/domains/game/app/operations/game/play_practice_move.rb` -- plays the bot's move through `CallRound`/`AnswerRound`; `position(rules, card)` maps a card to its deck slot (DuelCards compare by value).
- `app/domains/game/app/operations/game/start_practice_duel.rb` -- builds the bot deck via `DuelSnapshot.for_cards(PracticeBot.deck_cards)`; `Duel.new(practice: true)` then `update!`.
- `app/domains/game/app/models/game/duel_rules.rb` -- `strength(card, stat, direction)` (−1 when no percentile), `outcome(...)` → `Outcome(winner: :caller/:answerer/nil, margin)`, `HAND_SIZE`.
- `app/domains/game/app/models/game/duel_view.rb` -- `Side(role, deck, played (ids), score, margin, stats_left)`, `hand`, `current_call` (card only for the answerer). Works on an unsaved `Game::Duel` with `Game::DuelSeat.new(role: "opponent")` (nil ids match).
- `app/domains/game/app/queries/game/deck_coverage.rb` -- `GAP_BELOW = 90`: reuse as the strong threshold.
- `app/domains/game/app/queries/game/duel_profiles.rb` -- `weekly_changes` shows the pluck-with-join pattern on `game_duel_stats` + `catalog_card_seasons`.
- `app/models/duel_screen.rb`, `app/views/duels/_header.html.erb` -- opponent name in `.duel-board__score` (3-column grid, `app/frontend/styles/duel-board.css`, uppercase label font).
- `config/i18n-tasks.yml` `ignore_unused` -- add `duels.archetypes.*` (dynamic key).
- `test/support/duels.rb` -- `duel_card`, `duel_deck`, `active_duel`, `lock_call`, `answer_call` build duels in memory; `test/support/live_duels.rb`, `test/domains/game/practice_duel_test.rb`, `test/system/duels_test.rb` ("trains against the bot").
- Latest migrations `db/migrate/20261118130000_add_forfeited_by_to_game_duels.rb` + `20261119100000_write_reaction_and_forfeit_checks_as_equalities.rb` show the check style (`col::text = 'v'::text` equalities, `validate: false`, then a validate migration); schema version is `2026_11_19_100001`.

## Tasks & Acceptance

**Execution:**
- [x] `app/domains/game/app/models/game/skilled_play.rb` -- new `Game::SkilledPlay.new(view)` with `call_move` → `DuelRules::Call` and `answer_card` → `DuelCard` -- see Design Notes.
- [x] `app/domains/game/app/models/game/deck_archetypes.rb` -- new `Game::DeckArchetypes` module: `NAMES`, `OTHER`, `build(name, pool, random: Random)`, `classify(cards)` -- see Design Notes.
- [x] `app/domains/game/app/models/game/practice_bot.rb` -- drop the half-random moves; add `archetype_after(human, random: Random)` (most recent practice duel where a seat holds `human.id`, by id desc, `pick(:bot_archetype)`; sample from `NAMES` minus it) and `deck_cards(archetype)` = `DeckArchetypes.build(archetype, catalog).map(&:card_season_id)`, `catalog` plucking `card_season_id`, `card_id` and the five `*_percentile` of `DuelStat.where.not(discovery_value: nil)` into `DuelCard`s (value/median_distance nil, number/rarity 0).
- [x] `app/domains/game/app/operations/game/play_practice_move.rb` -- `SkilledPlay.new(DuelView.for(duel, duel.seat_of(player)))` for both moves.
- [x] `app/domains/game/app/operations/game/start_practice_duel.rb` -- pick the archetype, build that deck, `Duel.new(practice: true, bot_archetype:)`.
- [x] `db/migrate/20261120140000_add_bot_archetype_to_game_duels.rb` -- `add_column :game_duels, :bot_archetype, :string` + check `bot_archetype IS NULL OR bot_archetype::text = 'coverage'::text OR …` (the nine names written literally), name `game_duels_bot_archetype_check`, `validate: false`.
- [x] `db/migrate/20261120140001_validate_game_duels_bot_archetype_check.rb` -- `validate_check_constraint`.
- [x] `db/schema.rb` -- version `2026_11_20_140001`; `t.string "bot_archetype"` after `forfeited_by`; the check line after the last `game_duels` check, in the dumped form (no outer parentheses).
- [x] `app/models/duel_screen.rb`, `app/views/duels/_header.html.erb`, `app/frontend/styles/duel-board.css` -- `bot_archetype` delegating to the duel; a `<span class="duel-board__bot">` after the opponent span when present; CSS `grid-column: 3; text-transform: none;`.
- [x] `config/locales/en.yml`, `config/locales/fr.yml`, `config/i18n-tasks.yml` -- `duels.board.bot_archetype` ("The bot plays a %{archetype} deck" / "Le bot joue un deck %{archetype}") and `duels.archetypes.*` names (Design Notes).
- [x] Tests -- `test/domains/game/skilled_play_test.rb`, `test/domains/game/deck_archetypes_test.rb`, additions to `practice_duel_test.rb` and `test/system/duels_test.rb` (see Acceptance).

**Acceptance Criteria:**
- Given 300 seeded in-memory duels (random percentiles from `Random.new(seed)`, the bot as `opponent` through `SkilledPlay` on `DuelView.for`, the other seat through `automatic_call`/`automatic_answer`, first caller alternating), when they are played out, then the bot wins at least 180; no database write.
- Given two duels differing only in the challenger's draw order (and, when answering, the locked stat and direction of the shown card), when the bot calls or answers, then its move is identical (and the hands are asserted different).
- Given a pure test pool of 60 games plus a second edition of one game, when each of the nine archetypes is built, then each deck has 12 cards, 12 distinct `card_id`s, all from the pool; and `classify` names hand-made coverage, single-stat, two-stat and trump decks, and `other` for a deck at 50.
- Given a player whose practice duel left its seats, when they start another, then both duels store an archetype from `NAMES` and they differ.
- Given a practice duel opened in the browser, then the line "The bot plays a <name> deck" shows in `.duel-board__bot`.

## Implementation Notes

- A Rails-free scratch replay of the skill test (same seed, same percentile draws, `SkilledPlay` vs `automatic_call`/`automatic_answer`) gave the bot 241 wins, 58 losses, 1 draw out of 300.
- `classify` of a built deck does not always return the archetype that built it (an extreme rating deck often also covers every call and reads as `coverage`; a trump deck can read as `two_stats`), as the ordered rules imply; nothing relies on the round trip.

## Plan Change Log

## Review Triage Log

### 2026-11-20 — Review pass
- verdicts: 1 findings — high 0, medium 1, low 0, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` `db/schema.rb`: the new `game_duels_bot_archetype_check` line sat last, but the dumper sorts `t.check_constraint` statements by text (activerecord `schema_dumper.rb:293`), so the regenerated schema would drift — moved the line after the three `"(state…` checks, before `"capsule IS NULL…`.

## Design Notes

`SkilledPlay` (myopic per round, as the simulation's skilled player; no keep-cost, which the simulation found barely matters):
- `expected_calls(card, stats)` = each `[stat, direction]` of `stats × DIRECTIONS` weighted by `exp(strength / CALL_TEMPERATURE)` normalised, `CALL_TEMPERATURE = 8.0`: how a reader of a shown card expects the hidden call.
- `answer_card`: among `view.hand`, the card minimising `Σ weight × payoff(shown, card, call)` over `expected_calls(view.current_call.card, view.theirs.stats_left)`.
- `call_move`: unseen = `theirs.deck` less `theirs.played`; for each hand card, rank unseen by the reader's choice (lowest expected caller payoff under `expected_calls(card, mine.stats_left)` first); the i-th ranked card is the answer when it is the best of a uniform hand of `h = min(HAND_SIZE, n)`: chance `C(n-1-i, h-1) / C(n, h)`. Value of each `[card, stat, direction]` (stats from `mine.stats_left`) = `Σ chance_i × payoff(card, ranked_i, stat, direction)`; play the max. Memoise payoffs per instance.

`DeckArchetypes`: `NAMES = coverage, popularity, rating, release, discovery, circulation, two_stats, trumps, random`. Build on the pool shuffled with `random`, always adding only games not yet in the deck:
- coverage: for each of the ten calls not yet held at `GAP_BELOW`+ by the deck, a random card at 90+ in it, else the strongest card left in it; then the most extreme trumps to 12.
- a stat: the 12 most extreme cards on it (max of both directions). two_stats: two random stats, the 6 most extreme on each. trumps: the 12 highest trumps. random: the first 12 games.
- classify, in order: coverage (every call held at 90+); a stat (10+ cards at 90+ on it); two_stats (two stats with 5+ cards at 90+ each and 10+ cards at 90+ on either); trumps (every trump ≥ 98); else `other`. A random deck cannot be told from an unplanned one, so classify never answers `random`.

Assumptions (recorded for the author):
- Two stats uses a random pair per duel, named "deux stats" / "two-stat"; the duel stores only `two_stats`.
- Coverage fallback when no card reaches 90 in a direction: the strongest card left in it.
- Names fr/en: couverture/coverage, popularité/popularity, note/rating, sortie/release, découverte/discovery, circulation/circulation, deux stats/two-stat, atouts/trump, aléatoire/random.
- The win-rate floor is 60 % of 300 duels; the rate itself is measured when the coordinator runs the suite.

## Verification

**Commands (run by the coordinator, not this build):**
- `bin/rails test test/domains/game/skilled_play_test.rb test/domains/game/deck_archetypes_test.rb test/domains/game/practice_duel_test.rb` -- expected: pass
- `bin/rails test test/system/duels_test.rb -n /trains/` -- expected: pass
- `RAILS_ENV=test SCHEMA=tmp/migrated_schema.rb bin/rails db:drop db:create db:migrate && diff tmp/migrated_schema.rb db/schema.rb` -- expected: no diff

## Auto Run Result

**Summary:** the practice bot now plays through `Game::SkilledPlay`, a pure object that reads only its own seat's `DuelView` (both open decks, struck cards, shown card, stats left). It values point plus margin against a reader's likely answer from every hand the other seat may hold. Each practice duel deals one of nine archetype decks from `Game::DeckArchetypes`, which also classifies any deck (or `other`). It is never the player's previous archetype, is stored in `game_duels.bot_archetype`, and is named under the opponent's name.

**Files changed:**
- `app/domains/game/app/models/game/skilled_play.rb` -- new: the bot's call and answer from its seat's view.
- `app/domains/game/app/models/game/deck_archetypes.rb` -- new: the nine archetypes, `build` and `classify`.
- `app/domains/game/app/models/game/practice_bot.rb` -- half-random moves removed; `archetype_after`, `deck_cards(archetype)`, catalog pool.
- `app/domains/game/app/operations/game/play_practice_move.rb` -- moves go through `SkilledPlay`.
- `app/domains/game/app/operations/game/start_practice_duel.rb` -- picks, builds and stores the archetype.
- `db/migrate/20261120140000_add_bot_archetype_to_game_duels.rb`, `db/migrate/20261120140001_validate_game_duels_bot_archetype_check.rb`, `db/schema.rb` -- column and its check, NOT VALID then validated; schema edited by hand.
- `app/models/duel_screen.rb`, `app/views/duels/_header.html.erb`, `app/frontend/styles/duel-board.css` -- the archetype line under the opponent's name.
- `config/locales/en.yml`, `config/locales/fr.yml`, `config/i18n-tasks.yml` -- the line, the nine names, the dynamic key ignored.
- `test/domains/game/skilled_play_test.rb`, `test/domains/game/deck_archetypes_test.rb`, `test/domains/game/practice_duel_test.rb`, `test/system/duels_test.rb` -- tests.

**Review findings:** 1 patch applied (medium, schema check order); nothing deferred; nothing rejected.

**Follow-up review recommended:** false (one medium patched; no high).

**Verification:** the coordinator said not to run tests, linters or migrations in this build, so none were run. `ruby -c` on the changed Ruby files and a YAML load of both locales passed. A Rails-free replay of the skill test against the automatic move gave 241 wins, 58 losses and 1 draw out of 300 (floor 180). The coordinator still has to run:
- the commands under Verification;
- packwerk;
- `script/check_planning_references`;
- `script/check_file_sizes`;
- `npm run lint:css`;
- i18n-tasks;
- the schema diff.

**Residual risks:**
- `db/schema.rb` is hand-edited: diff it against a regenerated dump.
- The skill test rebuilds the rules often, and nobody has measured how long it takes under Rails.
- The catalog pool loads every ranked `DuelStat` row each time a practice duel starts. That is fine at today's catalog size.
