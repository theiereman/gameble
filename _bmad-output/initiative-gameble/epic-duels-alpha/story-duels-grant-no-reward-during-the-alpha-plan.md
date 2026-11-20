---
title: 'Duels grant no reward during the alpha'
type: 'feature'
ticket: '2'
created: '2026-11-20'
status: 'built'
baseline_revision: '57da342f8d2c7b14fdc965142c41efb1f9bcd3b5'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: true
context: ['{project-root}/AGENTS.md']
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** During the duels alpha a finished duel must grant nothing: today the finishing move of a live win draws a duel capsule, `GrantAchievementsJob` follows `Game::DuelFinished`, and the result screen and Comment ça marche promise the capsule.

**Approach:** Stop the finishing move from awarding the capsule (and delete the now-dead `Game::DuelCapsule`), drop `Game::DuelFinished` from the achievements handler's events (which the event store subscription reads), remove the result's capsule line with its partial, `DuelScreen#capsule`, styles and locale keys, and remove the capsule paragraph and its odds table from Comment ça marche's duels section. The schema stays: the `duel` pack kind, `duel_day` and its unique index, `game_fortunes.duel_packs`, `game_duels.capsule` and the duel achievement keys; no migration. The ten duel achievements and the Duelliste back already leave the catalogue and the back picker through `Game::Achievements.offered` (entry 1).

</intent-contract>

## Implementation Notes

Oneshot: the change is mostly deletions across a dozen files plus two rewritten tests; no new design.

Files touched:
- `app/domains/game/app/operations/game/answer_round.rb` -- `finish` no longer writes `capsule:` nor calls the capsule; `PlayAutomaticMove` goes through it, so both paths are covered.
- `app/domains/game/app/models/game/duel_capsule.rb` -- deleted (its only caller was `AnswerRound#finish`).
- `app/domains/game/app/handlers/game/handlers/achievements.rb` -- `Game::DuelFinished` leaves `EVENTS`; `config/initializers/event_store.rb` subscribes to `EVENTS.keys`, so the subscription goes with it.
- `app/views/duels/_result.html.erb`, `app/views/duels/_capsule.html.erb` (deleted), `app/models/duel_screen.rb` (`capsule` removed), `app/frontend/styles/duel-reveal.css` (`.duel-capsule*` removed) -- the result keeps the rematch, the rounds and "Send feedback".
- `app/views/pages/how_it_works.html.erb` -- the duels section loses the capsule sentence and the duel odds table.
- `config/locales/{en,fr}.yml` -- removed `duels.board.capsule.{granted,automatic_move,already_won_today}`, `pages.how_it_works.duels.capsule`, `pages.how_it_works.packs.tables.duel`; `duels.lobby.practice_hint` loses "and gives no capsule" (review), since it implied a live duel gives one.
- Tests: deleted `test/domains/game/duel_capsule_test.rb` and `test/controllers/duel_capsule_line_test.rb`; `test/system/duel_capsule_test.rb` becomes `test/system/duel_rewards_test.rb` (a live win and a practice win with no automatic move: no capsule line, no toast, "Send feedback" kept, special reserve at 0, no duel pack, no achievement unlock); new `test/domains/game/duel_rewards_test.rb` (a real win draws no capsule and enqueues no `GrantAchievementsJob`; a finish by `PlayAutomaticMove` records no capsule case); `duel_achievements_test.rb`'s job test now asserts `DuelFinished` is not followed and publishing it enqueues no job; `duel_board_test.rb` expects no `#duel-capsule-line`; `how_it_works_test.rb` drops the duel odds table and expects no capsule paragraph; the schema checks of the duel pack kind (one per player and day, three cards, duel day on duel packs only) move from the deleted capsule test to `test/domains/game/duel_pack_schema_test.rb` (review).

Assumptions (no one to ask):
- `Game::DuelCapsule` is deleted rather than left unused: nothing else calls it and deleting it touches no schema; the beta can restore it from history. `Game::Pack::DUEL_SIZE` and `Game::DrawOdds::DUEL` stay, since `Game::LuckOdds` and the `duel` pack kind (packs already granted to staff stay openable) still read them.
- The `game_duels.capsule` column and its check constraints stay; new duels simply write nil.
- "Comment ça marche's duels section drops the capsule" is read as dropping both the capsule sentence and the duel capsule odds table under it, since the table describes the capsule's odds.
- The `canister-small-duel` pixel icon stays generated, though nothing renders it now: it is art for the beta's return, and the pixel export script owns that folder.
- The Duelliste back already leaves the back picker through `CardBackShelf.offered_backs`, which reads `Game::Achievements.offered_keys` since entry 1 (`card_back_shelf_test.rb` asserts it); nothing to change.
- The system test's practice win replays the live duel: the practice duel's decks, draw orders and first caller are copied from the live duel Léa just won, and both seats play the rules' moves through the operations, since the bot's own deck and half its moves are random. The bot's own play is covered by `practice_duel_test.rb`.
- Duel packs or achievements already granted to staff in production stay as they are (ticket's unknown).

## Plan Change Log

## Review Triage Log

### 2026-11-20 — Review pass
- verdicts: 4 findings — high 0, medium 2, low 2, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` the system test plays the practice duel to its end without proving a win, which the ticket's verify asks for — the practice duel now takes the live duel's decks, draw orders and first caller and both seats play the rules' moves, and the test asserts the result `challenger` and "Win against".
  - `[low]` `[patch]` the lobby's practice hint "gives no capsule" still implies a live duel gives one — the hint reads "Training only: it counts for nothing." / "Entraînement seulement : il ne compte pour rien." in both locales.
  - `[medium]` `[patch]` deleting the capsule test left the kept duel pack schema (one-per-day index, size and duel-day checks) untested — its two schema tests move to `test/domains/game/duel_pack_schema_test.rb`, without `DuelCapsule`.
  - `[low]` `[patch]` the system test's "no toast" check could never fail since `GrantAchievementsJob` was never delivered — `deliver` now performs `Game::GrantAchievementsJob` too.

## Auto Run Result

Status: built

**Summary:** a finished duel grants nothing during the alpha. `AnswerRound#finish` (which `PlayAutomaticMove` goes through) no longer draws a duel capsule, and `Game::DuelCapsule` is deleted; `Game::DuelFinished` leaves the achievements handler's events, so `GrantAchievementsJob` no longer follows it; the duel result loses its capsule line (partial, `DuelScreen#capsule`, styles, keys) and keeps "Send feedback"; Comment ça marche's duels section loses the capsule sentence and its odds table; the lobby's practice hint no longer mentions a capsule. Schema untouched, no migration.

**Files changed:**
- `app/domains/game/app/operations/game/answer_round.rb` — finish without the capsule.
- `app/domains/game/app/models/game/duel_capsule.rb` — deleted.
- `app/domains/game/app/handlers/game/handlers/achievements.rb` — `DuelFinished` not followed.
- `app/views/duels/_result.html.erb`, `app/views/duels/_capsule.html.erb` (deleted), `app/models/duel_screen.rb`, `app/frontend/styles/duel-reveal.css` — capsule line gone.
- `app/views/pages/how_it_works.html.erb` — capsule sentence and duel odds table gone.
- `config/locales/{en,fr}.yml` — five unused keys removed, practice hint reworded.
- Tests — `duel_capsule_test.rb` and `duel_capsule_line_test.rb` deleted; `test/system/duel_rewards_test.rb` (renamed from the capsule system test), `test/domains/game/duel_rewards_test.rb`, `test/domains/game/duel_pack_schema_test.rb` added; `duel_achievements_test.rb`, `duel_board_test.rb`, `how_it_works_test.rb` adjusted.

**Review:** 4 patches applied (2 medium, 2 low), 0 deferred, 0 rejected.

**Follow-up review recommended:** true — two medium findings patched; the practice replay (copying the live duel's snapshots onto the practice duel) and every new or changed test were never run, so a wrong assumption about the snapshot columns would only show in the coordinator's suite run.

**Verification:** no suite or check run in this build, by the coordinator's instruction; grep for `DuelCapsule`, `duels/capsule`, `duel-capsule`, `board.capsule`, `duels.capsule`, `tables.duel` over app, test and config finds only the absence assertions.

**Residual risks:** i18n-tasks may flag key ordering; the unused `canister-small-duel` pixel icon stays generated.

## Verification

Per the coordinator, suites run once in the main tree; this build runs none.

**Commands (coordinator):**
- `bin/rails test test/domains/game/duel_rewards_test.rb test/domains/game/duel_pack_schema_test.rb test/domains/game/duel_achievements_test.rb test/controllers/duel_board_test.rb test/controllers/how_it_works_test.rb test/domains/game/practice_duel_test.rb` -- expected: green
- `bin/rails test test/system/duel_rewards_test.rb` -- expected: green
- `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `bin/ci` (i18n-tasks unused keys) -- expected: green
- `grep -rn "DuelCapsule\|duels/capsule\|duel-capsule" app test` -- expected: only the absence assertions in the rewards and board tests
